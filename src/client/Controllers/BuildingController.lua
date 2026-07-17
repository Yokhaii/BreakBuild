-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")
local StarterPlayer = game:GetService("StarterPlayer")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Rodux
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local InventoryActions = require(Actions.InventoryActions)

-- Player
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

-- Controllers (resolved at KnitStart)
local DistanceFadeController
local BlueprintController

-- BuildingController
local BuildingController = Knit.CreateController({
	Name = "BuildingController",
})

-- Constants
local PREVIEW_TRANSPARENCY = 0.5
local WALLLIMIT_TRANSPARENCY  = 0.9
local HIGHLIGHT_VALID_COLOR = Color3.fromRGB(0, 0, 0) -- White greyish
local HIGHLIGHT_INVALID_COLOR = Color3.fromRGB(255, 0, 0) -- Red
local GRID_SIZE = 2 -- 2-stud grid (same as server)

-- Services (to be initialized)
local BuildingService
local InventoryService
local BlueprintService
local InventoryController
local BlueprintPlacementController

-- Building state
local buildingMode = false
local currentBlockItem = nil
local previewModel = nil
local previewGlassModel = nil -- Glass copy for highlights
local previewHighlights = {} -- Array of highlights (one per part)
local currentPosition = nil
local isValidPlacement = false
local wallLimitTweens = {} -- Array of tweens for WallLimit pulsing animation

-- Removal mode state
local removalMode = false
local hoveredBlock = nil -- Currently hovered block model
local removalHighlight = nil -- Highlight for the hovered block
local removalBillboard = nil -- Billboard showing block/structure name
local hoveredStructure = nil -- Currently hovered completed structure
local hoveredBlueprint = nil -- Currently hovered uncompleted blueprint

-- Blueprint preview state (when in Build mode, not removal mode)
local blueprintPreviewHighlight = nil
local blueprintPreviewBillboard = nil
local hoveredPreviewBlueprint = nil
local hoveredPreviewType = nil -- "blueprint", "structure", or "blueprints_table"

-- BuildingArea tracking state
local playerInBuildingArea = false

-- DistanceFade effect IDs
local BUILDING_FADE_ID = "BuildingArea"
local PREVIEW_FADE_ID = "PreviewBlock"

-- References
local buildingZone = nil
local buildingArea = nil
local buildingAreaInfo = nil

--|| Private Functions ||--

-- Snap position to grid based on block size (client-side version)
-- 4x4x4 blocks (half=2) snap to even positions: 2, 4, 6...
-- 2x2x2 blocks (half=1) snap to odd positions: 1, 3, 5...
local function snapToGridForBlockSize(position: Vector3, blockSize: Vector3): Vector3
	local halfSize = blockSize / 2

	local function snapAxis(value, halfBlockSize)
		if halfBlockSize % GRID_SIZE == 0 then
			-- Block half-size is multiple of grid (4x4x4), snap to grid multiples
			return math.round(value / GRID_SIZE) * GRID_SIZE
		else
			-- Block half-size is not multiple of grid (2x2x2), snap to offset grid
			local gridHalf = GRID_SIZE / 2
			return math.round((value - gridHalf) / GRID_SIZE) * GRID_SIZE + gridHalf
		end
	end

	return Vector3.new(
		snapAxis(position.X, halfSize.X),
		snapAxis(position.Y, halfSize.Y),
		snapAxis(position.Z, halfSize.Z)
	)
end

-- Legacy snap function (defaults to 4x4x4 block size)
local function snapToGrid(position: Vector3): Vector3
	return snapToGridForBlockSize(position, Vector3.new(4, 4, 4))
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

-- Start DistanceFade effect on BuildingArea walls (visible from inside and outside)
local function startDistanceFade()
	if DistanceFadeController:IsActive(BUILDING_FADE_ID) then
		return
	end

	local _, area = getBuildingZone()
	if not area then
		return
	end

	local faces = {
		Enum.NormalId.Front,
		Enum.NormalId.Back,
		Enum.NormalId.Left,
		Enum.NormalId.Right,
	}
	DistanceFadeController:Apply(BUILDING_FADE_ID, area, faces, "BuildingArea")
end

-- Stop DistanceFade effect
local function stopDistanceFade()
	DistanceFadeController:Stop(BUILDING_FADE_ID)
