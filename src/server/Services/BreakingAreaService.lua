--[[
	BreakingAreaService.lua
	Handles spawning blocks in the BreakingZone grid
	- Blocks spawn on a 2-stud grid in a 64x64x64 BreakingZone
	- 3 floors maximum (16x16 = 256 blocks per floor)
	- Blocks spawn every X seconds, filling floor 1 first, then 2, then 3
	- Registers spawned blocks with BreakingService for unified breaking
]]

-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Data & Config
local MaterialData = require(ReplicatedStorage.Shared.Data.MaterialData)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local BreakingConfig = require(ReplicatedStorage.Shared.Config.BreakingConfig)

-- Services (to be initialized)
local BreakingService
local DataService

local BreakingAreaService = Knit.CreateService({
	Name = "BreakingAreaService",
	Client = {
		-- Signals for client visual updates (spawn animations)
		BlockAboutToSpawn = Knit.CreateSignal(), -- (blockData) - sent before animation
		BlockSpawned = Knit.CreateSignal(), -- (blockData) - sent after animation
	},
})

-- Types
type BlockData = {
	id: string,
	materialType: string,
	gridX: number,
	gridZ: number,
	floor: number,
}

type RuntimeBlock = {
	id: string,
	materialType: string,
	gridX: number,
	gridZ: number,
	floor: number,
	position: Vector3,
	model: Instance?,
}

-- Private variables
local playerBlocks: {[Player]: {[string]: RuntimeBlock}} = {} -- Runtime blocks per player
local playerSpawnLoops: {[Player]: boolean} = {} -- Active spawn loops

-- References (cached)
local breakingZone = nil
local breakingArea = nil

--|| Private Functions ||--

-- Get BreakingZone references
local function getBreakingZone()
	if not breakingZone or not breakingArea then
		breakingZone = Workspace:FindFirstChild("BreakingZone")
		if breakingZone then
			breakingArea = breakingZone:FindFirstChild("BreakingArea")
			if not breakingArea then
				breakingArea = breakingZone:FindFirstChild("Area")
			end
		end
	end
	return breakingZone, breakingArea
end

-- Get BreakingArea origin (floor level)
local function getBreakingAreaOrigin(): Vector3?
	local zone, area = getBreakingZone()

	if not zone then
		warn("[BreakingAreaService] BreakingZone not found in Workspace!")
		return nil
	end

	if not area then
		warn("[BreakingAreaService] BreakingArea not found inside BreakingZone!")
		return nil
	end

	return Vector3.new(area.Position.X, area.Position.Y - 32, area.Position.Z)
end

-- Convert grid coordinates to world position
local function gridToWorldPosition(gridX: number, gridZ: number, floor: number): Vector3?
	local origin = getBreakingAreaOrigin()
	if not origin then return nil end

	local x = -30 + (gridX * 4)
	local z = -30 + (gridZ * 4)
	local y = BreakingConfig.FloorYPositions[floor]

	return origin + Vector3.new(x, y, z)
end

-- Get player's breaking data from DataService
local function getBreakingData(player: Player)
	if not DataService then return nil end
	local playerData = DataService:GetData(player)
	if not playerData then return nil end
	return playerData.Breaking
end

-- Generate unique block ID for player
local function generateBlockId(player: Player): string
	local breakingData = getBreakingData(player)
	if not breakingData then return tostring(tick()) end

	local id = string.format("%s_break_%d", player.UserId, breakingData.NextBlockId)
	breakingData.NextBlockId = breakingData.NextBlockId + 1

	return id
end

-- Check if a grid position is occupied for a player
local function isGridPositionOccupied(player: Player, gridX: number, gridZ: number, floor: number): boolean
	local blocks = playerBlocks[player]
	if not blocks then return false end

	for _, block in pairs(blocks) do
		if block.gridX == gridX and block.gridZ == gridZ and block.floor == floor then
			return true
		end
	end

	return false
end

-- Get all empty positions on a floor for a player
local function getEmptyPositionsOnFloor(player: Player, floor: number): {{x: number, z: number}}
	local emptyPositions = {}

	for gridX = 0, BreakingConfig.BlocksPerAxis - 1 do
		for gridZ = 0, BreakingConfig.BlocksPerAxis - 1 do
			if not isGridPositionOccupied(player, gridX, gridZ, floor) then
				table.insert(emptyPositions, {x = gridX, z = gridZ})
			end
		end
	end

	return emptyPositions
end

-- Get the current floor to fill (lowest floor with empty spots)
local function getCurrentFillFloor(player: Player): (number?, {{x: number, z: number}}?)
	for floor = 1, BreakingConfig.MaxFloors do
		local emptyPositions = getEmptyPositionsOnFloor(player, floor)
		if #emptyPositions > 0 then
			return floor, emptyPositions
		end
	end

	return nil, nil
