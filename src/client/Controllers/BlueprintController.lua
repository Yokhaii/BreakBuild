--[[
	BlueprintController.lua
	Handles proximity detection for Blueprints table and shows the billboard UI
	Also handles auto-closing the Blueprint menu when player walks too far away

	The Blueprints model is located at: BuildingZone > Platform > Blueprints
]]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterPlayer = game:GetService("StarterPlayer")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Rodux
local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)
local UIActions = require(Client.Rodux.Actions.UIActions)

-- Player
local player = Players.LocalPlayer

-- BlueprintController
local BlueprintController = Knit.CreateController({
	Name = "BlueprintController",
})

-- Private variables
local GeneralBillboardController

local blueprintsModel = nil
local isNearBlueprints = false
local isBlueprintMenuOpen = false
local proximityConnection = nil
local menuDistanceConnection = nil

-- Constants
local PROXIMITY_DISTANCE = 10 -- How close the player needs to be to see billboard
local MENU_CLOSE_DISTANCE = 15 -- How far the player can be before menu auto-closes

--|| Private Functions ||--

-- Find the Blueprints model in the BuildingZone
local function findBlueprints()
	local buildingZone = Workspace:FindFirstChild("BuildingZone")
	if not buildingZone then
		warn("[BlueprintController] BuildingZone not found in Workspace")
		return nil
	end

	local platform = buildingZone:FindFirstChild("Platform")
	if not platform then
		warn("[BlueprintController] Platform not found in BuildingZone")
		return nil
	end

	local blueprints = platform:FindFirstChild("Blueprints")
	if not blueprints then
		warn("[BlueprintController] Blueprints model not found in Platform")
		return nil
	end

	print("[BlueprintController] Found Blueprints model:", blueprints:GetFullName())
	return blueprints
end

-- Get the position of the Blueprints model
local function getBlueprintsPosition()
	if not blueprintsModel then return nil end

	if blueprintsModel:IsA("Model") and blueprintsModel.PrimaryPart then
		return blueprintsModel.PrimaryPart.Position
	elseif blueprintsModel:IsA("BasePart") then
		return blueprintsModel.Position
	elseif blueprintsModel:IsA("Model") then
		-- Try to find any part to get position
		local part = blueprintsModel:FindFirstChildWhichIsA("BasePart")
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

-- Check distance between player and Blueprints
local function checkProximity(maxDistance)
	local playerPos = getPlayerPosition()
	local blueprintsPos = getBlueprintsPosition()

	if not playerPos or not blueprintsPos then
		return false
	end

	local distance = (playerPos - blueprintsPos).Magnitude
	return distance <= maxDistance
end

-- Get the adornee part for the billboard (PrimaryPart of the Blueprints model)
local function getBlueprintsAdornee()
	if not blueprintsModel then return nil end

	if blueprintsModel:IsA("Model") and blueprintsModel.PrimaryPart then
		return blueprintsModel.PrimaryPart
	elseif blueprintsModel:IsA("BasePart") then
		return blueprintsModel
	elseif blueprintsModel:IsA("Model") then
		-- Fallback: find any part
		return blueprintsModel:FindFirstChildWhichIsA("BasePart")
	end

	return nil
end

-- Handle entering proximity
local function onEnterProximity()
	if isNearBlueprints then return end
	isNearBlueprints = true

	-- Get the part to attach the billboard to
	local adorneePart = getBlueprintsAdornee()
	print("[BlueprintController] Entering proximity, adornee:", adorneePart and adorneePart:GetFullName() or "nil")

	-- Show the billboard on the Blueprints model
	GeneralBillboardController:Show("Blueprints", {
		BlueprintsModel = blueprintsModel,
	}, adorneePart)
end

-- Handle leaving proximity
local function onLeaveProximity()
	if not isNearBlueprints then return end
	isNearBlueprints = false

	-- Hide the billboard
	GeneralBillboardController:Hide()
end

