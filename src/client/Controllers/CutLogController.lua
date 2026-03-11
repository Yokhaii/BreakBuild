--[[
	CutLogController.lua
	Handles proximity detection for CuttingLog station and shows the billboard UI

	The CuttingLog model is located at: BuildingZone > Platform > CuttingLog
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Player
local player = Players.LocalPlayer

-- CutLogController
local CutLogController = Knit.CreateController({
	Name = "CutLogController",
})

-- Private variables
local GeneralBillboardController
local CutLogService

local cuttingLogModel = nil
local isNearCuttingLog = false
local proximityConnection = nil

-- Constants
local PROXIMITY_DISTANCE = 10 -- How close the player needs to be to interact

--|| Private Functions ||--

-- Find the CuttingLog model in the BuildingZone
local function findCuttingLog()
	local buildingZone = Workspace:FindFirstChild("BuildingZone")
	if not buildingZone then
		return nil
	end

	local platform = buildingZone:FindFirstChild("Platform")
	if not platform then
		return nil
	end

	return platform:FindFirstChild("CuttingLog")
end

-- Get the position of the CuttingLog model
local function getCuttingLogPosition()
	if not cuttingLogModel then return nil end

	if cuttingLogModel:IsA("Model") and cuttingLogModel.PrimaryPart then
		return cuttingLogModel.PrimaryPart.Position
	elseif cuttingLogModel:IsA("BasePart") then
		return cuttingLogModel.Position
	elseif cuttingLogModel:IsA("Model") then
		-- Try to find any part to get position
		local part = cuttingLogModel:FindFirstChildWhichIsA("BasePart")
		if part then
			return part.Position
		end
	end

	return nil
end

-- Get the player's current position
local function getPlayerPosition()
	local character = player.Character
	if not character then return nil end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return nil end

	return humanoidRootPart.Position
end

-- Check distance between player and CuttingLog
local function checkProximity()
	local playerPos = getPlayerPosition()
	local cuttingLogPos = getCuttingLogPosition()

	if not playerPos or not cuttingLogPos then
		return false
	end

	local distance = (playerPos - cuttingLogPos).Magnitude
	return distance <= PROXIMITY_DISTANCE
end

-- Get the adornee part for the billboard (PrimaryPart of the CuttingLog model)
local function getCuttingLogAdornee()
	if not cuttingLogModel then return nil end

	if cuttingLogModel:IsA("Model") and cuttingLogModel.PrimaryPart then
		return cuttingLogModel.PrimaryPart
	elseif cuttingLogModel:IsA("BasePart") then
		return cuttingLogModel
	elseif cuttingLogModel:IsA("Model") then
		-- Fallback: find any part
		return cuttingLogModel:FindFirstChildWhichIsA("BasePart")
	end

	return nil
end

-- Handle entering proximity
local function onEnterProximity()
	if isNearCuttingLog then return end
	isNearCuttingLog = true

	-- Get the part to attach the billboard to
	local adorneePart = getCuttingLogAdornee()

	-- Show the billboard on the CuttingLog model
	GeneralBillboardController:Show("CuttingLog", {
		CuttingLogModel = cuttingLogModel,
	}, adorneePart)
end

-- Handle leaving proximity
local function onLeaveProximity()
	if not isNearCuttingLog then return end
	isNearCuttingLog = false

	-- Hide the billboard
	GeneralBillboardController:Hide()
end

-- Proximity check loop
local function startProximityCheck()
	proximityConnection = RunService.Heartbeat:Connect(function()
		-- Try to find CuttingLog if not found yet
		if not cuttingLogModel then
			cuttingLogModel = findCuttingLog()
			if not cuttingLogModel then
				return
			end
		end

		-- Check proximity
		local isNear = checkProximity()

		if isNear and not isNearCuttingLog then
			onEnterProximity()
		elseif not isNear and isNearCuttingLog then
			onLeaveProximity()
		end
	end)
end

-- Stop proximity check
local function stopProximityCheck()
	if proximityConnection then
		proximityConnection:Disconnect()
		proximityConnection = nil
	end
end

--|| Public Functions ||--

-- Manually show the CuttingLog billboard (for external triggers)
function CutLogController:ShowBillboard()
	local adorneePart = getCuttingLogAdornee()
	GeneralBillboardController:Show("CuttingLog", {
		CuttingLogModel = cuttingLogModel,
	}, adorneePart)
end

-- Manually hide the CuttingLog billboard
function CutLogController:HideBillboard()
	GeneralBillboardController:Hide()
end

-- Check if player is near the cutting log
function CutLogController:IsNearCuttingLog()
	return isNearCuttingLog
end

--|| Initialization ||--

function CutLogController:KnitStart()
	-- Get controllers and services
	GeneralBillboardController = Knit.GetController("GeneralBillboardController")
	CutLogService = Knit.GetService("CutLogService")

	-- Connect to service signals for feedback
	CutLogService.LogCut:Connect(function(logsUsed, planksReceived)
		print("[CutLogController] Cut", logsUsed, "logs into", planksReceived, "planks")
	end)

	CutLogService.CutFailed:Connect(function(reason)
		warn("[CutLogController] Cut failed:", reason)
	end)

	-- Start proximity detection
	startProximityCheck()

	-- Handle character respawn
	player.CharacterAdded:Connect(function()
		-- Reset state
		isNearCuttingLog = false
		cuttingLogModel = nil

		-- Re-find the cutting log
		task.wait(1) -- Wait for world to load
		cuttingLogModel = findCuttingLog()
	end)

	print("[CutLogController] Started")
end

return CutLogController
