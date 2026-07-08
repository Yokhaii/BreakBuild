--[[
	TreeService.lua
	Manages world-spawned trees (not per-player).
	- Finds ground positions inside Outside boundary parts via raycast
	- Only spawns on parts tagged with the Ground CollectionService tag
	- Trees are global breakables registered with BreakingService
	- Broken trees respawn after RespawnDelay seconds
	- Spawn type and frequency are configurable in TreeSpawnConfig
]]

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TreeData = require(ReplicatedStorage.Shared.Data.TreeData)
local TreeSpawnConfig = require(ReplicatedStorage.Shared.Config.TreeSpawnConfig)
local SpawnUtils = require(game:GetService("ServerScriptService").Server.Modules.SpawnUtils)

local BreakingService

local TreeService = Knit.CreateService({
	Name = "TreeService",
	Client = {},
})

-- type for a live tree entry
type TreeEntry = {
	id: string,
	treeType: string,
	model: Model,
	position: Vector3,
	logCount: number,
	brokenLogs: number,
}

-- id -> entry for currently alive trees
local liveTrees: {[string]: TreeEntry} = {}

-- positions currently occupied (kept in sync with liveTrees)
local occupiedPositions: {Vector3} = {}

-- ids queued for respawn: id -> os.time() when it becomes eligible
local respawnQueue: {[string]: number} = {}

-- monotonic counter for unique ids
local nextTreeIndex = 0

--|| Helpers ||--

local function getTreeModel(treeType: string): Model?
	local config = TreeData.GetTree(treeType)
	if not config then return nil end

	local pathParts = string.split(config.modelPath, ".")
	local current = ReplicatedStorage
	local startIndex = (pathParts[1] == "ReplicatedStorage") and 2 or 1

	for i = startIndex, #pathParts do
		current = current:FindFirstChild(pathParts[i])
		if not current then
			warn("[TreeService] Model not found at path:", config.modelPath)
			return nil
		end
	end

	if not current:IsA("Model") then
		warn("[TreeService] Path is not a Model:", config.modelPath)
		return nil
	end

	return current
end

local function countBreakableLogs(treeModel: Model, breakablePartName: string): number
	local count = 0
	for _, desc in ipairs(treeModel:GetDescendants()) do
		if desc:IsA("Model") and desc.Name == breakablePartName then
			count = count + 1
		elseif desc:IsA("BasePart") and desc.Name == breakablePartName then
			-- Skip BaseParts that are the direct child of a Model of the same name (avoid double-counting)
			if not (desc.Parent and desc.Parent:IsA("Model") and desc.Parent.Name == breakablePartName) then
				count = count + 1
			end
		end
	end
	return count
end

local function removeOccupiedPosition(pos: Vector3)
	for i, p in ipairs(occupiedPositions) do
		if p == pos then
			table.remove(occupiedPositions, i)
			return
		end
	end
end

--|| Per-log break callback ||--

local function onLogBroken(treeId: string, logId: string)
	local entry = liveTrees[treeId]
	if not entry then return end

	entry.brokenLogs = entry.brokenLogs + 1

	if entry.brokenLogs >= entry.logCount then
		-- All logs gone — destroy remaining model and schedule respawn
		if entry.model and entry.model.Parent then
			entry.model:Destroy()
		end

		removeOccupiedPosition(entry.position)
		liveTrees[treeId] = nil

		respawnQueue[treeId] = os.time() + TreeSpawnConfig.RespawnDelay
	end
end

--|| Spawn a single tree at a given position ||--