end

-- Detect block, structure, or uncompleted blueprint under cursor for removal
-- Returns: model, targetType ("block", "structure", "blueprint", "blueprints_table", or nil)
local function detectRemovableUnderCursor(): (Model?, string?)
	local camera = Workspace.CurrentCamera
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayOrigin = mouseRay.Origin
	local rayDirection = mouseRay.Direction * 1000

	-- Create raycast params
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude

	-- Build filter list: character and preview model
	local filterList = {player.Character}
	if previewModel then
		table.insert(filterList, previewModel)
	end

	raycastParams.FilterDescendantsInstances = filterList

	-- Perform raycast
	local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if not raycastResult then
		return nil, nil
	end

	local hitInstance = raycastResult.Instance

	-- Check if hit instance is inside BuildingZone
	local zone = getBuildingZone()
	if not zone then
		return nil, nil
	end

	-- Check if the hit is the static Blueprints table (BuildingZone > Platform > Blueprints)
	local platform = zone:FindFirstChild("Platform")
	if platform then
		local blueprintsTable = platform:FindFirstChild("Blueprints")
		if blueprintsTable and hitInstance:IsDescendantOf(blueprintsTable) then
			return blueprintsTable, "blueprints_table"
		end
	end

	-- Traverse up to find if this is part of a model in BuildingZone
	local current = hitInstance
	while current and current ~= Workspace do
		if current.Parent == zone then
			-- Found a child of BuildingZone
			local ownerId = current:FindFirstChild("OwnerId")
			local playerId = current:FindFirstChild("PlayerId")
			local isCompletedStructure = current:FindFirstChild("IsCompletedStructure")
			local blueprintId = current:FindFirstChild("BlueprintId")

			-- Check if it's a completed structure
			if isCompletedStructure and isCompletedStructure.Value then
				if ownerId and ownerId.Value == player.UserId then
					return current, "structure"
				end
			end

			-- Check if it's an uncompleted blueprint (has BlueprintId but not IsCompletedStructure)
			if blueprintId and not isCompletedStructure then
				if ownerId and ownerId.Value == player.UserId then
					return current, "blueprint"
				end
			end

			-- Check if it has BlockId (placed blocks have this)
			local blockId = current:FindFirstChild("BlockId")
			if blockId and playerId and playerId.Value == player.UserId then
				-- This is a block placed by this player
				return current, "block"
			end
			break
		end
		current = current.Parent
	end

	return nil, nil
end

-- Get display name for a target (block, structure, or blueprint)
local function getTargetDisplayName(target: Model?, targetType: string?): string
	if not target or not targetType then
		return "Unknown"
	end

	if targetType == "block" then
		-- Get block item name from the model name (e.g., "SandBlock_Block" -> "SandBlock")
		local blockName = target.Name:gsub("_Block$", "")
		local itemConfig = ItemData.GetItem(blockName)
		if itemConfig and itemConfig.displayName then
			return itemConfig.displayName
		end
		return blockName
	elseif targetType == "structure" then
		-- Get structure type from BlueprintType value
		local blueprintTypeValue = target:FindFirstChild("BlueprintType")
		if blueprintTypeValue then
			return blueprintTypeValue.Value
		end
		return "Structure"
	elseif targetType == "blueprint" then
		-- Look for BlueprintType StringValue first (like completed structures have)
		local blueprintTypeValue = target:FindFirstChild("BlueprintType")
		if blueprintTypeValue and blueprintTypeValue:IsA("StringValue") then
			return blueprintTypeValue.Value .. " Blueprint"
		end
		-- Fallback: search for a child with "Blueprint" in the name pattern
		for _, child in ipairs(target:GetChildren()) do
			if child:IsA("StringValue") and child.Name == "BlueprintType" then
				return child.Value .. " Blueprint"
			end
		end
		return "Blueprint"
	elseif targetType == "blueprints_table" then
		return "Blueprints"
	end

	return "Unknown"
end

