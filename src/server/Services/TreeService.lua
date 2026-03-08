--[[
	TreeService.lua
	Handles tree spawning and respawning
	- Trees spawn at TreeAttachment inside Platform model
	- Logs are registered with BreakingService for unified breaking
	- Trees respawn after all logs broken, or 10x time if partially broken
	- State persists across sessions
]]

-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Data & Config
local TreeData = require(ReplicatedStorage.Shared.Data.TreeData)

-- Services (to be initialized)
local BreakingService
local DataService

local TreeService = Knit.CreateService({
	Name = "TreeService",
	Client = {
		-- Signals for client visual updates
		TreeStateChanged = Knit.CreateSignal(), -- (state, treeType, spawnProgress)
		TreeAboutToSpawn = Knit.CreateSignal(), -- (treeType, finalPosition) - for spawn animation
		TreeSpawned = Knit.CreateSignal(), -- (treeType, logIds)
		TreeFullyBroken = Knit.CreateSignal(), -- ()
	},
})

-- Private variables
local playerTrees: {[Player]: Model?} = {} -- Current tree model per player
local playerTreeAttachments: {[Player]: Attachment?} = {} -- Cached tree attachments
local playerLogCounts: {[Player]: {total: number, broken: number}} = {} -- Track logs per player

--|| Private Functions ||--

-- Get player's tree data from DataService
local function getTreeData(player: Player)
	if not DataService then return nil end
	local playerData = DataService:GetData(player)
	if not playerData then return nil end
	return playerData.Tree
end

-- Get BreakingZone for player
local function getBreakingZone(player: Player)
	local breakingZone = Workspace:FindFirstChild("BreakingZone")
	return breakingZone
end

-- Get TreeAttachment for player
local function getTreeAttachment(player: Player): Attachment?
	if playerTreeAttachments[player] then
		return playerTreeAttachments[player]
	end

	local breakingZone = getBreakingZone(player)
	if not breakingZone then return nil end

	local platform = breakingZone:FindFirstChild("Platform")
	if not platform then return nil end

	local attachment = nil
	if platform:IsA("Model") then
		for _, child in ipairs(platform:GetDescendants()) do
			if child:IsA("Attachment") and child.Name == "TreeAttachment" then
				attachment = child
				break
			end
		end
	elseif platform:IsA("BasePart") then
		attachment = platform:FindFirstChild("TreeAttachment")
	end

	playerTreeAttachments[player] = attachment
	return attachment
end

-- Get tree model from ReplicatedStorage
local function getTreeModel(treeType: string): Model?
	local treeConfig = TreeData.GetTree(treeType)
	if not treeConfig then return nil end

	local pathParts = string.split(treeConfig.modelPath, ".")
	local current = ReplicatedStorage

	local startIndex = 1
	if pathParts[1] == "ReplicatedStorage" then
		startIndex = 2
	end

	for i = startIndex, #pathParts do
		current = current:FindFirstChild(pathParts[i])
		if not current then
			warn("[TreeService] Tree model not found at path:", treeConfig.modelPath)
			return nil
		end
	end

	if not current:IsA("Model") then
		warn("[TreeService] Tree is not a Model:", treeConfig.modelPath)
		return nil
	end

	return current
end

-- Count breakable logs in a tree model (counts both BaseParts and Models with the name)
local function countLogs(treeModel: Model, breakablePartName: string): number
	local count = 0
	for _, descendant in ipairs(treeModel:GetDescendants()) do
		local isBreakableModel = descendant:IsA("Model") and descendant.Name == breakablePartName
		-- Only count BasePart if it's NOT inside a Model with the same breakable name (avoid double counting)
		local isBreakablePart = descendant:IsA("BasePart") and descendant.Name == breakablePartName
		if isBreakablePart then
			-- Check if parent is a Model with same name - if so, skip (the Model will be counted)
			if descendant.Parent and descendant.Parent:IsA("Model") and descendant.Parent.Name == breakablePartName then
				isBreakablePart = false
			end
		end

		if isBreakablePart or isBreakableModel then
			count = count + 1
		end
	end
	return count