local function spawnTree(treeType: string, position: Vector3)
	local config = TreeData.GetTree(treeType)
	if not config then return end

	local template = getTreeModel(treeType)
	if not template then return end

	nextTreeIndex = nextTreeIndex + 1
	local treeId = "world_tree_" .. tostring(nextTreeIndex)

	local treeModel = template:Clone()
	treeModel.Name = "WorldTree_" .. treeId

	local spawnPosition = position + Vector3.new(0, TreeSpawnConfig.SpawnHeightOffset, 0)

	if treeModel.PrimaryPart then
		local rotation = math.random(0, 3) * (math.pi / 2)
		treeModel:SetPrimaryPartCFrame(CFrame.new(spawnPosition) * CFrame.Angles(0, rotation, 0))
	end

	-- Store in Outside folder (or Workspace as fallback)
	local outside = Workspace:FindFirstChild(TreeSpawnConfig.OutsideFolderName)
	treeModel.Parent = outside or Workspace

	-- Register each breakable log as a global breakable
	local logIndex = 0
	local logCount = countBreakableLogs(template, config.breakablePartName)

	for _, desc in ipairs(treeModel:GetDescendants()) do
		local isModel = desc:IsA("Model") and desc.Name == config.breakablePartName and desc.PrimaryPart
		local isPart = desc:IsA("BasePart") and desc.Name == config.breakablePartName
		if isPart then
			if desc.Parent and desc.Parent:IsA("Model") and desc.Parent.Name == config.breakablePartName then
				isPart = false
			end
		end

		if isModel or isPart then
			logIndex = logIndex + 1
			local logId = treeId .. "_log_" .. tostring(logIndex)

			local targetPart = isModel and desc.PrimaryPart or desc

			-- Tag for BreakingController detection
			local idVal = Instance.new("StringValue")
			idVal.Name = "BreakableId"
			idVal.Value = logId
			idVal.Parent = targetPart

			-- PlayerId 0 = global (any player can break it)
			local pidVal = Instance.new("IntValue")
			pidVal.Name = "PlayerId"
			pidVal.Value = 0
			pidVal.Parent = targetPart

			local matVal = Instance.new("StringValue")
			matVal.Name = "MaterialType"
			matVal.Value = config.materialType
			matVal.Parent = targetPart

			local capturedTreeId = treeId
			local capturedLogId = logId

			BreakingService:RegisterGlobalBreakable(logId, {
				materialType = config.materialType,
				dropItem = config.dropItem,
				dropAmount = 1,
				position = targetPart.Position,
				part = isModel and desc or desc,
				customBreakTime = config.breakTime,
				onBroken = function(_, _)
					onLogBroken(capturedTreeId, capturedLogId)
				end,
			})
		end
	end

	liveTrees[treeId] = {
		id = treeId,
		treeType = treeType,
		model = treeModel,
		position = spawnPosition,
		logCount = logCount,
		brokenLogs = 0,
	}
	table.insert(occupiedPositions, spawnPosition)
end

--|| Collect boundary parts from Outside folder ||--

local function getBoundaryParts(): {BasePart}
	local folder = Workspace:FindFirstChild(TreeSpawnConfig.OutsideFolderName)
	if not folder then
		warn("[TreeService] Outside folder not found:", TreeSpawnConfig.OutsideFolderName)
		return {}
	end

	local parts = {}
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("BasePart") and child.Name == TreeSpawnConfig.BoundaryPartName then
			table.insert(parts, child)
		end
	end

	return parts
end

-- Spawn as many trees as needed to reach MaxTrees, all in parallel
local function fillTrees()
	local currentCount = 0
	for _ in pairs(liveTrees) do currentCount = currentCount + 1 end

	local needed = TreeSpawnConfig.MaxTrees - currentCount
	if needed <= 0 then return end

	local boundaryParts = getBoundaryParts()
	if #boundaryParts == 0 then return end

	for _ = 1, needed do
		local boundaryPart = boundaryParts[math.random(1, #boundaryParts)]
		local position = SpawnUtils.findGroundPosition(
			boundaryPart,
			TreeSpawnConfig.GroundTag,
			occupiedPositions,
			TreeSpawnConfig.MinTreeSeparation
		)
		if position then
			local treeType = SpawnUtils.pickWeightedRandom(TreeSpawnConfig.TreeWeights)
			if treeType then
				-- Reserve the position immediately so parallel spawns don't overlap
				table.insert(occupiedPositions, position)
				task.spawn(function()
					-- Remove the pre-reserved position; spawnTree will re-add via liveTrees
					removeOccupiedPosition(position)
					spawnTree(treeType, position)
				end)
			end
		end
	end
end

--|| Respawn check ||--

local function processRespawnQueue()
	local now = os.time()
	for id, eligibleAt in pairs(respawnQueue) do
		if now >= eligibleAt then
			respawnQueue[id] = nil
			-- Just let the normal spawn loop fill the slot; no need to force
			-- (the id is already removed from liveTrees)
		end
	end
end

--|| Knit Lifecycle ||--

function TreeService:KnitInit()
end

function TreeService:KnitStart()
	BreakingService = Knit.GetService("BreakingService")

	-- Initial fill: spawn all trees in parallel once world has loaded
	task.spawn(function()
		task.wait(2)
		fillTrees()
	end)

	-- Periodic loop: top up any missing trees and process respawns
	task.spawn(function()
		while true do
			task.wait(TreeSpawnConfig.SpawnInterval)
			processRespawnQueue()
			fillTrees()
		end
	end)
end

return TreeService