-- Create or update highlight for block, structure, or blueprint removal
local function updateRemovalHighlight(target: Model?, targetType: string?)
	-- Remove existing highlight and billboard
	if removalHighlight then
		removalHighlight:Destroy()
		removalHighlight = nil
	end
	if removalBillboard then
		removalBillboard:Destroy()
		removalBillboard = nil
	end

	-- Clear all hovered states
	hoveredBlock = nil
	hoveredStructure = nil
	hoveredBlueprint = nil

	-- If no target, we're done
	if not target or not targetType then
		return
	end

	-- Set the appropriate hovered state
	if targetType == "structure" then
		hoveredStructure = target
	elseif targetType == "blueprint" then
		hoveredBlueprint = target
	else
		hoveredBlock = target
	end

	-- Get target part for billboard
	local targetPart
	if target:IsA("BasePart") then
		targetPart = target
	elseif target:IsA("Model") and target.PrimaryPart then
		targetPart = target.PrimaryPart
	elseif target:IsA("Model") then
		targetPart = target:FindFirstChildWhichIsA("BasePart")
	end

	-- For blueprints, use the HighlightProxy model if it exists (Glass material supports highlights on transparent parts)
	local highlightTarget = target
	if targetType == "blueprint" and target:IsA("Model") then
		local highlightProxy = target:FindFirstChild("HighlightProxy")
		if highlightProxy then
			highlightTarget = highlightProxy
		end
	end

	-- Create new highlight (same style as BreakingController but with slight red fill)
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.9
	highlight.FillColor = Color3.fromRGB(255, 0, 0) -- Red fill
	highlight.OutlineTransparency = 0.9
	highlight.OutlineColor = Color3.new(0, 0, 0) -- Black outline
	highlight.Adornee = highlightTarget
	highlight.Parent = target

	removalHighlight = highlight

	-- Find BillboardAttach attachment for blueprints/structures, or use targetPart for blocks
	local billboardAdornee = nil
	if targetType == "blueprint" or targetType == "structure" then
		-- Search for BillboardAttach attachment in the model
		billboardAdornee = target:FindFirstChild("BillboardAttach", true)
	end

	-- Fallback to targetPart if no attachment found
	if not billboardAdornee then
		billboardAdornee = targetPart
	end

	-- Create billboard with name above the target
	if billboardAdornee then
		local displayName = getTargetDisplayName(target, targetType)

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(2, 0, 2, 0)
		billboard.StudsOffset = Vector3.new(0, 0, 0) -- No offset needed when using attachment
		billboard.Adornee = billboardAdornee
		billboard.AlwaysOnTop = true

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = displayName
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextStrokeTransparency = 0.5
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextScaled = true
		textLabel.Parent = billboard

		billboard.Parent = target
		removalBillboard = billboard
	end
end

-- Update removal mode (detect and highlight blocks/structures/blueprints)
local function updateRemovalMode()
	if not removalMode then
		return
	end

	-- Detect removable target under cursor
	local target, targetType = detectRemovableUnderCursor()

	-- Get current hovered target for comparison
	local currentTarget = hoveredStructure or hoveredBlueprint or hoveredBlock

	-- Update highlight (only if changed)
	if target ~= currentTarget then
		updateRemovalHighlight(target, targetType)
	end
end

-- Clear blueprint preview highlight
local function clearBlueprintPreviewHighlight()
	if blueprintPreviewHighlight then
		blueprintPreviewHighlight:Destroy()
		blueprintPreviewHighlight = nil
	end
	if blueprintPreviewBillboard then
		blueprintPreviewBillboard:Destroy()
		blueprintPreviewBillboard = nil
	end
	hoveredPreviewBlueprint = nil
	hoveredPreviewType = nil
end

