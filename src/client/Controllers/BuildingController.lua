-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Player
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

-- BuildingController
local BuildingController = Knit.CreateController({
	Name = "BuildingController",
})

-- Constants
local PREVIEW_TRANSPARENCY = 0.7
local WALLLIMIT_TRANSPARENCY  = 0.9
local HIGHLIGHT_VALID_COLOR = Color3.fromRGB(230, 230, 230) -- White greyish
local HIGHLIGHT_INVALID_COLOR = Color3.fromRGB(255, 0, 0) -- Red
local GRID_SIZE = 2 -- 2-stud grid (same as server)

-- Services (to be initialized)
local BuildingService
local InventoryService

-- Building state
local buildingMode = false
local currentBlockItem = nil
local previewModel = nil
local previewHighlights = {} -- Array of highlights (one per part)
local currentPosition = nil
local isValidPlacement = false
local wallLimitTweens = {} -- Array of tweens for WallLimit pulsing animation

-- References
local buildingZone = nil
local buildingArea = nil
local buildingAreaInfo = nil

--|| Private Functions ||--

-- Snap position to 2-stud grid (client-side version)
local function snapToGrid(position: Vector3): Vector3
	return Vector3.new(
		math.round(position.X / GRID_SIZE) * GRID_SIZE,
		math.round(position.Y / GRID_SIZE) * GRID_SIZE,
		math.round(position.Z / GRID_SIZE) * GRID_SIZE
	)
end

-- Get building zone references
local function getBuildingZone()
	if not buildingZone then
		buildingZone = Workspace:FindFirstChild("BuildingZone")
		if buildingZone then
			buildingArea = buildingZone:FindFirstChild("BuildingArea")
		end
	end
	return buildingZone, buildingArea
end

