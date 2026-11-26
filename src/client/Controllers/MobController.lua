--[[
	MobController.lua
	Client side of the mob system (see .claude/mob-system-instructions.md):
	  - creates a client mob class (Classes/Mobs/<class>, else BaseMob) for every mob model
	    streamed to this client, destroys it when the model leaves
	  - dev only: N toggles the Mob Spawner panel (CurrentFrame "MobSpawner") and the panel's
	    buttons call the Dev* methods below
	Movement and decisions are all on the server (MobService); the client only shows them.
]]

-- Services
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

-- Knit packages
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Data
local MobData = require(ReplicatedStorage.Shared.Data.MobData)
local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)

-- Rodux
local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)

-- Classes
local MobClasses = Client.Classes.Mobs
local BaseMob = require(MobClasses.BaseMob)

-- MobController
local MobController = Knit.CreateController({
	Name = "MobController",
})

-- Constants
local FRAME_NAME = "MobSpawner"
local TOGGLE_KEY = Enum.KeyCode.N
local ERROR_COLOR = Color3.fromRGB(255, 90, 90)

-- Private variables
local MobService
local UIController
local KeybindController
local TextNotificationController
local mobObjects = {} -- [model] = client mob
local isDevPlayer = false

--|| Private Functions ||--

local function loadMobClass(className: string?)
	local module = className and MobClasses:FindFirstChild(className)
	return module and require(module) or BaseMob
end

local function onMobAdded(model: Instance)
	if not model:IsA("Model") or mobObjects[model] then return end
	local data = MobData.GetMob(model:GetAttribute(MobConfig.Attributes.MobType))
	if not data then return end
	mobObjects[model] = loadMobClass(data.class).new(model, data)
end

local function onMobRemoved(model: Instance)
	local mob = mobObjects[model]
	if not mob then return end
	mobObjects[model] = nil
	mob:Destroy()
end

local function showError(text: string)
	if TextNotificationController then
		TextNotificationController:Show(text, ERROR_COLOR)
	end
end

-- Call a MobService dev method, notify on failure
local function callDev(methodName: string, ...)
	local args = table.pack(...)
	return MobService[methodName](MobService, table.unpack(args, 1, args.n)):catch(function(err)
		warn("[MobController]", methodName, err)
		showError("Mob action failed")
	end)
end

--|| Public Functions ||--

function MobController:IsDevPlayer(): boolean
	return isDevPlayer
end

function MobController:ToggleMobSpawner()
	if not isDevPlayer then return end
	if UIController:GetCurrentFrame() == FRAME_NAME then
		UIController:ShowHUD()
	else
		UIController:SetCurrentFrame(FRAME_NAME)
	end
end

function MobController:CloseMobSpawner()
	if UIController:GetCurrentFrame() == FRAME_NAME then
		UIController:ShowHUD()
	end
end

-- Spawn `amount` frozen mobs in front of the player
function MobController:DevSpawn(mobType: string, amount: number?)
	callDev("DevSpawn", mobType, amount or 1)
end

function MobController:DevEnableAll()
	callDev("DevEnableAll")
end

function MobController:DevFreezeAll()
	callDev("DevFreezeAll")
end

function MobController:DevFleeFromMe()
	callDev("DevFleeFromMe")
end

function MobController:DevComeToMe()
	callDev("DevComeToMe")
end

function MobController:DevChaseMe()
	callDev("DevChaseMe")
end

function MobController:DevHitNearest()
	callDev("DevHitNearest")
end

function MobController:DevDespawn(onlyDevSpawns: boolean)
	callDev("DevDespawn", onlyDevSpawns)
end

function MobController:DevToggleNaturalSpawning()
	local enabled = Store:getState().DevMobReducer.NaturalSpawning
	callDev("DevSetNaturalSpawning", not enabled)
end

--|| Initialization ||--

function MobController:KnitStart()
	MobService = Knit.GetService("MobService")
	UIController = Knit.GetController("UIController")
	KeybindController = Knit.GetController("KeybindController")
	TextNotificationController = Knit.GetController("TextNotificationController")

	CollectionService:GetInstanceAddedSignal(MobConfig.MobTag):Connect(onMobAdded)
	CollectionService:GetInstanceRemovedSignal(MobConfig.MobTag):Connect(onMobRemoved)
	for _, model in ipairs(CollectionService:GetTagged(MobConfig.MobTag)) do
		onMobAdded(model)
	end

	-- Same rule as MobService's dev check: any Studio session, or a dev account
	Knit.GetService("InventoryService"):IsDevPlayer():andThen(function(result)
		isDevPlayer = result or RunService:IsStudio()
		if isDevPlayer then
			KeybindController:Register("ToggleMobSpawner", TOGGLE_KEY, function()
				self:ToggleMobSpawner()
			end)
		end
	end)
end

return MobController