end

-- Handle when a log is broken
local function onLogBroken(player: Player, logId: string)
	local treeData = getTreeData(player)
	if not treeData then return end

	-- Add to broken logs
	table.insert(treeData.BrokenLogs, logId)

	-- Update log count
	if playerLogCounts[player] then
		playerLogCounts[player].broken = playerLogCounts[player].broken + 1

		-- Check if all logs broken
		if playerLogCounts[player].broken >= playerLogCounts[player].total then
			-- Destroy tree model (leaves, trunk base, etc.)
			if playerTrees[player] then
				playerTrees[player]:Destroy()
				playerTrees[player] = nil
			end

			-- Start respawn (full break)
			local treeType = treeData.SelectedTreeType or TreeData.DefaultTreeType
			local treeConfig = TreeData.GetTree(treeType)
			if treeConfig then
				treeData.State = "respawning"
				treeData.RespawnStartedAt = os.time()
				treeData.RespawnDuration = treeConfig.spawnTime
				treeData.BrokenLogs = {}

				TreeService.Client.TreeStateChanged:Fire(player, "respawning", treeType, 0)
			end

			-- Notify client
			TreeService.Client.TreeFullyBroken:Fire(player)

			-- Clear log counts
			playerLogCounts[player] = nil
		end
	end
end

-- Spawn tree for player
local function spawnTree(player: Player)
	local treeData = getTreeData(player)
	if not treeData then return end

	local treeType = treeData.SelectedTreeType or TreeData.DefaultTreeType
	local treeConfig = TreeData.GetTree(treeType)
	if not treeConfig then return end

	local attachment = getTreeAttachment(player)
	if not attachment then
		warn("[TreeService] No TreeAttachment found for player:", player.Name)
		return
	end

	local treeTemplate = getTreeModel(treeType)
	if not treeTemplate then return end

	-- Clone and position tree
	local treeModel = treeTemplate:Clone()
	treeModel.Name = "PlayerTree_" .. player.UserId

	local finalPosition = attachment.WorldPosition

	-- Notify client that tree is about to spawn
	TreeService.Client.TreeAboutToSpawn:Fire(player, treeType, finalPosition)

	if treeModel.PrimaryPart then
		treeModel:SetPrimaryPartCFrame(CFrame.new(finalPosition))
	end

	-- Store player reference
	local playerIdValue = Instance.new("IntValue")
	playerIdValue.Name = "PlayerId"
	playerIdValue.Value = player.UserId
	playerIdValue.Parent = treeModel

	-- Store final position for client
	local finalPosValue = Instance.new("Vector3Value")
	finalPosValue.Name = "FinalPosition"
	finalPosValue.Value = finalPosition
	finalPosValue.Parent = treeModel

	-- Parent to BreakingZone
	local breakingZone = getBreakingZone(player)
	if breakingZone then
		treeModel.Parent = breakingZone
	else
		treeModel.Parent = Workspace
	end

	-- Process logs: assign IDs and register with BreakingService
	local breakablePartName = treeConfig.breakablePartName
	local logIndex = 0
	local remainingLogs = {}
	local totalLogs = countLogs(treeTemplate, breakablePartName)

	for _, descendant in ipairs(treeModel:GetDescendants()) do
		-- Check for Model with breakablePartName (use PrimaryPart for values)
		local isBreakableModel = descendant:IsA("Model") and descendant.Name == breakablePartName and descendant.PrimaryPart
		-- Check for BasePart with breakablePartName (but NOT if inside a Model with same name)
		local isBreakablePart = descendant:IsA("BasePart") and descendant.Name == breakablePartName
		if isBreakablePart then
			-- Skip if parent is a Model with same name (the Model will be processed instead)
			if descendant.Parent and descendant.Parent:IsA("Model") and descendant.Parent.Name == breakablePartName then
				isBreakablePart = false
			end
		end

		if isBreakablePart or isBreakableModel then
			logIndex = logIndex + 1
			local logId = "tree_" .. player.UserId .. "_log_" .. tostring(logIndex)

			-- Check if this log was already broken
			local isBroken = false
			for _, brokenLog in ipairs(treeData.BrokenLogs) do
				if brokenLog == logId then
					isBroken = true
					break
				end
			end

			if isBroken then
				descendant:Destroy()
			else
				-- Determine target for values (PrimaryPart for Models, the part itself for BaseParts)
				local targetPart = isBreakableModel and descendant.PrimaryPart or descendant
				local targetInstance = descendant -- The actual thing to destroy/highlight

				-- Add BreakableId for client detection
				local breakableIdValue = Instance.new("StringValue")
				breakableIdValue.Name = "BreakableId"
				breakableIdValue.Value = logId
				breakableIdValue.Parent = targetPart

				-- Add PlayerId for client detection
				local partPlayerIdValue = Instance.new("IntValue")
				partPlayerIdValue.Name = "PlayerId"
				partPlayerIdValue.Value = player.UserId
				partPlayerIdValue.Parent = targetPart

				-- Add MaterialType for client
				local materialValue = Instance.new("StringValue")
				materialValue.Name = "MaterialType"
				materialValue.Value = treeConfig.materialType
				materialValue.Parent = targetPart

				-- Register with BreakingService
				if BreakingService then
					BreakingService:RegisterBreakable(player, logId, {
						materialType = treeConfig.materialType,
						dropItem = treeConfig.dropItem,
						dropAmount = 1,
						position = targetPart.Position,
						part = targetInstance, -- Destroy the whole model/part
						customBreakTime = treeConfig.breakTime,
						onBroken = function(p, id)
							onLogBroken(p, id)
						end,
					})
				end

				table.insert(remainingLogs, logId)
			end
		end
	end

	-- Update data
	treeData.State = "spawned"
	treeData.TotalLogs = totalLogs

	-- Track log counts
	playerLogCounts[player] = {
		total = totalLogs,
		broken = #treeData.BrokenLogs,
	}

	-- Store runtime reference
	playerTrees[player] = treeModel

	-- Notify client
	TreeService.Client.TreeSpawned:Fire(player, treeType, remainingLogs)
