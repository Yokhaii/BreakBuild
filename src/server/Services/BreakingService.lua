--[[
	BreakingService.lua
	Unified breaking system that handles breaking ANY breakable object
	- Breakables are registered by spawner services (BreakingAreaService, TreeService, etc.)
	- Each breakable has: id, materialType, dropItem, dropAmount, position
	- Handles breaking progress, tool validation, and item drops
	- Fires events when breakables are destroyed (spawners listen to respawn)
]]

-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

-- Data & Config
local MaterialData = require(ReplicatedStorage.Shared.Data.MaterialData)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local BreakingConfig = require(ReplicatedStorage.Shared.Config.BreakingConfig)

-- Services (to be initialized)
local InventoryService

local BreakingService = Knit.CreateService({
	Name = "BreakingService",
	Client = {
		-- Signals for client
		BreakablesInitialized = Knit.CreateSignal(), -- (breakables table)
		BreakableRegistered = Knit.CreateSignal(), -- (breakableData)
		BreakableUnregistered = Knit.CreateSignal(), -- (breakableId)
		BreakingStarted = Knit.CreateSignal(), -- (breakableId)
		BreakingProgress = Knit.CreateSignal(), -- (breakableId, progress 0-1)
		BreakingStopped = Knit.CreateSignal(), -- (breakableId)
		BreakableBroken = Knit.CreateSignal(), -- (breakableId, dropItem, position)
	},
	-- Server-side signal for spawner services to listen to
	BreakableDestroyed = nil, -- Will be created in KnitInit
})

-- Types
export type BreakableConfig = {
	materialType: string, -- For break time and tool tier checking
	dropItem: string, -- Item to give when broken
	dropAmount: number?, -- How many to give (default 1)
	position: Vector3, -- World position
	part: Instance, -- The actual part/model to destroy
	customBreakTime: number?, -- Override break time (optional)
	onBroken: ((player: Player, breakableId: string) -> ())?, -- Custom callback when broken
}

type RuntimeBreakable = {
	id: string,
	materialType: string,
	dropItem: string,
	dropAmount: number,
	position: Vector3,
	part: Instance,
	customBreakTime: number?,
	onBroken: ((player: Player, breakableId: string) -> ())?,
}

type BreakingState = {
	breakableId: string,
	startTime: number,
	totalBreakTime: number,
	toolConfig: any,
}

-- Private variables
local playerBreakables: {[Player]: {[string]: RuntimeBreakable}} = {} -- Registered breakables per player
local playerBreaking: {[Player]: BreakingState} = {} -- Currently breaking state per player

-- Signal module for server-side events
local Signal = require(ReplicatedStorage.Packages.Signal)

--|| Private Functions ||--

-- Bare hand config (used when no tool is equipped)
local BARE_HAND_CONFIG = {
	isBreakingTool = true,
	toolTier = BreakingConfig.BareHandToolTier,
	breakSpeed = BreakingConfig.BareHandBreakSpeed,
	isBareHand = true,
}

-- Get player's currently equipped tool config (returns bare hand config if no tool)
local function getEquippedToolConfig(player: Player): any
	if not InventoryService then return BARE_HAND_CONFIG end

	local inventory = InventoryService:GetInventory(player)
	if not inventory or not inventory.EquippedSlot then return BARE_HAND_CONFIG end

	local equippedItem = inventory.Hotbar[inventory.EquippedSlot]
	if not equippedItem then return BARE_HAND_CONFIG end

	local itemConfig = ItemData.GetItem(equippedItem.itemName)
	if not itemConfig or not itemConfig.isBreakingTool then return BARE_HAND_CONFIG end

	return itemConfig
end

-- Check if tool can break material
local function canToolBreakMaterial(toolConfig: any, materialType: string): boolean
	if toolConfig.canBreakAll then
		return true
	end
	return MaterialData.CanToolBreak(toolConfig.toolTier, materialType)
end

-- Give item to player inventory
local function giveItemToPlayer(player: Player, itemName: string, amount: number)
	if not InventoryService then
		warn("[BreakingService] InventoryService not initialized!")
		return
	end

	local success = InventoryService:AddItem(player, itemName, amount)
	if not success then
		warn("[BreakingService] Failed to add item to inventory:", itemName)
	end
end

-- Get all breakables data for client
local function getBreakablesData(player: Player): {[string]: {materialType: string, position: Vector3}}
	local data = {}
	local breakables = playerBreakables[player]
	if not breakables then return data end

	for id, breakable in pairs(breakables) do
		data[id] = {
			materialType = breakable.materialType,
			position = breakable.position,
		}
	end

	return data
end

--|| Public Functions ||--

-- Register a breakable object for a player
-- Called by spawner services (BreakingAreaService, TreeService, etc.)
function BreakingService:RegisterBreakable(player: Player, breakableId: string, config: BreakableConfig)
	if not playerBreakables[player] then
		playerBreakables[player] = {}
	end

	local breakable: RuntimeBreakable = {
		id = breakableId,
		materialType = config.materialType,
		dropItem = config.dropItem,
		dropAmount = config.dropAmount or 1,
		position = config.position,
		part = config.part,
		customBreakTime = config.customBreakTime,
		onBroken = config.onBroken,
	}

	playerBreakables[player][breakableId] = breakable

	-- Notify client
	self.Client.BreakableRegistered:Fire(player, {
		id = breakableId,
		materialType = config.materialType,
		position = config.position,
	})