end

-- Create block model in world
local function createBlockModel(materialType: string, position: Vector3, blockId: string, player: Player): Instance?
	local itemConfig = ItemData.GetItem(materialType)
	if not itemConfig or not itemConfig.buildingPartPath then
		warn("[BreakingAreaService] No buildingPartPath for material:", materialType)
		return nil
	end

	-- Parse building part path
	local pathParts = string.split(itemConfig.buildingPartPath, ".")
	local current = ReplicatedStorage

	local startIndex = 1
	if pathParts[1] == "ReplicatedStorage" then
		startIndex = 2
	end

	for i = startIndex, #pathParts do
		current = current:FindFirstChild(pathParts[i])
		if not current then
			warn("[BreakingAreaService] Building part not found at path:", itemConfig.buildingPartPath)
			return nil
		end
	end

	if not current:IsA("Model") and not current:IsA("BasePart") then
		warn("[BreakingAreaService] Building part is not a Model or Part:", itemConfig.buildingPartPath)
		return nil
	end

	-- Clone the building part
	local model = current:Clone()
	model.Name = "BreakBlock_" .. blockId

	-- Set position
	if model:IsA("Model") and model.PrimaryPart then
		model:SetPrimaryPartCFrame(CFrame.new(position))
	elseif model:IsA("BasePart") then
		model.Position = position
		model.Size = BreakingConfig.BlockSize
		model.Anchored = true
		model.CanCollide = true
	end

	-- Determine target part for values (PrimaryPart for Models, the part itself for BaseParts)
	local targetPart
	if model:IsA("Model") and model.PrimaryPart then
		targetPart = model.PrimaryPart
	elseif model:IsA("BasePart") then
		targetPart = model
	else
		targetPart = model
	end

	-- Store block ID and player ID on target part (for client detection)
	local idValue = Instance.new("StringValue")
	idValue.Name = "BreakableId"
	idValue.Value = blockId
	idValue.Parent = targetPart

	local playerIdValue = Instance.new("IntValue")
	playerIdValue.Name = "PlayerId"
	playerIdValue.Value = player.UserId
	playerIdValue.Parent = targetPart

	-- Store material type for client
	local materialValue = Instance.new("StringValue")
	materialValue.Name = "MaterialType"
	materialValue.Value = materialType
	materialValue.Parent = targetPart

	-- Parent to BreakingZone
	local zone, _ = getBreakingZone()
	if zone then
		model.Parent = zone
	else
		model.Parent = Workspace
	end

	return model
end

-- Save block to player data
local function saveBlockToData(player: Player, blockData: BlockData)
	local breakingData = getBreakingData(player)
	if not breakingData then return end

	table.insert(breakingData.SpawnedBlocks, {
		id = blockData.id,
		materialType = blockData.materialType,
		gridX = blockData.gridX,
		gridZ = blockData.gridZ,
		floor = blockData.floor,
	})
end

-- Remove block from player data
local function removeBlockFromData(player: Player, blockId: string)
	local breakingData = getBreakingData(player)
	if not breakingData then return end

	for i, block in ipairs(breakingData.SpawnedBlocks) do
		if block.id == blockId then
			table.remove(breakingData.SpawnedBlocks, i)
			break
		end
	end
end

-- Register block with BreakingService
local function registerBlockWithBreakingService(player: Player, block: RuntimeBlock)
	if not BreakingService then return end

	BreakingService:RegisterBreakable(player, block.id, {
		materialType = block.materialType,
		dropItem = block.materialType, -- Blocks drop themselves
		dropAmount = 1,
		position = block.position,
		part = block.model,
	})
end