end

-- Start respawn timer for player
local function startRespawn(player: Player, isPartialBreak: boolean)
	local treeData = getTreeData(player)
	if not treeData then return end

	local treeType = treeData.SelectedTreeType or TreeData.DefaultTreeType
	local treeConfig = TreeData.GetTree(treeType)
	if not treeConfig then return end

	local respawnDuration = treeConfig.spawnTime
	if isPartialBreak then
		respawnDuration = treeConfig.spawnTime * treeConfig.respawnMultiplier
	end

	treeData.State = "respawning"
	treeData.RespawnStartedAt = os.time()
	treeData.RespawnDuration = respawnDuration
	treeData.BrokenLogs = {}

	TreeService.Client.TreeStateChanged:Fire(player, "respawning", treeType, 0)
end

--|| Public Functions ||--

-- Get current tree state for player
function TreeService:GetTreeState(player: Player)
	local treeData = getTreeData(player)
	if not treeData then return nil end

	return {
		state = treeData.State,
		treeType = treeData.SelectedTreeType,
		brokenLogs = treeData.BrokenLogs,
		totalLogs = treeData.TotalLogs,
	}
end

-- Change selected tree type
function TreeService:SelectTreeType(player: Player, treeType: string): boolean
	local treeConfig = TreeData.GetTree(treeType)
	if not treeConfig then return false end

	local treeData = getTreeData(player)
	if not treeData then return false end

	if treeData.State == "spawned" then
		return false
	end

	treeData.SelectedTreeType = treeType

	if treeData.State == nil then
		treeData.State = "spawning"
		treeData.SpawnStartedAt = os.time()
	end

	return true
end

--|| Client Functions ||--