-- Update blueprint preview highlight (for Build mode, not removal mode)
-- Reuses detectRemovableUnderCursor but only shows highlight for blueprints and structures (no red fill)
local function updateBlueprintPreviewMode()
	-- Use same detection as removal mode
	local target, targetType = detectRemovableUnderCursor()

	-- Only show highlight for blueprints, structures, and the blueprints table (not blocks)
	if targetType ~= "blueprint" and targetType ~= "structure" and targetType ~= "blueprints_table" then
		target = nil
		targetType = nil
	end

	-- If same target, no change needed
	if target == hoveredPreviewBlueprint then
		return
	end

	-- Clear existing highlight
	clearBlueprintPreviewHighlight()
	hoveredPreviewBlueprint = target
	hoveredPreviewType = targetType

	if not target then
		return
	end

	-- For blueprints, use the HighlightProxy model if it exists (for transparent parts)
	local highlightTarget = target
	if targetType == "blueprint" then
		local highlightProxy = target:FindFirstChild("HighlightProxy")
		if highlightProxy then
			highlightTarget = highlightProxy
		end
	end

	-- Create highlight (black outline, no red fill - just preview)
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineTransparency = 0.7
	highlight.OutlineColor = Color3.new(0, 0, 0) -- Black outline
	highlight.Adornee = highlightTarget
	highlight.Parent = target

	blueprintPreviewHighlight = highlight

	-- Find BillboardAttach attachment for billboard positioning
	local billboardAdornee = target:FindFirstChild("BillboardAttach", true)
	if not billboardAdornee then
		-- Fallback to PrimaryPart
		if target:IsA("Model") and target.PrimaryPart then
			billboardAdornee = target.PrimaryPart
		end
	end

	-- Create billboard with name
	if billboardAdornee then
		local displayName = getTargetDisplayName(target, targetType)

		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.new(2, 0, 2, 0)
		billboard.StudsOffset = Vector3.new(0, 0, 0)
		billboard.Adornee = billboardAdornee
		billboard.AlwaysOnTop = true

		local textLabel = Instance.new("TextLabel")
		textLabel.Size = UDim2.new(1, 0, 1, 0)
		textLabel.BackgroundTransparency = 1
		textLabel.Text = displayName
		textLabel.TextColor3 = Color3.new(1, 1, 1)
		textLabel.TextStrokeTransparency = 0.5
		textLabel.Font = Enum.Font.GothamBold
		textLabel.TextScaled = true
		textLabel.Parent = billboard

		billboard.Parent = target
		blueprintPreviewBillboard = billboard
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
			part.CastShadow = false
			part.CanCollide = false
			part.Anchored = true
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