-- Try to spawn a block for a player
local function trySpawnBlock(player: Player): boolean
	local floor, emptyPositions = getCurrentFillFloor(player)
	if not floor or not emptyPositions or #emptyPositions == 0 then
		return false
	end

	local randomPos = emptyPositions[math.random(1, #emptyPositions)]
	local gridX, gridZ = randomPos.x, randomPos.z

	local worldPosition = gridToWorldPosition(gridX, gridZ, floor)
	if not worldPosition then
		return false
	end

	local materialType = MaterialData.GetRandomBreakingMaterial()
	local blockId = generateBlockId(player)

	local blockDataToSend = {
		id = blockId,
		materialType = materialType,
		gridX = gridX,
		gridZ = gridZ,
		floor = floor,
		position = worldPosition,
	}

	if not playerBlocks[player] then
		playerBlocks[player] = {}
	end

	-- Reserve the position immediately
	local runtimeBlock: RuntimeBlock = {
		id = blockId,
		materialType = materialType,
		gridX = gridX,
		gridZ = gridZ,
		floor = floor,
		position = worldPosition,
		model = nil,
	}
	playerBlocks[player][blockId] = runtimeBlock

	-- Save to persistent data
	saveBlockToData(player, {
		id = blockId,
		materialType = materialType,
		gridX = gridX,
		gridZ = gridZ,
		floor = floor,
	})

	-- Notify client to start spawn animation
	BreakingAreaService.Client.BlockAboutToSpawn:Fire(player, blockDataToSend)

	-- Wait for animation, then create server model
	task.spawn(function()
		task.wait(BreakingConfig.SpawnAnimationDuration)

		if not player.Parent then return end
		if not playerBlocks[player] or not playerBlocks[player][blockId] then return end

		local model = createBlockModel(materialType, worldPosition, blockId, player)
		if model then
			playerBlocks[player][blockId].model = model

			-- Register with BreakingService
			registerBlockWithBreakingService(player, playerBlocks[player][blockId])
		end

		BreakingAreaService.Client.BlockSpawned:Fire(player, blockDataToSend)
	end)

	return true
end

-- Start spawn loop for player
local function startSpawnLoop(player: Player)
	if playerSpawnLoops[player] then return end

	playerSpawnLoops[player] = true

	task.spawn(function()
		while playerSpawnLoops[player] and player.Parent do
			local breakingData = getBreakingData(player)
			local interval = (breakingData and breakingData.SpawnInterval) or BreakingConfig.DefaultSpawnInterval

			task.wait(interval)

			if playerSpawnLoops[player] and player.Parent then
				trySpawnBlock(player)
			end
		end
	end)
end

-- Stop spawn loop for player
local function stopSpawnLoop(player: Player)
	playerSpawnLoops[player] = nil
end

-- Load spawned blocks from player data
local function loadSpawnedBlocks(player: Player)
	local breakingData = getBreakingData(player)
	if not breakingData then return end

	playerBlocks[player] = {}

	for _, blockData in ipairs(breakingData.SpawnedBlocks) do
		local worldPosition = gridToWorldPosition(blockData.gridX, blockData.gridZ, blockData.floor)
		if worldPosition then
			local model = createBlockModel(blockData.materialType, worldPosition, blockData.id, player)
			if model then
				local runtimeBlock: RuntimeBlock = {
					id = blockData.id,
					materialType = blockData.materialType,
					gridX = blockData.gridX,
					gridZ = blockData.gridZ,
					floor = blockData.floor,
					position = worldPosition,
					model = model,
				}
				playerBlocks[player][blockData.id] = runtimeBlock

				-- Register with BreakingService
				registerBlockWithBreakingService(player, runtimeBlock)
			end
		end
	end

	print("[BreakingAreaService] Loaded", #breakingData.SpawnedBlocks, "blocks for", player.Name)
end

-- Clean up player's blocks from world
local function cleanupPlayerBlocks(player: Player)
	local blocks = playerBlocks[player]
	if not blocks then return end

	for blockId, block in pairs(blocks) do
		-- Unregister from BreakingService
		if BreakingService then
			BreakingService:UnregisterBreakable(player, blockId)
		end

		if block.model then
			block.model:Destroy()
		end
	end

	playerBlocks[player] = nil
end

-- Handle block broken event from BreakingService
local function onBreakableDestroyed(player: Player, breakableId: string, dropItem: string, position: Vector3)
	local blocks = playerBlocks[player]
	if not blocks then return end

	local block = blocks[breakableId]
	if not block then return end

	-- Remove from runtime tracking
	blocks[breakableId] = nil

	-- Remove from persistent data
	removeBlockFromData(player, breakableId)
end

--|| Knit Lifecycle ||--

function BreakingAreaService:KnitInit()
	getBreakingZone()

	if not breakingZone then
		warn("[BreakingAreaService] BreakingZone not found in Workspace!")
	end
end

function BreakingAreaService:KnitStart()
	BreakingService = Knit.GetService("BreakingService")
	DataService = Knit.GetService("DataService")

	-- Listen to BreakingService for destroyed breakables
	BreakingService.BreakableDestroyed:Connect(onBreakableDestroyed)

	-- Handle player joining
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(1)

			loadSpawnedBlocks(player)
			startSpawnLoop(player)
		end)

		if player.Character then
			task.wait(1)
			loadSpawnedBlocks(player)
			startSpawnLoop(player)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		stopSpawnLoop(player)
		cleanupPlayerBlocks(player)
	end)
end

return BreakingAreaService
