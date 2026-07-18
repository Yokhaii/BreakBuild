--[=[
	BlueprintPlacementController
	Handles blueprint placement preview and placement when Blueprint item is equipped
]=]

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

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local BlueprintDefinitions = require(ReplicatedStorage.Shared.Data.Blueprints)
local ClientBaseBlueprint = require(StarterPlayer.StarterPlayerScripts.Client.Classes.Blueprints.BaseBlueprint)

-- Player
local player = Players.LocalPlayer
local mouse = player:GetMouse()

-- BlueprintPlacementController
local BlueprintPlacementController = Knit.CreateController({
	Name = "BlueprintPlacementController",
})

-- Constants
local PREVIEW_TRANSPARENCY = 0.5
local GRID_SIZE = 2 -- Same as BuildingController (2-stud grid)
local HIGHLIGHT_VALID_COLOR = Color3.fromRGB(100, 200, 255) -- Blue for valid
local HIGHLIGHT_INVALID_COLOR = Color3.fromRGB(255, 80, 80) -- Red for invalid
local DEFAULT_BLOCK_SIZE = Vector3.new(4, 4, 4) -- Default anchor block size

-- Services (to be initialized)
local BlueprintService
local InventoryService

-- Placement state
local placementMode = false
local currentBlueprintType = nil
local currentDefinition = nil
local anchorBlockSize = DEFAULT_BLOCK_SIZE -- Size of the anchor block
local previewModel = nil
local previewHighlight = nil
local currentPosition = nil -- Position of the anchor (PrimaryPart)
local isValidPlacement = false

-- Structure placement state (for completed blueprints)
local isStructurePlacement = false -- true when placing a completed structure, false for blueprint
local currentStructureItemName = nil -- Item name when placing a structure

-- References
local buildingZone = nil
local buildingArea = nil

-- Active blueprints on client
local activeBlueprints = {} -- { [blueprintId]: ClientBaseBlueprint }

--|| Private Functions ||--

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

-- Get building area origin (floor level)
local function getBuildingAreaOrigin()
	local _, area = getBuildingZone()
	if not area then return Vector3.new(0, 0, 0) end

	local areaPosition = area.Position
	return Vector3.new(areaPosition.X, areaPosition.Y - 32, areaPosition.Z)
end

-- Snap position to grid based on block size (same as BuildingController)
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

-- Check if a single block position is within building area bounds
local function isBlockWithinBounds(blockCenter: Vector3, blockSize: Vector3, areaOrigin: Vector3): boolean
	local relativePos = blockCenter - areaOrigin
	local halfBlockSize = blockSize / 2

	local blockMin = relativePos - halfBlockSize
	local blockMax = relativePos + halfBlockSize

	return blockMin.X >= -32 and blockMax.X <= 32 and
	       blockMin.Y >= 0 and blockMax.Y <= 64 and
	       blockMin.Z >= -32 and blockMax.Z <= 32
end

-- Check if all blocks of the blueprint are within building area bounds
-- anchorPosition: world position of anchor block center
-- definition: blueprint definition with blocks table
local function areAllBlocksWithinBounds(anchorPosition: Vector3, definition, areaOrigin: Vector3): boolean
	if not definition or not definition.blocks then
		return false
	end

	for _, blockReq in ipairs(definition.blocks) do
		-- Get block type config to determine block size
		local blockConfig = ItemData.GetItem(blockReq.blockType)
		local blockSize = blockConfig and blockConfig.blockSize or DEFAULT_BLOCK_SIZE

		-- Calculate this block's world position (anchor + offset)
		-- Offset is in world units, block center = anchor center + offset + half block size adjustment
		local blockCenter = anchorPosition + blockReq.offset

		if not isBlockWithinBounds(blockCenter, blockSize, areaOrigin) then
			return false
		end
	end

	return true
end