-- Create a glass copy of the preview model and attach highlights to it
local function createGlassHighlight(model)
	local highlights = {}

	local glassCopy = model:Clone()
	glassCopy.Name = model.Name .. "_Glass"

	local function setupGlassPart(part)
		if part:IsA("BasePart") then
			part.Transparency = 1
			part.Material = Enum.Material.Glass
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Anchored = true

			local highlight = Instance.new("Highlight")
			highlight.FillTransparency = 1
			highlight.OutlineTransparency = 0.5
			highlight.OutlineColor = HIGHLIGHT_VALID_COLOR
			highlight.Parent = part
			table.insert(highlights, highlight)
		end
	end

	if glassCopy:IsA("Model") then
		for _, descendant in ipairs(glassCopy:GetDescendants()) do
			setupGlassPart(descendant)
		end
		if glassCopy.PrimaryPart then
			setupGlassPart(glassCopy.PrimaryPart)
		end
	elseif glassCopy:IsA("BasePart") then
		setupGlassPart(glassCopy)
	end

	return glassCopy, highlights
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
		if previewGlassModel then previewGlassModel.Parent = nil end
		return
	end

	local character = player.Character
	if not character or not character.PrimaryPart then
		previewModel.Parent = nil
		if previewGlassModel then previewGlassModel.Parent = nil end
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
		if previewGlassModel then previewGlassModel.Parent = nil end
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

	-- Build filter list: character, preview, glass copy, and any parts with Ignore attribute
	local filterList = {player.Character, previewModel}
	if previewGlassModel then
		table.insert(filterList, previewGlassModel)
	end

	-- Add all parts with "Ignore" attribute to filter
	for _, part in ipairs(Workspace:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("Ignore") then
			table.insert(filterList, part)
		end
	end

	-- Add blueprint models to filter (so we can place blocks inside blueprints)
	local zone = getBuildingZone()
	if zone then
		for _, child in ipairs(zone:GetChildren()) do
			-- Blueprint models have a BlueprintId child
			if child:FindFirstChild("BlueprintId") then
				table.insert(filterList, child)
			end
		end
	end

	raycastParams.FilterDescendantsInstances = filterList

	-- Perform raycast
	local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if not raycastResult then
		-- No hit, hide preview
		previewModel.Parent = nil
		if previewGlassModel then previewGlassModel.Parent = nil end
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


	-- Calculate target position (on the surface)
	-- Add half the block size in the direction of the normal to place block on surface
	local targetPosition = hitPosition + (hitNormal * (blockSize.Y / 2))

	-- Snap to grid based on block size (client-side, no server call needed)
	local snappedPosition = snapToGridForBlockSize(targetPosition, blockSize)

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

	-- Snap the clamped position to grid again based on block size (in case clamping moved it off-grid)
	clampedPosition = snapToGridForBlockSize(clampedPosition, blockSize)


	currentPosition = clampedPosition

	-- Check if the preview position is within BuildingArea bounds (for color only)
	isValidPlacement = isWithinBounds(clampedPosition, blockSize, areaOrigin)

	-- Calculate and display relative position (offset from BuildingArea origin)

	-- Update preview position
	if previewModel:IsA("Model") and previewModel.PrimaryPart then
		previewModel:SetPrimaryPartCFrame(CFrame.new(clampedPosition))
	elseif previewModel:IsA("BasePart") then
		previewModel.Position = clampedPosition
		previewModel.Size = blockSize
	end

	-- Update glass copy position
	if previewGlassModel then
		if previewGlassModel:IsA("Model") and previewGlassModel.PrimaryPart then
			previewGlassModel:SetPrimaryPartCFrame(CFrame.new(clampedPosition))
		elseif previewGlassModel:IsA("BasePart") then
			previewGlassModel.Position = clampedPosition
			previewGlassModel.Size = blockSize
		end
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
	if previewGlassModel and previewGlassModel.Parent ~= Workspace then
		previewGlassModel.Parent = Workspace
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

	-- Create glass copy with highlights
	previewGlassModel, previewHighlights = createGlassHighlight(previewModel)
	previewGlassModel.Parent = Workspace

	-- Apply DistanceFade to BuildingArea walls, tracked by the preview block's position
	local _, area = getBuildingZone()
	local previewPart = nil
	if previewModel:IsA("BasePart") then
		previewPart = previewModel
	elseif previewModel:IsA("Model") and previewModel.PrimaryPart then
		previewPart = previewModel.PrimaryPart
	end
	if previewPart and area then
		local wallFaces = {
			Enum.NormalId.Front,
			Enum.NormalId.Back,
			Enum.NormalId.Left,
			Enum.NormalId.Right,
		}
		DistanceFadeController:Apply(PREVIEW_FADE_ID, area, wallFaces, "PreviewBlock", {
			trackPart = previewPart,
		})
	end
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

	-- Stop preview DistanceFade
	DistanceFadeController:Stop(PREVIEW_FADE_ID)

	-- Destroy preview
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end

	-- Destroy glass copy (highlights are children, destroyed with it)
	if previewGlassModel then
		previewGlassModel:Destroy()
		previewGlassModel = nil
	end
	previewHighlights = {}

end

-- Start removal mode
local function startRemovalMode()
	if removalMode then
		return
	end

	-- Stop building mode if active
	if buildingMode then
		stopBuildingMode()
	end

	-- Clear blueprint preview (removal mode has its own highlight)
	clearBlueprintPreviewHighlight()

	removalMode = true

	-- Start pulsing animation for WallLimit parts (same as building mode)
	startWallLimitPulsing()

	print("Removal mode started")
end

-- Stop removal mode
local function stopRemovalMode()
	if not removalMode then
		return
	end

	removalMode = false

	-- Stop pulsing animation and hide WallLimit parts
	stopWallLimitPulsing()

	-- Remove highlight and billboard
	if removalHighlight then
		removalHighlight:Destroy()
		removalHighlight = nil
	end
	if removalBillboard then
		removalBillboard:Destroy()
		removalBillboard = nil
	end

	hoveredBlock = nil
	hoveredStructure = nil
	hoveredBlueprint = nil

	print("Removal mode stopped")
end

-- Handle item equipped
local function onItemEquipped(slot: number, itemName: string)
	local itemConfig = ItemData.GetItem(itemName)

	-- Check if item is the Hammer (removal tool)
	if itemConfig and itemConfig.isRemovalTool then
		-- Start removal mode
		startRemovalMode()
	-- Check if item is a block
	elseif itemConfig and itemConfig.type == "Block" and itemConfig.blockSize then
		-- Start building mode
		startBuildingMode(itemName)
	else
		-- Not a block or removal tool, stop both modes if active
		if buildingMode then
			stopBuildingMode()
		end
		if removalMode then
			stopRemovalMode()
		end
	end
end

-- Handle item unequipped
local function onItemUnequipped()
	-- Stop building mode
	if buildingMode then
		stopBuildingMode()
	end
	-- Stop removal mode
	if removalMode then
		stopRemovalMode()
	end
end

-- Handle mouse click for placement or removal
local function onMouseClick()
	-- Handle removal mode - completed structure removal (instant)
	if removalMode and hoveredStructure then
		local blueprintId = hoveredStructure:FindFirstChild("BlueprintId")
		if blueprintId and blueprintId.Value then
			-- Call BlueprintService to remove the completed structure (gives item back)
			BlueprintService:RemoveCompletedStructure(blueprintId.Value)
				:andThen(function(success, itemName)
					if success then
						print("Structure removed successfully! Received:", itemName)
					else
						warn("Failed to remove structure:", itemName)
					end
				end)
				:catch(function(err)
					warn("Error removing structure:", err)
				end)
		end
		return
	end

	-- Handle removal mode - uncompleted blueprint removal (instant)
	if removalMode and hoveredBlueprint then
		local blueprintId = hoveredBlueprint:FindFirstChild("BlueprintId")
		if blueprintId and blueprintId.Value then
			-- Call BlueprintService to remove the uncompleted blueprint
			BlueprintService:RemoveUncompletedBlueprint(blueprintId.Value)
				:andThen(function(success, itemName)
					if success then
						print("Blueprint removed successfully! Received:", itemName)
					else
						warn("Failed to remove blueprint:", itemName)
					end
				end)
				:catch(function(err)
					warn("Error removing blueprint:", err)
				end)
		end
		return
	end

	-- Handle removal mode - block removal (instant)
	if removalMode and hoveredBlock then
		-- Get block ID
		local blockId = hoveredBlock:FindFirstChild("BlockId")
		if blockId and blockId.Value then
			-- Call BuildingService to remove the block
			BuildingService:RemoveBlock(blockId.Value)
				:andThen(function(success, itemName)
					if success then
						print("Block removed successfully! Received:", itemName)
					else
						warn("Failed to remove block")
					end
				end)
				:catch(function(err)
					warn("Error removing block:", err)
				end)
		end
		return
	end

	-- Handle interaction with completed structures (when hovering in Build mode)
	if hoveredPreviewBlueprint and hoveredPreviewType == "structure" then
		local blueprintId = hoveredPreviewBlueprint:FindFirstChild("BlueprintId")
		if blueprintId and blueprintId.Value and BlueprintPlacementController then
			local blueprint = BlueprintPlacementController:GetActiveBlueprint(blueprintId.Value)
			if blueprint and blueprint._OnInteract then
				blueprint:_OnInteract(player)
			end
		end
		return
	end

	-- Handle click on the static Blueprints table
	if hoveredPreviewBlueprint and hoveredPreviewType == "blueprints_table" then
		if BlueprintController then
			BlueprintController:OpenBlueprintMenu()
		end
		return
	end

	-- Handle building mode
	if not buildingMode or not currentPosition or not currentBlockItem then
		return
	end

	-- Don't place block when hovering over completed structure or blueprints table
	if hoveredPreviewBlueprint and (hoveredPreviewType == "structure" or hoveredPreviewType == "blueprints_table") then
		return
	end

	-- Try to place block (returns a Promise)
	BuildingService:PlaceBlock(currentPosition, currentBlockItem)
		:andThen(function(success)
			if success then
			else
				warn("Failed to place block - server validation failed")
			end
		end)
		:catch(function(err)
			warn("Error placing block:", err)
		end)
end

-- Handle input began
local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	-- Left click to place block, remove block/structure, or interact with structure
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if buildingMode or removalMode or hoveredPreviewBlueprint then
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

-- Check if player is currently inside the BuildingArea
function BuildingController:IsPlayerInBuildingArea(): boolean
	return playerInBuildingArea
end

--|| Initialization ||--

function BuildingController:KnitStart()
	BuildingService = Knit.GetService("BuildingService")
	InventoryService = Knit.GetService("InventoryService")
	BlueprintService = Knit.GetService("BlueprintService")
	InventoryController = Knit.GetController("InventoryController")
	BlueprintPlacementController = Knit.GetController("BlueprintPlacementController")
	DistanceFadeController = Knit.GetController("DistanceFadeController")
	BlueprintController = Knit.GetController("BlueprintController")

	-- Get building zone
	getBuildingZone()

	-- Get building area info from server
	buildingAreaInfo = BuildingService:GetBuildingAreaInfo()

	-- Player DistanceFade on BuildingArea is always active
	startDistanceFade()

	-- Connect to inventory signals
	InventoryService.ItemEquipped:Connect(onItemEquipped)
	InventoryService.ItemUnequipped:Connect(onItemUnequipped)

	-- Update preview, removal mode, and BuildingArea tracking every frame
	RunService.RenderStepped:Connect(function()
		-- Track player entering/leaving BuildingArea
		local _, area = getBuildingZone()
		local inArea = false
		if area then
			local character = player.Character
			if character and character.PrimaryPart then
				local playerPosition = character.PrimaryPart.Position
				local areaPosition = area.Position
				local halfSize = area.Size / 2
				inArea = math.abs(playerPosition.X - areaPosition.X) <= halfSize.X
					and math.abs(playerPosition.Y - areaPosition.Y) <= halfSize.Y
					and math.abs(playerPosition.Z - areaPosition.Z) <= halfSize.Z
			end
		end

		if inArea ~= playerInBuildingArea then
			playerInBuildingArea = inArea
			Store:dispatch(InventoryActions.setHammerAvailable(inArea))

			-- Auto-unequip Hammer when leaving area
			if not inArea then
				local state = Store:getState().InventoryReducer
				if state.EquippedSlot == 0 then
					InventoryService:UnequipItem()
				end
			end
		end

		if removalMode then
			updateRemovalMode()
			clearBlueprintPreviewHighlight()
		else
			-- Show blueprint preview when inside BuildingArea, but always check
			-- the static Blueprints table (it lives outside the BuildingArea).
			if playerInBuildingArea then
				updateBlueprintPreviewMode()
			else
				-- Outside building area: still detect the Blueprints table
				local target, targetType = detectRemovableUnderCursor()
				if targetType ~= "blueprints_table" then
					target = nil
					targetType = nil
				end
				if target ~= hoveredPreviewBlueprint then
					clearBlueprintPreviewHighlight()
					hoveredPreviewBlueprint = target
					hoveredPreviewType = targetType
					if target then
						local highlight = Instance.new("Highlight")
						highlight.FillTransparency = 1
						highlight.OutlineTransparency = 0.7
						highlight.OutlineColor = Color3.new(0, 0, 0)
						highlight.Adornee = target
						highlight.Parent = target
						blueprintPreviewHighlight = highlight

						local billboardAdornee = target:FindFirstChild("BillboardAttach", true)
						if not billboardAdornee and target:IsA("Model") and target.PrimaryPart then
							billboardAdornee = target.PrimaryPart
						end
						if billboardAdornee then
							local billboard = Instance.new("BillboardGui")
							billboard.Size = UDim2.new(2, 0, 2, 0)
							billboard.StudsOffset = Vector3.new(0, 0, 0)
							billboard.Adornee = billboardAdornee
							billboard.AlwaysOnTop = true
							local textLabel = Instance.new("TextLabel")
							textLabel.Size = UDim2.new(1, 0, 1, 0)
							textLabel.BackgroundTransparency = 1
							textLabel.Text = "Blueprints"
							textLabel.TextColor3 = Color3.new(1, 1, 1)
							textLabel.TextStrokeTransparency = 0.5
							textLabel.Font = Enum.Font.GothamBold
							textLabel.TextScaled = true
							textLabel.Parent = billboard
							billboard.Parent = target
							blueprintPreviewBillboard = billboard
						end
					end
				end
			end

			if buildingMode then
				if hoveredPreviewBlueprint and (hoveredPreviewType == "structure" or hoveredPreviewType == "blueprints_table") then
					if previewModel and previewModel.Parent then
						previewModel.Parent = nil
					end
					if previewGlassModel and previewGlassModel.Parent then
						previewGlassModel.Parent = nil
					end
				else
					updatePreview()
					if previewGlassModel and not previewGlassModel.Parent then
						previewGlassModel.Parent = Workspace
					end
				end
			end
		end
	end)

	-- Handle input
	UserInputService.InputBegan:Connect(onInputBegan)

	print("BuildingController initialized")
end

return BuildingController
