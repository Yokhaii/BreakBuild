--[[
	MobService.lua
	Owns every live mob (see .claude/mob-system-instructions.md):
	- Spawn / Enable / Disable / Despawn, registry of live mobs
	- One Heartbeat loop: MobMover every frame, behaviors at MobConfig.ThinkRate
	- Dev API for the Mob Spawner panel (N key)
	It never decides when or where mobs spawn naturally: that's MobSpawnService.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local MobData = require(ReplicatedStorage.Shared.Data.MobData)
local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)
local SpawnUtils = require(script.Parent.Parent.Modules.SpawnUtils)

local MobClasses = script.Parent.Parent.Classes.Mobs
local BaseMob = require(MobClasses.BaseMob)
local Water = require(MobClasses.Navigation.Water)

local InventoryService
local MobSpawnService

local MobService = Knit.CreateService({
	Name = "MobService",
	Client = {
		DevStateChanged = Knit.CreateSignal(), -- (state) to dev players only
	},
})

MobService.MobSpawned = Signal.new() -- (mob)
MobService.MobRemoved = Signal.new() -- (mob, reason: "Died" | "Despawned" | "Destroyed")

local DEV_MAX_SPAWN = 10
local DEV_SPAWN_SPACING = 6 -- studs between mobs spawned in one click
local DEV_SPAWN_JITTER = 4 -- random sideways studs for single spawns (clicks don't stack mobs)
local DEV_COME_DISTANCE = 6 -- "Come to me" stops this far from the player
local DEV_ACTION_RADIUS = 120 -- studs around the dev player for Flee / Come / Chase
local DEV_HIT_RANGE = 40
local DEV_STATE_INTERVAL = 0.25

-- id -> mob
local mobs = {}
local nextMobId = 0
local mobsFolder: Folder
local devStateDirty = false

--|| Helpers ||--

local function resolveModel(modelPath: string): Model?
	local current = game
	for _, name in ipairs(string.split(modelPath, ".")) do
		current = current:FindFirstChild(name)
		if not current then
			return nil
		end
	end
	return current:IsA("Model") and current or nil
end

local function loadMobClass(className: string?)
	local module = className and MobClasses:FindFirstChild(className)
	return module and require(module) or BaseMob
end

-- Height of the RootPart above the bottom of the CollidePart (so the mob stands on the ground)
local function getRootHeight(model: Model): number
	local root = model.PrimaryPart
	local collide = model:FindFirstChild("CollidePart")
	if not collide then
		return root.Size.Y / 2
	end
	return root.Position.Y - (collide.Position.Y - collide.Size.Y / 2)
end

local function getCharacterRoot(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart")
end

local function isDev(player: Player): boolean
	return RunService:IsStudio() or InventoryService:IsDevPlayer(player)
end

local function markDevStateDirty()
	devStateDirty = true
end

--|| Public API ||--

--[=[
	Spawn a mob standing on the ground at `cframe` (position = ground point, rotation = facing).
	options:
	  enabled       boolean?  start its behavior right away (default false = frozen, Immobile)
	  homePosition  Vector3?  center of its patrol area (default: spawn position)
	  isDevSpawn    boolean?  spawned from the dev panel
	Returns the mob object (Classes/Mobs/<class>), or nil.
]=]
function MobService:Spawn(mobType: string, cframe: CFrame, options)
	options = options or {}
	local data = MobData.GetMob(mobType)
	if not data then
		warn("[MobService] Unknown mob type:", mobType)
		return nil
	end
	local template = resolveModel(data.modelPath)
	if not template or not template.PrimaryPart then
		warn("[MobService] Mob model not found (or no PrimaryPart) at path:", data.modelPath)
		return nil
	end

	nextMobId += 1
	local id = nextMobId

	local model = template:Clone()
	-- Brackets keep names unique as substrings too (the Animation package matches models by full name)
	model.Name = mobType .. "[" .. id .. "]"
	local groundPosition = cframe.Position
	local yaw = select(2, cframe:ToOrientation())
	model:PivotTo(CFrame.new(groundPosition + Vector3.new(0, getRootHeight(template) + 0.05, 0)) * CFrame.Angles(0, yaw, 0))
	model.Parent = mobsFolder
	model.PrimaryPart:SetNetworkOwner(nil)

	local mob = loadMobClass(data.class).new(id, mobType, data, model, options)
	mobs[id] = mob

	mob.Died:Connect(function()
		self:Despawn(mob, "Died")
	end)
	mob.EnabledChanged:Connect(markDevStateDirty)
	model.Destroying:Connect(function()
		-- Fell out of the world or destroyed by something else
		if mobs[id] then
			mob.ModelDestroyed = true
			self:Despawn(mob, "Destroyed")
		end
	end)

	CollectionService:AddTag(model, MobConfig.MobTag)

	if options.enabled then
		mob:Enable()
	end

	self.MobSpawned:Fire(mob)
	markDevStateDirty()
	return mob
end

function MobService:Enable(mob)
	mob:Enable()
end

function MobService:Disable(mob)
	mob:Disable()
end

function MobService:Despawn(mob, reason: string?)
	if not mobs[mob.Id] then return end
	mobs[mob.Id] = nil
	mob:Destroy()
	self.MobRemoved:Fire(mob, reason or "Despawned")
	markDevStateDirty()
end

function MobService:GetMob(id: number)
	return mobs[id]
end

function MobService:GetMobs()
	return mobs
end

-- Mobs whose model is `model` or contains `instance` (hit detection for the fighting system)
function MobService:GetMobFromInstance(instance: Instance)
	local model = instance:FindFirstAncestorWhichIsA("Model")
	while model and model.Parent ~= mobsFolder do
		model = model:FindFirstAncestorWhichIsA("Model")
	end
	local id = model and model:GetAttribute(MobConfig.Attributes.MobId)
	return id and mobs[id]
end

--|| Update loop ||--

local thinkInterval = 1 / MobConfig.ThinkRate

local function onHeartbeat(dt: number)
	for _, mob in pairs(mobs) do
		if not mob.IsDead then
			mob:Step(dt)
			mob.ThinkTimer -= dt
			if mob.ThinkTimer <= 0 then
				mob.ThinkTimer += thinkInterval
				mob:Think(thinkInterval)
			end
		end
	end
end

--|| Dev panel ||--

function MobService:GetDevState()
	local byType = {}
	local total, frozen, devSpawned = 0, 0, 0
	for _, mob in pairs(mobs) do
		total += 1
		byType[mob.Type] = (byType[mob.Type] or 0) + 1
		if not mob.Enabled then frozen += 1 end
		if mob.IsDevSpawn then devSpawned += 1 end
	end
	return {
		Total = total,
		Frozen = frozen,
		DevSpawned = devSpawned,
		ByType = byType,
		NaturalSpawning = MobSpawnService and MobSpawnService:IsEnabled() or false,
	}
end

function MobService:MarkDevStateDirty()
	markDevStateDirty()
end

local function fireDevState()
	local state = MobService:GetDevState()
	for _, player in ipairs(Players:GetPlayers()) do
		if isDev(player) then
			MobService.Client.DevStateChanged:Fire(player, state)
		end
	end
end

-- Mobs within `radius` of the player
local function getMobsNear(player: Player, radius: number)
	local root = getCharacterRoot(player)
	if not root then return {} end
	local result = {}
	for _, mob in pairs(mobs) do
		if (mob:GetPosition() - root.Position).Magnitude <= radius then
			table.insert(result, mob)
		end
	end
	return result
end

-- Spawn `amount` frozen mobs in a row in front of the player, facing them
function MobService.Client:DevSpawn(player: Player, mobType: string, amount: number?): number
	if not isDev(player) or not MobData.GetMob(mobType) then return 0 end
	local root = getCharacterRoot(player)
	if not root then return 0 end

	amount = math.clamp(math.floor(tonumber(amount) or 1), 1, DEV_MAX_SPAWN)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local right = Vector3.new(-look.Z, 0, look.X)
	local spawned = 0
	local jitter = amount == 1 and (math.random() * 2 - 1) * DEV_SPAWN_JITTER or 0
	for i = 1, amount do
		local sideOffset = (i - (amount + 1) / 2) * DEV_SPAWN_SPACING + jitter
		local point = root.Position + look * MobConfig.DevSpawnDistance + right * sideOffset
		local ground = SpawnUtils.findGroundAt(point, MobConfig.GroundTag) or (point - Vector3.new(0, 3, 0))
		local facing = CFrame.lookAt(ground, Vector3.new(root.Position.X, ground.Y, root.Position.Z))
		if self.Server:Spawn(mobType, facing, { enabled = false, isDevSpawn = true }) then
			spawned += 1
		end
	end
	return spawned
end

-- Start the behavior of every frozen mob
function MobService.Client:DevEnableAll(player: Player)
	if not isDev(player) then return end
	for _, mob in pairs(mobs) do
		mob:Enable()
	end
end

function MobService.Client:DevFreezeAll(player: Player)
	if not isDev(player) then return end
	for _, mob in pairs(mobs) do
		mob:Disable()
	end
end

function MobService.Client:DevFleeFromMe(player: Player)
	if not isDev(player) then return end
	for _, mob in ipairs(getMobsNear(player, DEV_ACTION_RADIUS)) do
		if mob.Enabled then
			mob:SetBehavior("Fleeing", { threat = player })
		end
	end
end

function MobService.Client:DevComeToMe(player: Player)
	if not isDev(player) then return end
	local root = getCharacterRoot(player)
	if not root then return end
	for _, mob in ipairs(getMobsNear(player, DEV_ACTION_RADIUS)) do
		if mob.Enabled then
			mob:SetBehavior("GoToPos", { position = root.Position, speedMode = "Run", arriveDistance = DEV_COME_DISTANCE })
		end
	end
end

function MobService.Client:DevChaseMe(player: Player)
	if not isDev(player) then return end
	for _, mob in ipairs(getMobsNear(player, DEV_ACTION_RADIUS)) do
		if mob.Enabled then
			mob:SetBehavior("Aggressive", { target = player })
		end
	end
end

-- Deal 1 damage to the closest mob (tests the hurt reaction before swords exist)
function MobService.Client:DevHitNearest(player: Player)
	if not isDev(player) then return end
	local root = getCharacterRoot(player)
	if not root then return end
	local nearest, nearestDistance = nil, DEV_HIT_RANGE
	for _, mob in pairs(mobs) do
		local distance = (mob:GetPosition() - root.Position).Magnitude
		if distance < nearestDistance then
			nearest, nearestDistance = mob, distance
		end
	end
	if nearest then
		nearest:TakeDamage(1, player)
	end
end

-- onlyDevSpawns = true: only the mobs spawned from the panel
function MobService.Client:DevDespawn(player: Player, onlyDevSpawns: boolean?)
	if not isDev(player) then return end
	for _, mob in pairs(mobs) do
		if not onlyDevSpawns or mob.IsDevSpawn then
			self.Server:Despawn(mob, "Despawned")
		end
	end
end

function MobService.Client:DevSetNaturalSpawning(player: Player, enabled: boolean)
	if not isDev(player) then return end
	MobSpawnService:SetEnabled(enabled == true)
end

function MobService.Client:GetDevState(player: Player)
	if not isDev(player) then return nil end
	return self.Server:GetDevState()
end

--|| Knit Lifecycle ||--

function MobService:KnitInit()
	mobsFolder = Workspace:FindFirstChild(MobConfig.MobsFolderName)
	if not mobsFolder then
		mobsFolder = Instance.new("Folder")
		mobsFolder.Name = MobConfig.MobsFolderName
		mobsFolder.Parent = Workspace
	end

	-- Water parts get their pathfinding label (ground mobs path around water)
	Water.Init()
end

function MobService:KnitStart()
	InventoryService = Knit.GetService("InventoryService")
	MobSpawnService = Knit.GetService("MobSpawnService")

	RunService.Heartbeat:Connect(onHeartbeat)

	task.spawn(function()
		while true do
			task.wait(DEV_STATE_INTERVAL)
			if devStateDirty then
				devStateDirty = false
				fireDevState()
			end
		end
	end)
end

return MobService
