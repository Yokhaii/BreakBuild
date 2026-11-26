--[[
	MobSpawnService.lua
	Natural mob spawning in the Outside zone (where trees spawn), as small herds:
	- Every SpawnInterval, picks a mob type below its maxAlive cap (weighted) and spawns a
	  herd of herdSize mobs around a ground point, away from other herds and players
	- Herd members patrol around the herd center (their home position)
	- Herds only spawn in their mob's habitat (ground mobs: never in water)
	- A dead / despawned natural mob blocks its type for RespawnDelay seconds
	Spawning itself goes through MobService:Spawn. Tuning: Shared.Config.MobSpawnConfig.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)

local MobData = require(ReplicatedStorage.Shared.Data.MobData)
local MobSpawnConfig = require(ReplicatedStorage.Shared.Config.MobSpawnConfig)
local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)
local SpawnUtils = require(script.Parent.Parent.Modules.SpawnUtils)
local Water = require(script.Parent.Parent.Classes.Mobs.Navigation.Water)

local MobService

local MobSpawnService = Knit.CreateService({
	Name = "MobSpawnService",
	Client = {},
})

local CENTER_TRIES = 4 -- boundary parts tried per herd
local SPOT_CHECK_RADIUS = 2 -- studs kept free around a herd member's spawn point
local HABITAT_CHECK_OFFSET = Vector3.new(0, 0.5, 0) -- habitat is tested just above the ground

local enabled = MobSpawnConfig.Enabled

-- herdId -> { mobType, center, members = { [mobId] = true } }
local herds = {}
local nextHerdId = 0
-- mobId -> herdId, natural mobs only
local naturalMobs = {}
-- mobType -> os.clock() before which it can't spawn again
local blockedUntil = {}

--|| Helpers ||--

local function getBoundaryParts(): { BasePart }
	local folder = Workspace:FindFirstChild(MobSpawnConfig.OutsideFolderName)
	if not folder then return {} end
	local parts = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") then
			table.insert(parts, child)
		end
	end
	return parts
end

local function countNatural(mobType: string): number
	local count = 0
	for _, herd in pairs(herds) do
		if herd.mobType == mobType then
			for _ in pairs(herd.members) do
				count += 1
			end
		end
	end
	return count
end

local function isFarFromPlayers(position: Vector3): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - position).Magnitude < MobSpawnConfig.MinPlayerDistance then
			return false
		end
	end
	return true
end

-- Nothing solid (tree, wall) at this ground point
local function isSpotFree(position: Vector3): boolean
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local mobsFolder = Workspace:FindFirstChild(MobConfig.MobsFolderName)
	params.FilterDescendantsInstances = mobsFolder and { mobsFolder } or {}
	params.RespectCanCollide = true
	local center = position + Vector3.new(0, SPOT_CHECK_RADIUS + 0.5, 0)
	return #Workspace:GetPartBoundsInRadius(center, SPOT_CHECK_RADIUS, params) == 0
end

-- The mob type's habitat allows this ground point (ground mobs: not in water)
local function isInHabitat(mobType: string, position: Vector3): boolean
	local data = MobData.GetMob(mobType)
	return Water.IsAllowed(data and data.habitat, position + HABITAT_CHECK_OFFSET)
end

local function findHerdCenter(mobType: string): Vector3?
	local boundaries = getBoundaryParts()
	if #boundaries == 0 then
		warn("[MobSpawnService] No boundary parts in Workspace." .. MobSpawnConfig.OutsideFolderName)
		return nil
	end

	local existingCenters = {}
	for _, herd in pairs(herds) do
		table.insert(existingCenters, herd.center)
	end

	for _ = 1, CENTER_TRIES do
		local boundary = boundaries[math.random(1, #boundaries)]
		local center = SpawnUtils.findGroundPosition(boundary, MobSpawnConfig.GroundTag, existingCenters, MobSpawnConfig.MinHerdSeparation)
		if center and isFarFromPlayers(center) and isSpotFree(center) and isInHabitat(mobType, center) then
			return center
		end
	end
	return nil
end

local function spawnHerd(mobType: string)
	local spawnConfig = MobSpawnConfig.Mobs[mobType]
	local room = spawnConfig.maxAlive - countNatural(mobType)
	if room <= 0 then return end

	local center = findHerdCenter(mobType)
	if not center then return end

	local size = math.min(math.random(spawnConfig.herdSize[1], spawnConfig.herdSize[2]), room)

	nextHerdId += 1
	local herdId = nextHerdId
	local herd = { mobType = mobType, center = center, members = {} }
	herds[herdId] = herd

	for i = 1, size do
		local position = center
		if i > 1 then
			local angle = math.random() * 2 * math.pi
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle)) * (2 + math.random() * (MobSpawnConfig.HerdRadius - 2))
			local ground = SpawnUtils.findGroundAt(center + offset, MobSpawnConfig.GroundTag)
			position = (ground and isSpotFree(ground) and isInHabitat(mobType, ground)) and ground or nil
		end
		if position then
			local cframe = CFrame.new(position) * CFrame.Angles(0, math.random() * 2 * math.pi, 0)
			local mob = MobService:Spawn(mobType, cframe, { enabled = true, homePosition = center })
			if mob then
				herd.members[mob.Id] = true
				naturalMobs[mob.Id] = herdId
			end
		end
	end

	if next(herd.members) == nil then
		herds[herdId] = nil
	end
end

local function spawnPass()
	local now = os.clock()
	for _ = 1, MobSpawnConfig.MaxHerdsPerPass do
		local weights = {}
		local hasCandidate = false
		for mobType, spawnConfig in pairs(MobSpawnConfig.Mobs) do
			if countNatural(mobType) < spawnConfig.maxAlive and now >= (blockedUntil[mobType] or 0) then
				weights[mobType] = spawnConfig.weight
				hasCandidate = true
			end
		end
		if not hasCandidate then return end

		local mobType = SpawnUtils.pickWeightedRandom(weights)
		if mobType then
			spawnHerd(mobType)
		end
	end
end

local function onMobRemoved(mob)
	local herdId = naturalMobs[mob.Id]
	if not herdId then return end
	naturalMobs[mob.Id] = nil
	blockedUntil[mob.Type] = os.clock() + MobSpawnConfig.RespawnDelay

	local herd = herds[herdId]
	if herd then
		herd.members[mob.Id] = nil
		if next(herd.members) == nil then
			herds[herdId] = nil
		end
	end
end

--|| Public API ||--

function MobSpawnService:IsEnabled(): boolean
	return enabled
end

-- Turn natural spawning on / off (mobs already alive stay)
function MobSpawnService:SetEnabled(isEnabled: boolean)
	if enabled == isEnabled then return end
	enabled = isEnabled
	MobService:MarkDevStateDirty()
end

function MobSpawnService:IsNaturalMob(mob): boolean
	return naturalMobs[mob.Id] ~= nil
end

--|| Knit Lifecycle ||--

function MobSpawnService:KnitStart()
	MobService = Knit.GetService("MobService")
	MobService.MobRemoved:Connect(onMobRemoved)

	task.delay(MobSpawnConfig.InitialDelay, function()
		while true do
			if enabled then
				spawnPass()
			end
			task.wait(MobSpawnConfig.SpawnInterval)
		end
	end)
end

return MobSpawnService