function TreeService.Client:GetTreeState(player: Player)
	return self.Server:GetTreeState(player)
end

function TreeService.Client:SelectTreeType(player: Player, treeType: string)
	return self.Server:SelectTreeType(player, treeType)
end

--|| Spawn/Respawn Loop ||--

local function updateTreeSpawning()
	local currentTime = os.time()

	for _, player in ipairs(Players:GetPlayers()) do
		local treeData = getTreeData(player)
		if not treeData then continue end

		if treeData.State == "spawning" then
			local treeType = treeData.SelectedTreeType or TreeData.DefaultTreeType
			local treeConfig = TreeData.GetTree(treeType)
			if not treeConfig then continue end

			local elapsed = currentTime - treeData.SpawnStartedAt
			local progress = math.clamp(elapsed / treeConfig.spawnTime, 0, 1)

			if progress >= 1 then
				spawnTree(player)
			else
				TreeService.Client.TreeStateChanged:Fire(player, "spawning", treeType, progress)
			end

		elseif treeData.State == "respawning" then
			local elapsed = currentTime - treeData.RespawnStartedAt
			local progress = math.clamp(elapsed / treeData.RespawnDuration, 0, 1)

			if progress >= 1 then
				treeData.State = "spawning"
				treeData.SpawnStartedAt = os.time()
				treeData.RespawnStartedAt = 0
				treeData.RespawnDuration = 0
			else
				local treeType = treeData.SelectedTreeType or TreeData.DefaultTreeType
				TreeService.Client.TreeStateChanged:Fire(player, "respawning", treeType, progress)
			end
		end
	end
end

-- Clean up player's tree
local function cleanupPlayerTree(player: Player)
	-- Unregister all logs from BreakingService
	if BreakingService and playerLogCounts[player] then
		local treeData = getTreeData(player)
		if treeData then
			for _, logId in ipairs(treeData.BrokenLogs or {}) do
				BreakingService:UnregisterBreakable(player, logId)
			end
		end
	end

	playerLogCounts[player] = nil
	playerTreeAttachments[player] = nil

	if playerTrees[player] then
		playerTrees[player]:Destroy()
		playerTrees[player] = nil
	end
end

--|| Knit Lifecycle ||--

function TreeService:KnitInit()
	-- Initialize
end

function TreeService:KnitStart()
	BreakingService = Knit.GetService("BreakingService")
	DataService = Knit.GetService("DataService")

	-- Handle player joining
	local function onPlayerAdded(player: Player)
		player.CharacterAdded:Connect(function()
			task.wait(1.5)

			local treeData = getTreeData(player)
			if not treeData then return end

			if treeData.State == nil then
				treeData.State = "spawning"
				treeData.SpawnStartedAt = os.time()
				treeData.SelectedTreeType = treeData.SelectedTreeType or TreeData.DefaultTreeType
			end

			if treeData.State == "spawned" then
				spawnTree(player)
			end

			local treeType = treeData.SelectedTreeType or TreeData.DefaultTreeType
			self.Client.TreeStateChanged:Fire(player, treeData.State, treeType, 0)
		end)

		if player.Character then
			task.spawn(function()
				task.wait(1.5)

				local treeData = getTreeData(player)
				if not treeData then return end

				if treeData.State == nil then
					treeData.State = "spawning"
					treeData.SpawnStartedAt = os.time()
					treeData.SelectedTreeType = treeData.SelectedTreeType or TreeData.DefaultTreeType
				end

				if treeData.State == "spawned" then
					spawnTree(player)
				end

				local treeType = treeData.SelectedTreeType or TreeData.DefaultTreeType
				self.Client.TreeStateChanged:Fire(player, treeData.State, treeType, 0)
			end)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Cleanup on player leave
	Players.PlayerRemoving:Connect(function(player)
		cleanupPlayerTree(player)
	end)

	-- Spawn/respawn check every second
	task.spawn(function()
		while true do
			task.wait(1)
			updateTreeSpawning()
		end
	end)
end

return TreeService