-- Get all WallLimit parts from BuildingZone
local function getWallLimitParts(): {BasePart}
	local wallLimits = {}
	local zone = getBuildingZone()
	if not zone then
		return wallLimits
	end

	for _, child in ipairs(zone:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "WallLimit" then
			table.insert(wallLimits, child)
		end
	end

	return wallLimits
end

-- Start pulsing animation for WallLimit parts
local function startWallLimitPulsing()
	local wallLimits = getWallLimitParts()

	-- TweenInfo for pulsing (goes from 0.9 to 0.8 and back)
	local tweenInfo = TweenInfo.new(
		1, -- Duration: 1 second
		Enum.EasingStyle.Sine, -- Smooth sine wave
		Enum.EasingDirection.InOut, -- Smooth in and out
		-1, -- Repeat infinitely
		true, -- Reverse (creates the pulse effect)
		0 -- No delay
	)

	-- Create and play tween for each WallLimit part
	for _, wallPart in ipairs(wallLimits) do
		-- Set initial transparency
		wallPart.Transparency = WALLLIMIT_TRANSPARENCY

		-- Create tween to pulse to 0.8
		local goal = {Transparency = WALLLIMIT_TRANSPARENCY * 0.86}
		local tween = TweenService:Create(wallPart, tweenInfo, goal)
		tween:Play()

		-- Store tween for cleanup later
		table.insert(wallLimitTweens, tween)
	end
end

-- Stop pulsing animation for WallLimit parts
local function stopWallLimitPulsing()
	-- Cancel all tweens
	for _, tween in ipairs(wallLimitTweens) do
		if tween then
			tween:Cancel()
		end
	end

	-- Clear the tweens array
	wallLimitTweens = {}

	-- Reset WallLimit transparency to fully transparent
	local wallLimits = getWallLimitParts()
	for _, wallPart in ipairs(wallLimits) do
		wallPart.Transparency = 1
	end
end
-- Simple client-side bounds check (for preview color only)
-- BuildingArea origin is at floor level (0,0,0) with PivotOffset
-- Bounds: X/Z from -32 to +32, Y from 0 to 64
local function isWithinBounds(position: Vector3, blockSize: Vector3, areaOrigin: Vector3): boolean
	-- Calculate relative position from origin (not part center)
	local relativePos = position - areaOrigin
	local halfBlockSize = blockSize / 2

	-- Block edges in relative space
	local blockMin = relativePos - halfBlockSize
	local blockMax = relativePos + halfBlockSize

	-- BuildingArea bounds (relative to origin at floor)
	-- X/Z: -32 to +32, Y: 0 to 64
	return blockMin.X >= -32 and blockMax.X <= 32 and
	       blockMin.Y >= 0 and blockMax.Y <= 64 and
	       blockMin.Z >= -32 and blockMax.Z <= 32
end


-- Create preview model from building part
local function createPreviewModel(itemName: string): Model?
	local itemConfig = ItemData.GetItem(itemName)
	if not itemConfig or not itemConfig.buildingPartPath then
		warn("Invalid building part path for:", itemName)
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
			warn("Building part not found at path:", itemConfig.buildingPartPath)
			return nil
		end
	end

	if not current:IsA("Model") and not current:IsA("BasePart") then
		warn("Building part is not a Model or Part:", itemConfig.buildingPartPath)
		return nil
	end

	-- Clone the building part
	local preview = current:Clone()
	preview.Name = itemName .. "_Preview"

	-- Make all parts transparent and non-collidable, keep original material
	local function setupPart(part)
		if part:IsA("BasePart") then
			part.Transparency = PREVIEW_TRANSPARENCY
			part.CanCollide = false
			part.Anchored = true
			-- Keep original material (Sand, Dirt, Stone, etc.)
		end
	end

	if preview:IsA("Model") then
		for _, descendant in ipairs(preview:GetDescendants()) do
			setupPart(descendant)
		end
		if preview.PrimaryPart then
			setupPart(preview.PrimaryPart)
		end
	elseif preview:IsA("BasePart") then
		setupPart(preview)
	end

	return preview
end

-- Create highlight for preview (add to each part)
local function createHighlight(model)
	local highlights = {}

	local function addHighlightToPart(part)
		if part:IsA("BasePart") then
			local highlight = Instance.new("Highlight")
			highlight.FillTransparency = 1
			highlight.OutlineTransparency = 0
			highlight.OutlineColor = HIGHLIGHT_VALID_COLOR
			highlight.Parent = part
			table.insert(highlights, highlight)
		end
	end

	if model:IsA("Model") then
		for _, descendant in ipairs(model:GetDescendants()) do
			addHighlightToPart(descendant)
		end
		if model.PrimaryPart then
			addHighlightToPart(model.PrimaryPart)
		end
	elseif model:IsA("BasePart") then
		addHighlightToPart(model)
	end

	return highlights
end

-- Update preview position and validation
local function updatePreview()
	if not buildingMode or not previewModel or not currentBlockItem then
		return
	end

	-- Check if player is inside the BuildingArea
	local _, area = getBuildingZone()
	if not area then
		previewModel.Parent = nil
		return
	end

	local character = player.Character
	if not character or not character.PrimaryPart then
		previewModel.Parent = nil
		return
	end

	local playerPosition = character.PrimaryPart.Position
	local areaPosition = area.Position
	local areaSize = area.Size -- 64x64x64

	-- Check if player is within the BuildingArea bounds (using center position)
	local halfSize = areaSize / 2
	local playerInArea = math.abs(playerPosition.X - areaPosition.X) <= halfSize.X and
	                     math.abs(playerPosition.Y - areaPosition.Y) <= halfSize.Y and
	                     math.abs(playerPosition.Z - areaPosition.Z) <= halfSize.Z

	if not playerInArea then
		-- Player outside building area, hide preview
		previewModel.Parent = nil
		return
	end

	-- Raycast from mouse to find target surface
	local camera = Workspace.CurrentCamera
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayOrigin = mouseRay.Origin
	local rayDirection = mouseRay.Direction * 1000

	-- Create raycast params
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude
	raycastParams.FilterDescendantsInstances = {player.Character, previewModel}

	-- Use RaycastFilterType.Exclude with a filter function to ignore parts with "Ignore" attribute
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

	-- Build filter list: character, preview, and any parts with Ignore attribute
	local filterList = {player.Character, previewModel}

	-- Add all parts with "Ignore" attribute to filter
	for _, part in ipairs(Workspace:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("Ignore") then
			table.insert(filterList, part)
		end
	end

	raycastParams.FilterDescendantsInstances = filterList

	-- Perform raycast
	local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if not raycastResult then
		-- No hit, hide preview
		previewModel.Parent = nil
		return
	end

	-- Get hit position and normal
	local hitPosition = raycastResult.Position
	local hitNormal = raycastResult.Normal
	local hitInstance = raycastResult.Instance

	-- Get block size
	local itemConfig = ItemData.GetItem(currentBlockItem)
	local blockSize = itemConfig.blockSize

	-- Get BuildingArea origin position (floor level)
	-- BuildingArea Part.Position.Y - 32 = floor level (Y=0)
	local areaPosition = area.Position
	local areaOrigin = Vector3.new(areaPosition.X, areaPosition.Y - 32, areaPosition.Z)

	-- Debug what we're hitting
	print("[BuildingController] Hit instance:", hitInstance.Name, "at position:", hitPosition)
	print("[BuildingController] Hit normal:", hitNormal)
	print("[BuildingController] BuildingArea Part.Position:", areaPosition)
	print("[BuildingController] BuildingArea Origin (Y-32):", areaOrigin)

	-- Calculate target position (on the surface)
	-- Add half the block size in the direction of the normal to place block on surface
	local targetPosition = hitPosition + (hitNormal * (blockSize.Y / 2))

	print("[BuildingController] Target position (before snap):", targetPosition)

	-- Snap to grid (client-side, no server call needed)
	local snappedPosition = snapToGrid(targetPosition)

	print("[BuildingController] Snapped position:", snappedPosition)

	-- Clamp position to BuildingArea bounds
	-- Convert to relative position first
	local relativePos = snappedPosition - areaOrigin

	-- Clamp X and Z to stay within -32 to +32 bounds (accounting for block size)
	local halfBlockSize = blockSize / 2
	local clampedRelativeX = math.clamp(relativePos.X, -32 + halfBlockSize.X, 32 - halfBlockSize.X)
	local clampedRelativeZ = math.clamp(relativePos.Z, -32 + halfBlockSize.Z, 32 - halfBlockSize.Z)

	-- Convert back to world position
	local clampedPosition = Vector3.new(
		areaOrigin.X + clampedRelativeX,
		snappedPosition.Y, -- Don't clamp Y, let it follow the surface
		areaOrigin.Z + clampedRelativeZ
	)

	-- Snap the clamped position to grid again (in case clamping moved it off-grid)
	clampedPosition = snapToGrid(clampedPosition)

	print("[BuildingController] Clamped position:", clampedPosition)

	currentPosition = clampedPosition

	-- Check if the preview position is within BuildingArea bounds (for color only)
	isValidPlacement = isWithinBounds(clampedPosition, blockSize, areaOrigin)

	-- Calculate and display relative position (offset from BuildingArea origin)
	local clampedRelativePosition = clampedPosition - areaOrigin
	print("[BuildingController] Relative Position:", clampedRelativePosition, "Valid:", isValidPlacement)
	print("---")

	-- Update preview position
	if previewModel:IsA("Model") and previewModel.PrimaryPart then
		previewModel:SetPrimaryPartCFrame(CFrame.new(clampedPosition))
	elseif previewModel:IsA("BasePart") then
		previewModel.Position = clampedPosition
		previewModel.Size = blockSize
	end

	-- Update highlight outline color only
	local targetColor = isValidPlacement and HIGHLIGHT_VALID_COLOR or HIGHLIGHT_INVALID_COLOR
	for _, highlight in ipairs(previewHighlights) do
		highlight.OutlineColor = targetColor
	end

	-- Make sure preview is visible
	if previewModel.Parent ~= Workspace then
		previewModel.Parent = Workspace
	end
end

-- Start building mode
local function startBuildingMode(itemName: string)
	if buildingMode then
		stopBuildingMode()
	end

	local itemConfig = ItemData.GetItem(itemName)
	if not itemConfig or itemConfig.type ~= "Block" or not itemConfig.blockSize then
		return
	end

	buildingMode = true
	currentBlockItem = itemName

	-- Start pulsing animation for WallLimit parts
	startWallLimitPulsing()

	-- Create preview model
	previewModel = createPreviewModel(itemName)
	if not previewModel then
		warn("Failed to create preview model")
		stopBuildingMode()
		return
	end

	-- Create highlights (one per part)
	previewHighlights = createHighlight(previewModel)

	print("Building mode started for:", itemName)
end

-- Stop building mode
function stopBuildingMode()
	if not buildingMode then
		return
	end

	buildingMode = false
	currentBlockItem = nil
	currentPosition = nil
	isValidPlacement = false

	-- Stop pulsing animation and hide WallLimit parts
	stopWallLimitPulsing()

	-- Destroy preview
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end

	-- Destroy all highlights
	for _, highlight in ipairs(previewHighlights) do
		if highlight then
			highlight:Destroy()
		end
	end
	previewHighlights = {}

	print("Building mode stopped")
end

-- Handle item equipped
local function onItemEquipped(slot: number, itemName: string)
	-- Check if item is a block
	local itemConfig = ItemData.GetItem(itemName)
	if itemConfig and itemConfig.type == "Block" and itemConfig.blockSize then
		-- Start building mode
		startBuildingMode(itemName)
	else
		-- Not a block, stop building mode if active
		if buildingMode then
			stopBuildingMode()
		end
	end
end

-- Handle item unequipped
local function onItemUnequipped()
	-- Stop building mode
	if buildingMode then
		stopBuildingMode()
	end
end

-- Handle mouse click for placement
local function onMouseClick()
	if not buildingMode or not currentPosition or not currentBlockItem then
		return
	end

	-- Try to place block (returns a Promise)
	BuildingService:PlaceBlock(currentPosition, currentBlockItem)
		:andThen(function(success)
			if success then
				print("Block placed successfully!")
			else
				warn("Failed to place block - server validation failed")
			end
		end)
		:catch(function(err)
			warn("Error placing block:", err)
		end)
end

-- Handle input
local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	-- Left click to place block
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if buildingMode then
			onMouseClick()
		end
	end
end

--|| Public Functions ||--

-- Check if building mode is active
function BuildingController:IsBuildingMode(): boolean
	return buildingMode
end

-- Get current preview position
function BuildingController:GetPreviewPosition(): Vector3?
	return currentPosition
end

-- Force stop building mode (external call)
function BuildingController:StopBuildingMode()
	stopBuildingMode()
end

--|| Initialization ||--

function BuildingController:KnitStart()
	BuildingService = Knit.GetService("BuildingService")
	InventoryService = Knit.GetService("InventoryService")

	-- Get building zone
	getBuildingZone()

	-- Get building area info from server
	buildingAreaInfo = BuildingService:GetBuildingAreaInfo()

	-- Connect to inventory signals
	InventoryService.ItemEquipped:Connect(onItemEquipped)
	InventoryService.ItemUnequipped:Connect(onItemUnequipped)

	-- Update preview every frame
	RunService.RenderStepped:Connect(function()
		if buildingMode then
			updatePreview()
		end
	end)

	-- Handle input
	UserInputService.InputBegan:Connect(onInputBegan)

	print("BuildingController initialized")
end

return BuildingController
