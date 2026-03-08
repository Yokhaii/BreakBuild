--[[
	TreeController.lua
	Client-side tree visual handling
	- Plays tree spawn animations
	- Handles tree state UI updates
	- Breaking is handled by unified BreakingController
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Player
local player = Players.LocalPlayer

-- Data
local TreeData = require(ReplicatedStorage.Shared.Data.TreeData)

-- TreeController
local TreeController = Knit.CreateController({
	Name = "TreeController",
})

-- Constants
local SPAWN_START_OFFSET = -10
local SPAWN_ANIMATION_DURATION = 1.0

-- Private variables
local TreeService
local currentTreeModel: Model? = nil
local currentTreeType: string? = nil

--|| Private Functions ||--

local function getBreakingZone()
	return Workspace:FindFirstChild("BreakingZone")
end

-- Get tree model template from ReplicatedStorage
local function getTreeModelTemplate(treeType: string): Model?
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
			return nil
		end
	end

	if not current:IsA("Model") then
		return nil
	end

	return current
end

-- Play tree spawn animation
local function playTreeSpawnAnimation(treeType: string, finalPosition: Vector3)
	local template = getTreeModelTemplate(treeType)
	if not template then return end

	-- Create animation model
	local animModel = template:Clone()
	animModel.Name = "TreeSpawnAnim"

	-- Make non-collidable during animation
	for _, part in ipairs(animModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.Transparency = part.Transparency -- Keep original transparency
		end
	end

	-- Start underground
	local startY = finalPosition.Y + SPAWN_START_OFFSET
	if animModel.PrimaryPart then
		animModel:SetPrimaryPartCFrame(CFrame.new(finalPosition.X, startY, finalPosition.Z))
	end

	-- Parent to BreakingZone
	local zone = getBreakingZone()
	animModel.Parent = zone or Workspace

	-- Animate up
	local animPart = animModel.PrimaryPart
	if not animPart then
		animModel:Destroy()
		return
	end

	local overshootY = finalPosition.Y + 2

	-- Phase 1: Rise with overshoot
	local tween1 = TweenService:Create(
		animPart,
		TweenInfo.new(SPAWN_ANIMATION_DURATION * 0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{Position = Vector3.new(finalPosition.X, overshootY, finalPosition.Z)}
	)

	tween1:Play()
	tween1.Completed:Wait()

	-- Phase 2: Settle
	local tween2 = TweenService:Create(
		animPart,
		TweenInfo.new(SPAWN_ANIMATION_DURATION * 0.4, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out),
		{Position = finalPosition}
	)

	tween2:Play()
	tween2.Completed:Wait()

	-- Cleanup animation model (server model should exist now)
	animModel:Destroy()
end

--|| Event Handlers ||--

local function onTreeAboutToSpawn(treeType: string, finalPosition: Vector3)
	currentTreeType = treeType

	-- Play spawn animation
	task.spawn(function()
		playTreeSpawnAnimation(treeType, finalPosition)
	end)
end

local function onTreeSpawned(treeType: string, logIds: {string})
	currentTreeType = treeType

	-- Find tree model in BreakingZone
	local zone = getBreakingZone()
	if zone then
		local treeName = "PlayerTree_" .. player.UserId
		currentTreeModel = zone:FindFirstChild(treeName)
	end

	print("[TreeController] Tree spawned with", #logIds, "logs")
end

local function onTreeFullyBroken()
	currentTreeModel = nil
	currentTreeType = nil
	print("[TreeController] Tree fully broken")
end

local function onTreeStateChanged(state: string, treeType: string, progress: number)
	-- Could update UI here to show spawn/respawn progress
	if state == "spawning" then
		-- Show spawning progress
	elseif state == "respawning" then
		-- Show respawn progress
	end
end

--|| Public Functions ||--

function TreeController:GetCurrentTreeType(): string?
	return currentTreeType
end

function TreeController:GetCurrentTreeModel(): Model?
	return currentTreeModel
end

--|| Knit Lifecycle ||--

function TreeController:KnitInit()
	-- Initialize
end

function TreeController:KnitStart()
	TreeService = Knit.GetService("TreeService")

	-- Connect to TreeService events
	TreeService.TreeAboutToSpawn:Connect(onTreeAboutToSpawn)
	TreeService.TreeSpawned:Connect(onTreeSpawned)
	TreeService.TreeFullyBroken:Connect(onTreeFullyBroken)
	TreeService.TreeStateChanged:Connect(onTreeStateChanged)

	-- Get initial state
	task.spawn(function()
		local state = TreeService:GetTreeState()
		if state then
			currentTreeType = state.treeType

			if state.state == "spawned" then
				-- Tree already exists, find it
				local zone = getBreakingZone()
				if zone then
					local treeName = "PlayerTree_" .. player.UserId
					currentTreeModel = zone:FindFirstChild(treeName)
				end
			end
		end
	end)
end

return TreeController