end

-- Unregister a breakable (without destroying it - used for cleanup)
function BreakingService:UnregisterBreakable(player: Player, breakableId: string)
	if not playerBreakables[player] then return end

	playerBreakables[player][breakableId] = nil

	-- Stop breaking if player was breaking this
	if playerBreaking[player] and playerBreaking[player].breakableId == breakableId then
		playerBreaking[player] = nil
	end

	-- Notify client
	self.Client.BreakableUnregistered:Fire(player, breakableId)
end

-- Start breaking a breakable
function BreakingService:StartBreaking(player: Player, breakableId: string): boolean
	local breakables = playerBreakables[player]
	if not breakables then
		return false
	end

	local breakable = breakables[breakableId]
	if not breakable then
		return false
	end

	-- Get tool config (returns bare hand config if no tool equipped)
	local toolConfig = getEquippedToolConfig(player)

	-- Check if tool can break this material
	if not canToolBreakMaterial(toolConfig, breakable.materialType) then
		return false
	end

	-- Calculate break time
	local breakTime
	if breakable.customBreakTime then
		breakTime = breakable.customBreakTime / toolConfig.breakSpeed
	else
		breakTime = MaterialData.GetBreakTime(breakable.materialType, toolConfig.breakSpeed)
	end

	-- Set breaking state
	playerBreaking[player] = {
		breakableId = breakableId,
		startTime = tick(),
		totalBreakTime = breakTime,
		toolConfig = toolConfig,
	}

	-- Notify client
	self.Client.BreakingStarted:Fire(player, breakableId)

	return true
end

-- Stop breaking
function BreakingService:StopBreaking(player: Player)
	local state = playerBreaking[player]
	if not state then return end

	local breakableId = state.breakableId
	playerBreaking[player] = nil

	-- Notify client
	self.Client.BreakingStopped:Fire(player, breakableId)
end

-- Get all breakables for a player (for client initialization)
function BreakingService:GetBreakables(player: Player)
	return getBreakablesData(player)
end

-- Check if a breakable exists
function BreakingService:HasBreakable(player: Player, breakableId: string): boolean
	return playerBreakables[player] and playerBreakables[player][breakableId] ~= nil
end

--|| Client Functions ||--

function BreakingService.Client:GetBreakables(player: Player)
	return self.Server:GetBreakables(player)
end

function BreakingService.Client:StartBreaking(player: Player, breakableId: string)
	return self.Server:StartBreaking(player, breakableId)
end

function BreakingService.Client:StopBreaking(player: Player)
	return self.Server:StopBreaking(player)
end

--|| Breaking Progress Loop ||--

local function updateBreakingProgress()
	local currentTime = tick()

	for player, state in pairs(playerBreaking) do
		-- Check if player is still valid
		if not player.Parent then
			playerBreaking[player] = nil
			continue
		end

		local breakables = playerBreakables[player]
		if not breakables then
			playerBreaking[player] = nil
			continue
		end

		-- Check if breakable still exists
		local breakable = breakables[state.breakableId]
		if not breakable then
			playerBreaking[player] = nil
			BreakingService.Client.BreakingStopped:Fire(player, state.breakableId)
			continue
		end

		-- Check if tool is still equipped and valid
		local toolConfig = getEquippedToolConfig(player)
		if not canToolBreakMaterial(toolConfig, breakable.materialType) then
			playerBreaking[player] = nil
			BreakingService.Client.BreakingStopped:Fire(player, state.breakableId)
			continue
		end

		-- Calculate progress
		local elapsed = currentTime - state.startTime
		local progress = math.clamp(elapsed / state.totalBreakTime, 0, 1)

		-- Send progress update
		BreakingService.Client.BreakingProgress:Fire(player, state.breakableId, progress)

		-- Check if breaking complete
		if progress >= 1 then
			local breakableId = state.breakableId
			local dropItem = breakable.dropItem
			local dropAmount = breakable.dropAmount
			local position = breakable.position
			local part = breakable.part
			local onBroken = breakable.onBroken

			-- Remove from runtime
			breakables[breakableId] = nil

			-- Clear breaking state
			playerBreaking[player] = nil

			-- Destroy the part
			if part and part.Parent then
				part:Destroy()
			end

			-- Give item to player
			if dropItem and dropItem ~= "" then
				giveItemToPlayer(player, dropItem, dropAmount)
			end

			-- Call custom callback if provided
			if onBroken then
				task.spawn(function()
					onBroken(player, breakableId)
				end)
			end

			-- Fire server-side event for spawner services
			BreakingService.BreakableDestroyed:Fire(player, breakableId, dropItem, position)

			-- Notify client
			BreakingService.Client.BreakableBroken:Fire(player, breakableId, dropItem, position)
		end
	end
end

--|| Knit Lifecycle ||--

function BreakingService:KnitInit()
	-- Create server-side signal for spawner services
	self.BreakableDestroyed = Signal.new()
end

function BreakingService:KnitStart()
	InventoryService = Knit.GetService("InventoryService")

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		playerBreaking[player] = nil
		playerBreakables[player] = nil
	end)

	-- Start breaking progress loop
	RunService.Heartbeat:Connect(function(deltaTime)
		updateBreakingProgress()
	end)
end

return BreakingService