-- Close the Blueprint menu
local function closeBlueprintMenu()
	if not isBlueprintMenuOpen then return end
	isBlueprintMenuOpen = false

	-- Dispatch action to close menu (set back to HUD)
	Store:dispatch(UIActions.setCurrentFrame("HUD"))

	-- Stop distance monitoring for menu
	if menuDistanceConnection then
		menuDistanceConnection:Disconnect()
		menuDistanceConnection = nil
	end
end

-- Start monitoring distance for auto-closing menu
local function startMenuDistanceMonitoring()
	-- Stop any existing monitoring
	if menuDistanceConnection then
		menuDistanceConnection:Disconnect()
	end

	menuDistanceConnection = RunService.Heartbeat:Connect(function()
		if not isBlueprintMenuOpen then
			if menuDistanceConnection then
				menuDistanceConnection:Disconnect()
				menuDistanceConnection = nil
			end
			return
		end

		-- Check if player is too far away
		local isCloseEnough = checkProximity(MENU_CLOSE_DISTANCE)
		if not isCloseEnough then
			closeBlueprintMenu()
		end
	end)
end

-- Proximity check loop
local function startProximityCheck()
	proximityConnection = RunService.Heartbeat:Connect(function()
		-- Try to find Blueprints if not found yet
		if not blueprintsModel then
			blueprintsModel = findBlueprints()
			if not blueprintsModel then
				return
			end
		end

		-- Check proximity for billboard (only show if menu is not open)
		local isNear = checkProximity(PROXIMITY_DISTANCE)

		if isNear and not isNearBlueprints and not isBlueprintMenuOpen then
			onEnterProximity()
		elseif not isNear and isNearBlueprints then
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

-- Open the Blueprint menu
function BlueprintController:OpenBlueprintMenu()
	if isBlueprintMenuOpen then return end
	isBlueprintMenuOpen = true

	-- Hide the billboard when menu opens
	GeneralBillboardController:Hide()
	isNearBlueprints = false

	-- Dispatch action to open Blueprint UI
	Store:dispatch(UIActions.setCurrentFrame("Blueprint"))

	-- Start monitoring distance to auto-close if player walks away
	startMenuDistanceMonitoring()
end

-- Close the Blueprint menu (can be called externally)
function BlueprintController:CloseBlueprintMenu()
	closeBlueprintMenu()
end

-- Check if player is near the blueprints table
function BlueprintController:IsNearBlueprints()
	return isNearBlueprints
end

-- Check if Blueprint menu is open
function BlueprintController:IsBlueprintMenuOpen()
	return isBlueprintMenuOpen
end

-- Manually show the Blueprints billboard (for external triggers)
function BlueprintController:ShowBillboard()
	local adorneePart = getBlueprintsAdornee()
	GeneralBillboardController:Show("Blueprints", {
		BlueprintsModel = blueprintsModel,
	}, adorneePart)
end

-- Manually hide the Blueprints billboard
function BlueprintController:HideBillboard()
	GeneralBillboardController:Hide()
end

--|| Initialization ||--

function BlueprintController:KnitStart()
	-- Get controllers
	GeneralBillboardController = Knit.GetController("GeneralBillboardController")

	-- Start proximity detection
	startProximityCheck()

	-- Handle character respawn
	player.CharacterAdded:Connect(function()
		-- Reset state
		isNearBlueprints = false
		blueprintsModel = nil

		-- Close menu if open (player died)
		if isBlueprintMenuOpen then
			closeBlueprintMenu()
		end

		-- Re-find the blueprints model
		task.wait(1) -- Wait for world to load
		blueprintsModel = findBlueprints()
	end)

	-- Listen for UI state changes (in case menu is closed by other means)
	Store.changed:connect(function(newState, oldState)
		local oldFrame = oldState.UIReducer and oldState.UIReducer.CurrentFrame
		local newFrame = newState.UIReducer and newState.UIReducer.CurrentFrame

		-- If Blueprint menu was closed externally
		if oldFrame == "Blueprint" and newFrame ~= "Blueprint" and isBlueprintMenuOpen then
			isBlueprintMenuOpen = false
			if menuDistanceConnection then
				menuDistanceConnection:Disconnect()
				menuDistanceConnection = nil
			end
		end
	end)

	print("[BlueprintController] Started")
end

return BlueprintController