-- Get a model from ReplicatedStorage by path
local function getModelByPath(modelPath)
	if not modelPath then
		return nil
	end

	-- Parse model path (e.g., "ReplicatedStorage.Assets.Blueprints.Workbench")
	local pathParts = string.split(modelPath, ".")
	local current = ReplicatedStorage

	-- Skip first part if it's "ReplicatedStorage"
	local startIndex = 1
	if pathParts[1] == "ReplicatedStorage" then
		startIndex = 2
	end

	for i = startIndex, #pathParts do
		current = current:FindFirstChild(pathParts[i])
		if not current then
			warn("[BlueprintPlacementController] Model not found at path:", modelPath)
			return nil
		end
	end

	return current
end

-- Get the blueprint model from ReplicatedStorage
local function getBlueprintModel(definition)
	if not definition or not definition.modelPath then
		return nil
	end
	return getModelByPath(definition.modelPath)
end

-- Get the completed structure model from ReplicatedStorage
local function getCompletedModel(definition)
	if not definition or not definition.completedModelPath then
		return nil
	end
	return getModelByPath(definition.completedModelPath)
end

-- Create preview model for blueprint or structure placement
-- Clones the actual model and makes it transparent for preview
-- forStructure: if true, uses completedModelPath instead of modelPath
local function createPreviewModel(blueprintType, forStructure)
	local definition = BlueprintDefinitions.GetDefinition(blueprintType)
	if not definition then
		warn("[BlueprintPlacementController] Unknown blueprint type:", blueprintType)
		return nil
	end

	-- Get the source model from ReplicatedStorage
	local sourceModel
	if forStructure then
		sourceModel = getCompletedModel(definition)
		if not sourceModel then
			warn("[BlueprintPlacementController] Could not find completed model for:", blueprintType)
			return nil
		end
	else
		sourceModel = getBlueprintModel(definition)
		if not sourceModel then
			warn("[BlueprintPlacementController] Could not find blueprint model for:", blueprintType)
			return nil
		end
	end

	if not sourceModel:IsA("Model") then
		local modelPath = forStructure and definition.completedModelPath or definition.modelPath
		warn("[BlueprintPlacementController] Model path does not point to a Model:", modelPath)
		return nil
	end

	if not sourceModel.PrimaryPart then
		warn("[BlueprintPlacementController] Model has no PrimaryPart (anchor):", blueprintType)
		return nil
	end

	-- Clone the model for preview
	local preview = sourceModel:Clone()
	preview.Name = (forStructure and "StructurePreview_" or "BlueprintPreview_") .. blueprintType

	-- Make all parts transparent and non-collidable
	for _, descendant in ipairs(preview:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = PREVIEW_TRANSPARENCY
			descendant.CanCollide = false
			descendant.Anchored = true
			descendant.CastShadow = false
		end
	end

	-- Also apply to PrimaryPart
	if preview.PrimaryPart then
		preview.PrimaryPart.Transparency = PREVIEW_TRANSPARENCY
		preview.PrimaryPart.CanCollide = false
		preview.PrimaryPart.Anchored = true
		preview.PrimaryPart.CastShadow = false
	end

	return preview
end

-- Create highlight for preview
local function createHighlight(model)
	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 0.8
	highlight.OutlineTransparency = 0
	highlight.OutlineColor = HIGHLIGHT_VALID_COLOR
	highlight.FillColor = HIGHLIGHT_VALID_COLOR
	highlight.Adornee = model
	highlight.Parent = model

	return highlight
end

-- Update preview position
local function updatePreview()
	if not placementMode or not previewModel or not currentBlueprintType or not currentDefinition then
		return
	end

	-- Check if player is inside the BuildingArea
	local _, area = getBuildingZone()
	if not area then
		if previewModel.Parent then
			previewModel.Parent = nil
		end
		return
	end

	local character = player.Character
	if not character or not character.PrimaryPart then
		if previewModel.Parent then
			previewModel.Parent = nil
		end
		return
	end

	-- Raycast from mouse
	local camera = Workspace.CurrentCamera
	local mouseRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
	local rayOrigin = mouseRay.Origin
	local rayDirection = mouseRay.Direction * 1000

	-- Create raycast params (same as BuildingController)
	local raycastParams = RaycastParams.new()
	raycastParams.FilterType = Enum.RaycastFilterType.Blacklist

	-- Build filter list
	local filterList = {player.Character, previewModel}
	raycastParams.FilterDescendantsInstances = filterList

	-- Perform raycast
	local raycastResult = Workspace:Raycast(rayOrigin, rayDirection, raycastParams)

	if not raycastResult then
		if previewModel.Parent then
			previewModel.Parent = nil
		end
		return
	end

	-- Get hit position and normal (same as BuildingController)
	local hitPosition = raycastResult.Position
	local hitNormal = raycastResult.Normal

	-- Get building area info
	local areaOrigin = getBuildingAreaOrigin()
	local areaPosition = area.Position

	-- Calculate target position on surface (same as regular block placement)
	-- Add half the anchor block size in the direction of the normal
	local targetPosition = hitPosition + (hitNormal * (anchorBlockSize.Y / 2))

	-- Snap to grid based on anchor block size (same as BuildingController)
	local snappedPosition = snapToGridForBlockSize(targetPosition, anchorBlockSize)

	-- Clamp to building area bounds (same as BuildingController)
	local relativePos = snappedPosition - areaOrigin
	local halfBlockSize = anchorBlockSize / 2
	local clampedRelativeX = math.clamp(relativePos.X, -32 + halfBlockSize.X, 32 - halfBlockSize.X)
	local clampedRelativeZ = math.clamp(relativePos.Z, -32 + halfBlockSize.Z, 32 - halfBlockSize.Z)
	local clampedPosition = Vector3.new(
		areaOrigin.X + clampedRelativeX,
		snappedPosition.Y,
		areaOrigin.Z + clampedRelativeZ
	)
	clampedPosition = snapToGridForBlockSize(clampedPosition, anchorBlockSize)

	-- Check if ALL blocks in the blueprint are within bounds
	isValidPlacement = areAllBlocksWithinBounds(clampedPosition, currentDefinition, areaOrigin)

	-- Store the anchor position (this is what we send to the server)
	currentPosition = clampedPosition

	-- Update preview position using PrimaryPart as anchor
	if previewModel.PrimaryPart then
		previewModel:SetPrimaryPartCFrame(CFrame.new(clampedPosition))
	end

	-- Update highlight color
	if previewHighlight then
		local targetColor = isValidPlacement and HIGHLIGHT_VALID_COLOR or HIGHLIGHT_INVALID_COLOR
		previewHighlight.OutlineColor = targetColor
		previewHighlight.FillColor = targetColor
	end

	-- Make sure preview is visible
	if not previewModel.Parent then
		previewModel.Parent = Workspace
	end
end

-- Get anchor block size from definition (first block or block at offset 0,0,0)
local function getAnchorBlockSize(definition)
	if not definition or not definition.blocks or #definition.blocks == 0 then
		return DEFAULT_BLOCK_SIZE
	end

	-- Find the anchor block (offset 0,0,0) or use first block
	local anchorBlockType = nil
	for _, blockReq in ipairs(definition.blocks) do
		if blockReq.offset == Vector3.new(0, 0, 0) then
			anchorBlockType = blockReq.blockType
			break
		end
	end

	-- Fallback to first block if no 0,0,0 offset found
	if not anchorBlockType then
		anchorBlockType = definition.blocks[1].blockType
	end

	-- Get block size from ItemData
	local blockConfig = ItemData.GetItem(anchorBlockType)
	if blockConfig and blockConfig.blockSize then
		return blockConfig.blockSize
	end

	return DEFAULT_BLOCK_SIZE
end

-- Start placement mode for blueprint or structure
-- forStructure: if true, placing a completed structure; structureItemName is the item name
local function startPlacementMode(blueprintType, forStructure, structureItemName)
	if placementMode then
		stopPlacementMode()
	end

	local definition = BlueprintDefinitions.GetDefinition(blueprintType)
	if not definition then
		warn("[BlueprintPlacementController] Unknown blueprint type:", blueprintType)
		return
	end

	placementMode = true
	currentBlueprintType = blueprintType
	currentDefinition = definition
	isStructurePlacement = forStructure or false
	currentStructureItemName = structureItemName

	-- Get anchor block size for proper grid snapping
	anchorBlockSize = getAnchorBlockSize(definition)
	print("[BlueprintPlacementController] Anchor block size:", anchorBlockSize)

	-- Create preview model (clones from ReplicatedStorage)
	previewModel = createPreviewModel(blueprintType, isStructurePlacement)
	if not previewModel then
		warn("[BlueprintPlacementController] Failed to create preview model")
		stopPlacementMode()
		return
	end

	-- Create highlight
	previewHighlight = createHighlight(previewModel)

	local modeType = isStructurePlacement and "structure" or "blueprint"
	print("[BlueprintPlacementController] Started", modeType, "placement mode for:", blueprintType)
end

-- Stop placement mode
local function stopPlacementMode()
	if not placementMode then
		return
	end

	placementMode = false
	currentBlueprintType = nil
	currentDefinition = nil
	currentPosition = nil
	isValidPlacement = false
	anchorBlockSize = DEFAULT_BLOCK_SIZE
	isStructurePlacement = false
	currentStructureItemName = nil

	-- Destroy preview
	if previewModel then
		previewModel:Destroy()
		previewModel = nil
	end

	previewHighlight = nil

	print("[BlueprintPlacementController] Stopped placement mode")
end

-- Handle item equipped
local function onItemEquipped(slot, itemName)
	local itemConfig = ItemData.GetItem(itemName)

	if itemConfig and itemConfig.isBlueprintTool then
		-- Blueprint tool - place a new blueprint ghost
		if itemConfig.blueprintType then
			startPlacementMode(itemConfig.blueprintType, false, nil)
		else
			warn("[BlueprintPlacementController] Blueprint item missing blueprintType in config:", itemName)
		end
	elseif itemConfig and itemConfig.isStructure then
		-- Structure item - place a completed structure
		if itemConfig.blueprintType then
			startPlacementMode(itemConfig.blueprintType, true, itemName)
		else
			warn("[BlueprintPlacementController] Structure item missing blueprintType in config:", itemName)
		end
	else
		-- Not a blueprint or structure, stop placement mode if active
		if placementMode then
			stopPlacementMode()
		end
	end
end

-- Handle item unequipped
local function onItemUnequipped()
	if placementMode then
		stopPlacementMode()
	end
end

-- Handle mouse click for placement
local function onMouseClick()
	if not placementMode or not currentPosition or not currentBlueprintType then
		return
	end

	if not isValidPlacement then
		warn("[BlueprintPlacementController] Invalid placement position")
		return
	end

	-- Debug: print position being sent
	local areaOrigin = getBuildingAreaOrigin()
	print("[BlueprintPlacementController] Sending position:", currentPosition)
	print("[BlueprintPlacementController] Area origin:", areaOrigin)
	print("[BlueprintPlacementController] Relative position:", currentPosition - areaOrigin)

	if isStructurePlacement then
		-- Place completed structure via server
		BlueprintService:PlaceStructure(currentPosition, currentStructureItemName)
			:andThen(function(success, structureIdOrError)
				if success then
					print("[BlueprintPlacementController] Structure placed:", structureIdOrError)

					-- Stop placement mode after successful placement
					stopPlacementMode()

					-- Unequip the item (item is consumed by server)
					InventoryService:UnequipItem()
				else
					warn("[BlueprintPlacementController] Failed to place structure:", structureIdOrError)
				end
			end)
			:catch(function(err)
				warn("[BlueprintPlacementController] Error placing structure:", err)
			end)
	else
		-- Place blueprint via server
		BlueprintService:PlaceBlueprint(currentPosition, currentBlueprintType)
			:andThen(function(success, blueprintIdOrError)
				if success then
					print("[BlueprintPlacementController] Blueprint placed:", blueprintIdOrError)

					-- Stop placement mode after successful placement
					stopPlacementMode()

					-- Unequip the item (consume it)
					InventoryService:UnequipItem()
				else
					warn("[BlueprintPlacementController] Failed to place blueprint:", blueprintIdOrError)
				end
			end)
			:catch(function(err)
				warn("[BlueprintPlacementController] Error placing blueprint:", err)
			end)
	end
end

-- Handle input
local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	-- Left click to place blueprint
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if placementMode then
			onMouseClick()
		end
	end
end

-- Create client blueprint instance based on type (loads specific class if available)
local function createClientBlueprintInstance(data)
	local definition = BlueprintDefinitions.GetDefinition(data.blueprintType)
	if not definition then
		return ClientBaseBlueprint.new(data)
	end

	-- Try to load specific client class
	local clientClassName = definition.clientClass
	if clientClassName then
		local success, classModule = pcall(function()
			return require(StarterPlayer.StarterPlayerScripts.Client.Classes.Blueprints[clientClassName])
		end)

		if success and classModule then
			return classModule.new(data)
		end
	end

	-- Fallback to base class
	return ClientBaseBlueprint.new(data)
end

-- Handle blueprint placed signal from server
local function onBlueprintPlaced(blueprintData)
	-- Validate blueprintData is a table with required fields
	if type(blueprintData) ~= "table" then
		warn("[BlueprintPlacementController] Invalid blueprintData received (expected table, got " .. type(blueprintData) .. ")")
		return
	end

	if not blueprintData.id then
		warn("[BlueprintPlacementController] blueprintData missing 'id' field:", blueprintData)
		return
	end

	print("[BlueprintPlacementController] Blueprint placed by server:", blueprintData.id)

	-- Skip if already tracked (prevent duplicates)
	if activeBlueprints[blueprintData.id] then
		print("[BlueprintPlacementController] Blueprint already tracked, skipping:", blueprintData.id)
		return
	end

	-- Create client-side blueprint instance (uses specific class if available)
	local blueprint = createClientBlueprintInstance(blueprintData)
	activeBlueprints[blueprintData.id] = blueprint

	-- Find and store reference to the model
	local zone = getBuildingZone()
	if zone then
		-- Small delay to ensure model is created
		task.wait(0.1)

		for _, child in ipairs(zone:GetChildren()) do
			local bpId = child:FindFirstChild("BlueprintId")
			if bpId and bpId.Value == blueprintData.id then
				blueprint:SetModel(child)
				blueprint:UpdateVisuals()
				break
			end
		end
	end
end

-- Handle blueprint removed signal from server
local function onBlueprintRemoved(blueprintId)
	print("[BlueprintPlacementController] Blueprint removed:", blueprintId)

	local blueprint = activeBlueprints[blueprintId]
	if blueprint then
		blueprint:Destroy()
		activeBlueprints[blueprintId] = nil
	end
end

-- Handle block filled in blueprint
local function onBlueprintBlockFilled(blueprintId, offset, blockType, isCorrect)
	local blueprint = activeBlueprints[blueprintId]
	if not blueprint then return end

	-- Update filled blocks
	local offsetKey = string.format("%d,%d,%d", offset.x, offset.y, offset.z)
	blueprint.FilledBlocks[offsetKey] = {
		blockType = blockType,
		blockId = "unknown", -- We don't have the blockId on client for this event
	}

	-- Update visuals
	local offsetVector = Vector3.new(offset.x, offset.y, offset.z)
	blueprint:UpdateBlockVisual(offsetVector)

	-- Flash effect for feedback
	blueprint:FlashBlockSlot(offsetVector, isCorrect)

	-- If wrong block, find the block model and add highlight
	if not isCorrect then
		local zone = getBuildingZone()
		if zone then
			-- Find the most recently placed block at this position
			local areaOrigin = getBuildingAreaOrigin()
			local worldPos = blueprint:OffsetToWorld(offsetVector, areaOrigin)

			for _, child in ipairs(zone:GetChildren()) do
				local blockId = child:FindFirstChild("BlockId")
				if blockId and child:IsA("Model") or child:IsA("BasePart") then
					local blockPos
					if child:IsA("Model") and child.PrimaryPart then
						blockPos = child.PrimaryPart.Position
					elseif child:IsA("BasePart") then
						blockPos = child.Position
					end

					if blockPos and (blockPos - worldPos).Magnitude < 2 then
						blueprint:CreateWrongBlockHighlight(child, blockId.Value)
						break
					end
				end
			end
		end
	end
end

-- Handle block removed from blueprint
local function onBlueprintBlockRemoved(blueprintId, offset)
	local blueprint = activeBlueprints[blueprintId]
	if not blueprint then return end

	-- Update filled blocks
	local offsetKey = string.format("%d,%d,%d", offset.x, offset.y, offset.z)
	blueprint.FilledBlocks[offsetKey] = nil

	-- Update visuals
	blueprint:UpdateBlockVisual(Vector3.new(offset.x, offset.y, offset.z))
end

-- Handle blueprint completed
local function onBlueprintCompleted(blueprintId)
	local blueprint = activeBlueprints[blueprintId]
	if not blueprint then return end

	blueprint.CompletedAt = os.time()

	-- Update visuals
	blueprint:UpdateVisuals()

	-- Clear any wrong block highlights
	blueprint:ClearWrongBlockHighlights()
end

--|| Public Functions ||--

-- Check if placement mode is active
function BlueprintPlacementController:IsPlacementMode()
	return placementMode
end

-- Get current blueprint type being placed
function BlueprintPlacementController:GetCurrentBlueprintType()
	return currentBlueprintType
end

-- Start placement mode externally (e.g., from UI)
function BlueprintPlacementController:StartPlacementMode(blueprintType)
	startPlacementMode(blueprintType)
end

-- Stop placement mode externally
function BlueprintPlacementController:StopPlacementMode()
	stopPlacementMode()
end

-- Get active blueprint by ID
function BlueprintPlacementController:GetActiveBlueprint(blueprintId)
	return activeBlueprints[blueprintId]
end

-- Get all active blueprints
function BlueprintPlacementController:GetActiveBlueprints()
	return activeBlueprints
end

--|| Initialization ||--

function BlueprintPlacementController:KnitStart()
	BlueprintService = Knit.GetService("BlueprintService")
	InventoryService = Knit.GetService("InventoryService")

	-- Get building zone
	getBuildingZone()

	-- Connect to inventory signals
	InventoryService.ItemEquipped:Connect(onItemEquipped)
	InventoryService.ItemUnequipped:Connect(onItemUnequipped)

	-- Connect to blueprint service signals
	BlueprintService.BlueprintPlaced:Connect(onBlueprintPlaced)
	BlueprintService.BlueprintRemoved:Connect(onBlueprintRemoved)
	BlueprintService.BlueprintBlockFilled:Connect(onBlueprintBlockFilled)
	BlueprintService.BlueprintBlockRemoved:Connect(onBlueprintBlockRemoved)
	BlueprintService.BlueprintCompleted:Connect(onBlueprintCompleted)
	BlueprintService.StructurePlaced:Connect(onBlueprintPlaced) -- Structure uses same handler

	-- Update preview every frame
	RunService.RenderStepped:Connect(function()
		if placementMode then
			updatePreview()
		end
	end)

	-- Handle input
	UserInputService.InputBegan:Connect(onInputBegan)

	-- Note: Blueprints are loaded via BlueprintPlaced signal from server's LoadPlayerBlueprints
	-- No need to manually fetch them here

	print("[BlueprintPlacementController] Initialized")
end

return BlueprintPlacementController
