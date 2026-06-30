--[=[
	BlueprintService
	Server-side service for managing blueprint placement and filling
]=]

local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Signal = require(game:GetService("ReplicatedStorage").Packages.Signal)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")

local BlueprintDefinitions = require(ReplicatedStorage.Shared.Data.Blueprints)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local ServerBaseBlueprint = require(game:GetService("ServerScriptService").Server.Classes.Blueprints.BaseBlueprint)

-- Services (to be initialized)
local DataService
local InventoryService
local BuildingService
local BreakingService

local BlueprintService = Knit.CreateService({
	Name = "BlueprintService",
	Client = {
		BlueprintPlaced = Knit.CreateSignal(), -- (blueprintData)
		BlueprintRemoved = Knit.CreateSignal(), -- (blueprintId)
		BlueprintBlockFilled = Knit.CreateSignal(), -- (blueprintId, offset, blockType, isCorrect)
		BlueprintBlockRemoved = Knit.CreateSignal(), -- (blueprintId, offset)
		BlueprintCompleted = Knit.CreateSignal(), -- (blueprintId)
		StructurePlaced = Knit.CreateSignal(), -- (structureData) - when completed structure is placed from inventory
	},
})

-- Constants
local GRID_SIZE = 2 -- Same as BuildingService (2-stud grid)
local BUILDING_AREA_SIZE = Vector3.new(64, 64, 64)

-- Active blueprint instances (by player)
local playerBlueprints = {} -- { [Player]: { [blueprintId]: ServerBaseBlueprint } }

-- Building zone references
local buildingZone = nil
local buildingArea = nil

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

-- Get player's blueprint data
local function getBlueprintData(player)
	local playerData = DataService:GetData(player)
	if not playerData then return nil end
	return playerData.Blueprints
end

-- Generate unique blueprint ID
local function generateBlueprintId(player)
	local blueprintData = getBlueprintData(player)
	if not blueprintData then return tostring(tick()) end

	local id = string.format("%s_bp_%d", player.UserId, blueprintData.NextBlueprintId)
	blueprintData.NextBlueprintId = blueprintData.NextBlueprintId + 1

	return id
end

-- Create blueprint class instance based on type
local function createBlueprintInstance(data)
	local definition = BlueprintDefinitions.GetDefinition(data.blueprintType)
	if not definition then
		return ServerBaseBlueprint.new(data)
	end

	-- Try to load specific class
	local serverClassName = definition.serverClass
	if serverClassName then
		local success, classModule = pcall(function()
			return require(game:GetService("ServerScriptService").Server.Classes.Blueprints[serverClassName])
		end)

		if success and classModule then
			return classModule.new(data)
		end
	end

	-- Fallback to base class
	return ServerBaseBlueprint.new(data)
end

-- Snap position to grid based on block size (same as BuildingService)
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

-- Get anchor block size from definition
local function getAnchorBlockSize(definition)
	local DEFAULT_BLOCK_SIZE = Vector3.new(4, 4, 4)

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

-- Check if a single block position is within building area bounds
local function isBlockWithinBounds(blockCenter: Vector3, blockSize: Vector3): boolean
	local halfBlockSize = blockSize / 2

	local blockMin = blockCenter - halfBlockSize
	local blockMax = blockCenter + halfBlockSize

	-- Small tolerance for floating point precision errors
	local TOLERANCE = 0.1

	-- Building area bounds: X/Z from -32 to +32, Y from 0 to 64
	return blockMin.X >= -32 - TOLERANCE and blockMax.X <= 32 + TOLERANCE and
	       blockMin.Y >= 0 - TOLERANCE and blockMax.Y <= 64 + TOLERANCE and
	       blockMin.Z >= -32 - TOLERANCE and blockMax.Z <= 32 + TOLERANCE
end

-- Check if ALL blocks of the blueprint are within building area bounds
-- anchorPosition: position of anchor block center relative to area origin
-- definition: blueprint definition with blocks table
local function areAllBlocksWithinBounds(anchorRelativePosition: Vector3, definition): boolean
	if not definition or not definition.blocks then
		return false
	end

	local DEFAULT_BLOCK_SIZE = Vector3.new(4, 4, 4)

	for _, blockReq in ipairs(definition.blocks) do
		-- Get block type config to determine block size
		local blockConfig = ItemData.GetItem(blockReq.blockType)
		local blockSize = blockConfig and blockConfig.blockSize or DEFAULT_BLOCK_SIZE

		-- Calculate this block's relative position (anchor + offset)
		local blockCenter = anchorRelativePosition + blockReq.offset

		if not isBlockWithinBounds(blockCenter, blockSize) then
			print("[BlueprintService] Block out of bounds:", blockReq.blockType, "at", blockCenter)
			return false
		end
	end

	return true
end

-- Handle blueprint completion - replace blocks with completed model
local function onBlueprintCompleted(player, blueprint)
	print("[BlueprintService] Blueprint completed:", blueprint.Id)

	local areaOrigin = getBuildingAreaOrigin()

	-- Remove all the individual blocks that were placed for this blueprint
	if BuildingService and blueprint.FilledBlocks then
		for offsetKey, blockData in pairs(blueprint.FilledBlocks) do
			if blockData.blockId then
				-- Remove block without giving item back (it's part of the structure now)
				BuildingService:RemoveBlockSilent(player, blockData.blockId)
			end
		end
	end

	-- Create the completed structure model
	local completedModel = blueprint:CreateCompletedModel(areaOrigin)
	if not completedModel then
		warn("[BlueprintService] Failed to create completed model for:", blueprint.Id)
		return
	end

	-- Register as breakable with BreakingService
	if BreakingService then
		local breakableId = blueprint:GetBreakableId()
		local dropItem = blueprint:GetDropItemName()

		BreakingService:RegisterBreakable(player, breakableId, {
			materialType = "Structure",
			dropItem = dropItem or "",
			dropAmount = 1,
			position = completedModel.PrimaryPart and completedModel.PrimaryPart.Position or areaOrigin + blueprint.RelativePosition,
			part = completedModel,
			customBreakTime = 2.0,
			onBroken = function(breakingPlayer, brokenBreakableId)
				-- Handle structure destruction
				BlueprintService:OnStructureBroken(breakingPlayer, blueprint.Id)
			end,
		})
	end
end

-- Compute world-space AABB for a blueprint given its anchor center position
local function getBlueprintAABB(anchorRelative, definition)
	local minOffset, maxOffset = BlueprintDefinitions.GetBounds(definition)
	local HALF_BLOCK = 2
	local halfVec = Vector3.new(HALF_BLOCK, HALF_BLOCK, HALF_BLOCK)
	local bpMin = anchorRelative + minOffset - halfVec
	local bpMax = anchorRelative + maxOffset + halfVec
	return bpMin, bpMax
end

-- Check if blueprint overlaps with existing blueprints
local function hasCollision(player, anchorRelative, definition)
	local blueprints = playerBlueprints[player]
	if not blueprints then return false end

	local newMin, newMax = getBlueprintAABB(anchorRelative, definition)

	for _, blueprint in pairs(blueprints) do
		if not blueprint.Definition then continue end
		local bpMin, bpMax = getBlueprintAABB(blueprint.RelativePosition, blueprint.Definition)

		if newMin.X < bpMax.X and newMax.X > bpMin.X and
		   newMin.Y < bpMax.Y and newMax.Y > bpMin.Y and
		   newMin.Z < bpMax.Z and newMax.Z > bpMin.Z then
			return true
		end
	end

	return false
end

--|| Public Functions ||--

-- Place a new blueprint
function BlueprintService:PlaceBlueprint(player, position, blueprintType)
	print("[BlueprintService] PlaceBlueprint called:", player.Name, blueprintType)

	-- Get blueprint definition
	local definition = BlueprintDefinitions.GetDefinition(blueprintType)
	if not definition then
		warn("[BlueprintService] Unknown blueprint type:", blueprintType)
		return false, "Unknown blueprint type"
	end

	-- Get building area origin
	local areaOrigin = getBuildingAreaOrigin()

	-- Get anchor block size for proper snapping
	local anchorBlockSize = getAnchorBlockSize(definition)

	-- Calculate relative position from anchor (client sends anchor center position)
	local worldPosition = Vector3.new(position.X or position.x, position.Y or position.y, position.Z or position.z)
	local snappedPosition = snapToGridForBlockSize(worldPosition, anchorBlockSize)

	-- Anchor relative position (center of anchor block relative to area origin)
	local anchorRelative = snappedPosition - areaOrigin

	print("[BlueprintService] World position received:", worldPosition)
	print("[BlueprintService] Area origin:", areaOrigin)
	print("[BlueprintService] Snapped position:", snappedPosition)
	print("[BlueprintService] Anchor relative position:", anchorRelative)
	print("[BlueprintService] Anchor block size:", anchorBlockSize)

	-- Validate placement - check each block individually
	if not areAllBlocksWithinBounds(anchorRelative, definition) then
		print("[BlueprintService] Bounds check FAILED")
		return false, "Outside building area"
	end
	print("[BlueprintService] Bounds check PASSED")

	if hasCollision(player, anchorRelative, definition) then
		return false, "Overlapping with existing structure"
	end

	-- Get player data
	local blueprintData = getBlueprintData(player)
	if not blueprintData then
		return false, "Player data not found"
	end

	-- Check max quantity
	local currentCount = 0
	for _, bp in ipairs(blueprintData.PlacedBlueprints) do
		if bp.blueprintType == blueprintType then
			currentCount = currentCount + 1
		end
	end

	if currentCount >= definition.maxQuantity then
		return false, "Maximum quantity reached"
	end

	-- Check if player has the blueprint item equipped and consume it
	local inventory = InventoryService:GetInventory(player)
	if not inventory or not inventory.EquippedSlot then
		warn("[BlueprintService] No item equipped")
		return false, "No item equipped"
	end

	local equippedItem = inventory.Hotbar[inventory.EquippedSlot]
	local expectedItemName = blueprintType .. "Blueprint"
	if not equippedItem or equippedItem.itemName ~= expectedItemName then
		warn("[BlueprintService] Wrong item equipped:", equippedItem and equippedItem.itemName or "nil", "expected:", expectedItemName)
		return false, "Wrong item equipped"
	end

	-- Consume the blueprint item from inventory
	local consumed = InventoryService:RemoveItem(player, equippedItem.id, 1)
	if not consumed then
		warn("[BlueprintService] Failed to consume blueprint item")
		return false, "Failed to consume item"
	end

	-- Create blueprint data
	-- Store anchor center position (used by CreateModel to position PrimaryPart)
	local blueprintId = generateBlueprintId(player)
	local newBlueprintData = {
		id = blueprintId,
		blueprintType = blueprintType,
		relativePosition = {
			x = anchorRelative.X,
			y = anchorRelative.Y,
			z = anchorRelative.Z,
		},
		rotation = 0,
		ownerId = player.UserId,
		completedAt = 0,
		filledBlocks = {},
	}

	-- Save to player data
	table.insert(blueprintData.PlacedBlueprints, newBlueprintData)

	-- Create blueprint instance
	local blueprint = createBlueprintInstance(newBlueprintData)

	-- Initialize player blueprint table if needed
	if not playerBlueprints[player] then
		playerBlueprints[player] = {}
	end
	playerBlueprints[player][blueprintId] = blueprint

	-- Create model in world
	blueprint:CreateModel(areaOrigin)

	-- Connect events
	blueprint.OnCompleted:Connect(function()
		self.Client.BlueprintCompleted:Fire(player, blueprintId)
		-- Handle completion - replace with solid model
		onBlueprintCompleted(player, blueprint)
	end)

	-- Notify client
	self.Client.BlueprintPlaced:Fire(player, newBlueprintData)

	print("[BlueprintService] Blueprint placed:", blueprintId)
	return true, blueprintId
end

-- Get blueprint at a specific world position
function BlueprintService:GetBlueprintAtPosition(player, worldPosition)
	local blueprints = playerBlueprints[player]
	if not blueprints then return nil, nil end

	local areaOrigin = getBuildingAreaOrigin()
	local relativePos = worldPosition - areaOrigin

	for _, blueprint in pairs(blueprints) do
		if not blueprint.Definition then continue end

		local bpMin, bpMax = getBlueprintAABB(blueprint.RelativePosition, blueprint.Definition)

		-- Check if position is within blueprint AABB
		if relativePos.X >= bpMin.X and relativePos.X < bpMax.X and
		   relativePos.Y >= bpMin.Y and relativePos.Y < bpMax.Y and
		   relativePos.Z >= bpMin.Z and relativePos.Z < bpMax.Z then
			-- Calculate offset relative to anchor (round to nearest integer for float safety)
			local rawOffset = relativePos - blueprint.RelativePosition
			local offset = Vector3.new(
				math.round(rawOffset.X),
				math.round(rawOffset.Y),
				math.round(rawOffset.Z)
			)

			return blueprint, offset
		end
	end

	return nil, nil
end

-- Called when a block is placed inside a blueprint
function BlueprintService:OnBlockPlacedInBlueprint(player, blueprintId, offset, blockType, blockId)
	local blueprints = playerBlueprints[player]
	if not blueprints then return false, false end

	local blueprint = blueprints[blueprintId]
	if not blueprint then return false, false end

	-- Fill the block slot
	local success, isCorrect = blueprint:FillBlock(offset, blockType, blockId)

	if success then
		-- Update persisted data
		local blueprintData = getBlueprintData(player)
		if blueprintData then
			for _, bpData in ipairs(blueprintData.PlacedBlueprints) do
				if bpData.id == blueprintId then
					local offsetKey = string.format("%d,%d,%d", offset.X, offset.Y, offset.Z)
					bpData.filledBlocks[offsetKey] = {
						blockType = blockType,
						blockId = blockId,
					}

					if blueprint.CompletedAt > 0 then
						bpData.completedAt = blueprint.CompletedAt
					end
					break
				end
			end
		end

		-- Notify client
		self.Client.BlueprintBlockFilled:Fire(player, blueprintId, {
			x = offset.X,
			y = offset.Y,
			z = offset.Z,
		}, blockType, isCorrect)
	end

	return success, isCorrect
end

-- Called when a block is removed from inside a blueprint
function BlueprintService:OnBlockRemovedFromBlueprint(player, blueprintId, offset)
	local blueprints = playerBlueprints[player]
	if not blueprints then return false end

	local blueprint = blueprints[blueprintId]
	if not blueprint then return false end

	-- Remove the filled block
	local success = blueprint:RemoveFilledBlock(offset)

	if success then
		-- Update persisted data
		local blueprintData = getBlueprintData(player)
		if blueprintData then
			for _, bpData in ipairs(blueprintData.PlacedBlueprints) do
				if bpData.id == blueprintId then
					local offsetKey = string.format("%d,%d,%d", offset.X, offset.Y, offset.Z)
					bpData.filledBlocks[offsetKey] = nil
					bpData.completedAt = 0
					break
				end
			end
		end

		-- Notify client
		self.Client.BlueprintBlockRemoved:Fire(player, blueprintId, {
			x = offset.X,
			y = offset.Y,
			z = offset.Z,
		})
	end

	return success
end

-- Remove a blueprint (used internally, doesn't return item)
function BlueprintService:RemoveBlueprint(player, blueprintId)
	local blueprints = playerBlueprints[player]
	if not blueprints then return false end

	local blueprint = blueprints[blueprintId]
	if not blueprint then return false end

	-- Destroy the model
	blueprint:DestroyModel()

	-- Remove from active blueprints
	blueprints[blueprintId] = nil

	-- Remove from persisted data
	local blueprintData = getBlueprintData(player)
	if blueprintData then
		for i, bpData in ipairs(blueprintData.PlacedBlueprints) do
			if bpData.id == blueprintId then
				table.remove(blueprintData.PlacedBlueprints, i)
				break
			end
		end
	end

	-- Notify client
	self.Client.BlueprintRemoved:Fire(player, blueprintId)

	return true
end

-- Remove an uncompleted blueprint with hammer - returns blueprint item and any placed blocks
function BlueprintService:RemoveUncompletedBlueprint(player, blueprintId)
	local blueprints = playerBlueprints[player]
	if not blueprints then return false, "No blueprints found" end

	local blueprint = blueprints[blueprintId]
	if not blueprint then return false, "Blueprint not found" end

	-- Can't remove completed blueprints this way (use hammer breaking for structures)
	if blueprint.CompletedAt > 0 or blueprint.IsStructureComplete then
		return false, "Blueprint is completed - use hammer to break the structure"
	end

	-- Return all filled blocks to inventory
	if blueprint.FilledBlocks and BuildingService then
		for offsetKey, blockData in pairs(blueprint.FilledBlocks) do
			if blockData.blockId then
				-- Remove the block and return it to inventory
				BuildingService:RemoveBlock(player, blockData.blockId)
			end
		end
	end

	-- Get the blueprint item name to return
	local blueprintItemName = blueprint.BlueprintType .. "Blueprint"

	-- Destroy the model
	blueprint:DestroyModel()

	-- Remove from active blueprints
	blueprints[blueprintId] = nil

	-- Remove from persisted data
	local blueprintData = getBlueprintData(player)
	if blueprintData then
		for i, bpData in ipairs(blueprintData.PlacedBlueprints) do
			if bpData.id == blueprintId then
				table.remove(blueprintData.PlacedBlueprints, i)
				break
			end
		end
	end

	-- Return blueprint item to inventory
	InventoryService:AddItem(player, blueprintItemName, 1)

	-- Notify client
	self.Client.BlueprintRemoved:Fire(player, blueprintId)

	print("[BlueprintService] Uncompleted blueprint removed, returned:", blueprintItemName)
	return true, blueprintItemName
end

-- Load all blueprints for a player (called on join)
function BlueprintService:LoadPlayerBlueprints(player)
	local blueprintData = getBlueprintData(player)
	if not blueprintData then return end

	local areaOrigin = getBuildingAreaOrigin()

	-- Initialize player blueprint table
	playerBlueprints[player] = {}

	for _, bpData in ipairs(blueprintData.PlacedBlueprints) do
		-- Create blueprint instance
		local blueprint = createBlueprintInstance(bpData)
		playerBlueprints[player][bpData.id] = blueprint

		-- Check if already completed
		local isAlreadyCompleted = bpData.completedAt and bpData.completedAt > 0

		if isAlreadyCompleted then
			-- Create completed structure model directly
			blueprint:CreateCompletedModel(areaOrigin)

			-- Register as breakable
			if BreakingService then
				local breakableId = blueprint:GetBreakableId()
				local dropItem = blueprint:GetDropItemName()

				BreakingService:RegisterBreakable(player, breakableId, {
					materialType = "Structure",
					dropItem = dropItem or "",
					dropAmount = 1,
					position = blueprint.CompletedModel and blueprint.CompletedModel.PrimaryPart and blueprint.CompletedModel.PrimaryPart.Position or areaOrigin + blueprint.RelativePosition,
					part = blueprint.CompletedModel,
					customBreakTime = 2.0,
					onBroken = function(breakingPlayer, brokenBreakableId)
						BlueprintService:OnStructureBroken(breakingPlayer, bpData.id)
					end,
				})
			end
		else
			-- Create ghost model
			blueprint:CreateModel(areaOrigin)
		end

		-- Connect events for future completion
		blueprint.OnCompleted:Connect(function()
			self.Client.BlueprintCompleted:Fire(player, bpData.id)
			onBlueprintCompleted(player, blueprint)
		end)

		-- Notify client
		self.Client.BlueprintPlaced:Fire(player, bpData)
	end
end

-- Get all blueprints for a player
function BlueprintService:GetPlayerBlueprints(player)
	return playerBlueprints[player] or {}
end

-- Get a specific blueprint
function BlueprintService:GetBlueprint(player, blueprintId)
	local blueprints = playerBlueprints[player]
	if not blueprints then return nil end
	return blueprints[blueprintId]
end

-- Called when a completed structure is broken (legacy - for BreakingService callback)
function BlueprintService:OnStructureBroken(player, blueprintId)
	print("[BlueprintService] Structure broken:", blueprintId)

	local blueprints = playerBlueprints[player]
	if not blueprints then return end

	local blueprint = blueprints[blueprintId]
	if not blueprint then return end

	-- The item is already given by BreakingService, just clean up

	-- Remove from active blueprints
	blueprints[blueprintId] = nil

	-- Remove from persisted data
	local blueprintData = getBlueprintData(player)
	if blueprintData then
		for i, bpData in ipairs(blueprintData.PlacedBlueprints) do
			if bpData.id == blueprintId then
				table.remove(blueprintData.PlacedBlueprints, i)
				break
			end
		end
	end

	-- Notify client
	self.Client.BlueprintRemoved:Fire(player, blueprintId)
end

-- Remove a completed structure with hammer - instant removal, returns structure item
function BlueprintService:RemoveCompletedStructure(player, blueprintId)
	print("[BlueprintService] RemoveCompletedStructure called:", blueprintId)

	local blueprints = playerBlueprints[player]
	if not blueprints then return false, "No blueprints found" end

	local blueprint = blueprints[blueprintId]
	if not blueprint then return false, "Blueprint not found" end

	-- Must be a completed structure
	if blueprint.CompletedAt == 0 and not blueprint.IsStructureComplete then
		return false, "Structure is not completed - use RemoveUncompletedBlueprint instead"
	end

	-- Get the drop item name
	local dropItemName = blueprint:GetDropItemName()
	if not dropItemName then
		dropItemName = "Completed" .. blueprint.BlueprintType
	end

	-- Unregister from BreakingService if it was registered
	if BreakingService then
		local breakableId = blueprint:GetBreakableId()
		BreakingService:UnregisterBreakable(player, breakableId)
	end

	-- Destroy the model
	blueprint:DestroyModel()

	-- Remove from active blueprints
	blueprints[blueprintId] = nil

	-- Remove from persisted data
	local blueprintData = getBlueprintData(player)
	if blueprintData then
		for i, bpData in ipairs(blueprintData.PlacedBlueprints) do
			if bpData.id == blueprintId then
				table.remove(blueprintData.PlacedBlueprints, i)
				break
			end
		end
	end

	-- Give item to player
	InventoryService:AddItem(player, dropItemName, 1)

	-- Notify client
	self.Client.BlueprintRemoved:Fire(player, blueprintId)

	print("[BlueprintService] Completed structure removed, gave item:", dropItemName)
	return true, dropItemName
end

-- Place a completed structure from inventory
function BlueprintService:PlaceStructure(player, position, structureItemName)
	print("[BlueprintService] PlaceStructure called:", player.Name, structureItemName)

	-- Get item config
	local itemConfig = ItemData.GetItem(structureItemName)
	if not itemConfig or not itemConfig.isStructure then
		warn("[BlueprintService] Not a valid structure item:", structureItemName)
		return false, "Invalid structure item"
	end

	local blueprintType = itemConfig.blueprintType
	if not blueprintType then
		warn("[BlueprintService] Structure has no blueprintType:", structureItemName)
		return false, "Invalid structure configuration"
	end

	-- Get blueprint definition for size/positioning
	local definition = BlueprintDefinitions.GetDefinition(blueprintType)
	if not definition then
		warn("[BlueprintService] Unknown blueprint type:", blueprintType)
		return false, "Unknown structure type"
	end

	-- Get building area origin
	local areaOrigin = getBuildingAreaOrigin()

	-- Get anchor block size for proper snapping
	local anchorBlockSize = getAnchorBlockSize(definition)

	-- Calculate position
	local worldPosition = Vector3.new(position.X or position.x, position.Y or position.y, position.Z or position.z)
	local snappedPosition = snapToGridForBlockSize(worldPosition, anchorBlockSize)
	local anchorRelative = snappedPosition - areaOrigin

	-- Validate placement
	if not areAllBlocksWithinBounds(anchorRelative, definition) then
		return false, "Outside building area"
	end

	if hasCollision(player, anchorRelative, definition) then
		return false, "Overlapping with existing structure"
	end

	-- Check if player has the item equipped
	local inventory = InventoryService:GetInventory(player)
	if not inventory or not inventory.EquippedSlot then
		warn("No item equipped")
		return false
	end

	local equippedItem = inventory.Hotbar[inventory.EquippedSlot]
	if not equippedItem or equippedItem.itemName ~= structureItemName then
		warn("Different item equipped")
		return false
	end

	-- Consume item from inventory
	local consumed = InventoryService:RemoveItem(player, equippedItem.id, 1)
	if not consumed then
		warn("Failed to consume item")
		return false
	end

	-- Get player data
	local blueprintData = getBlueprintData(player)
	if not blueprintData then
		-- Refund item
		InventoryService:AddItem(player, structureItemName, 1)
		return false, "Player data not found"
	end

	-- Create blueprint data (already completed)
	local blueprintId = generateBlueprintId(player)
	local newBlueprintData = {
		id = blueprintId,
		blueprintType = blueprintType,
		relativePosition = {
			x = anchorRelative.X,
			y = anchorRelative.Y,
			z = anchorRelative.Z,
		},
		rotation = 0,
		ownerId = player.UserId,
		completedAt = os.time(), -- Already completed
		filledBlocks = {}, -- No individual blocks
	}

	-- Save to player data
	table.insert(blueprintData.PlacedBlueprints, newBlueprintData)

	-- Create blueprint instance
	local blueprint = createBlueprintInstance(newBlueprintData)
	blueprint.CompletedAt = os.time()

	-- Initialize player blueprint table if needed
	if not playerBlueprints[player] then
		playerBlueprints[player] = {}
	end
	playerBlueprints[player][blueprintId] = blueprint

	-- Create completed model directly
	local completedModel = blueprint:CreateCompletedModel(areaOrigin)
	if not completedModel then
		-- Refund item
		InventoryService:AddItem(player, structureItemName, 1)
		-- Cleanup
		playerBlueprints[player][blueprintId] = nil
		for i, bpData in ipairs(blueprintData.PlacedBlueprints) do
			if bpData.id == blueprintId then
				table.remove(blueprintData.PlacedBlueprints, i)
				break
			end
		end
		return false, "Failed to create structure model"
	end

	-- Register as breakable
	if BreakingService then
		local breakableId = blueprint:GetBreakableId()
		local dropItem = blueprint:GetDropItemName()

		BreakingService:RegisterBreakable(player, breakableId, {
			materialType = "Structure",
			dropItem = dropItem or "",
			dropAmount = 1,
			position = completedModel.PrimaryPart and completedModel.PrimaryPart.Position or snappedPosition,
			part = completedModel,
			customBreakTime = 2.0,
			onBroken = function(breakingPlayer, brokenBreakableId)
				self:OnStructureBroken(breakingPlayer, blueprintId)
			end,
		})
	end

	-- Notify client
	self.Client.StructurePlaced:Fire(player, newBlueprintData)

	print("[BlueprintService] Structure placed:", blueprintId)
	return true, blueprintId
end

--|| Client Functions ||--

function BlueprintService.Client:PlaceBlueprint(player, position, blueprintType)
	return self.Server:PlaceBlueprint(player, position, blueprintType)
end

function BlueprintService.Client:RemoveBlueprint(player, blueprintId)
	return self.Server:RemoveBlueprint(player, blueprintId)
end

function BlueprintService.Client:RemoveUncompletedBlueprint(player, blueprintId)
	return self.Server:RemoveUncompletedBlueprint(player, blueprintId)
end

function BlueprintService.Client:RemoveCompletedStructure(player, blueprintId)
	return self.Server:RemoveCompletedStructure(player, blueprintId)
end

function BlueprintService.Client:PlaceStructure(player, position, structureItemName)
	return self.Server:PlaceStructure(player, position, structureItemName)
end

function BlueprintService.Client:GetPlayerBlueprints(player)
	local blueprints = self.Server:GetPlayerBlueprints(player)
	local serialized = {}

	for id, blueprint in pairs(blueprints) do
		serialized[id] = blueprint:Serialize()
	end

	return serialized
end

function BlueprintService.Client:GetBlueprintAtPosition(player, worldPosition)
	local blueprint, offset = self.Server:GetBlueprintAtPosition(player, worldPosition)
	if not blueprint then return nil, nil end

	return blueprint:Serialize(), {
		x = offset.X,
		y = offset.Y,
		z = offset.Z,
	}
end

function BlueprintService.Client:ValidateBlueprintPlacement(player, position, blueprintType)
	local definition = BlueprintDefinitions.GetDefinition(blueprintType)
	if not definition then
		return false, "Unknown blueprint type"
	end

	local areaOrigin = getBuildingAreaOrigin()
	local anchorBlockSize = getAnchorBlockSize(definition)
	local worldPosition = Vector3.new(position.X or position.x, position.Y or position.y, position.Z or position.z)
	local snappedPosition = snapToGridForBlockSize(worldPosition, anchorBlockSize)
	local anchorRelative = snappedPosition - areaOrigin

	if not areAllBlocksWithinBounds(anchorRelative, definition) then
		return false, "Outside building area"
	end

	if hasCollision(player, anchorRelative, definition) then
		return false, "Overlapping with existing structure"
	end

	return true, nil
end

function BlueprintService.Client:GetSnappedPosition(player, position, blueprintType)
	local definition = BlueprintDefinitions.GetDefinition(blueprintType)
	if not definition then return nil end

	local anchorBlockSize = getAnchorBlockSize(definition)
	local worldPosition = Vector3.new(position.X or position.x, position.Y or position.y, position.Z or position.z)
	local snapped = snapToGridForBlockSize(worldPosition, anchorBlockSize)

	return {
		x = snapped.X,
		y = snapped.Y,
		z = snapped.Z,
	}
end

--|| KnitStart ||--

function BlueprintService:KnitStart()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")
	BuildingService = Knit.GetService("BuildingService")
	BreakingService = Knit.GetService("BreakingService")

	-- Get building zone references
	getBuildingZone()

	if not buildingZone then
		warn("[BlueprintService] BuildingZone not found in workspace!")
	end

	-- Load blueprints when players join
	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function()
			task.wait(1.5) -- Wait for data to load
			self:LoadPlayerBlueprints(player)
		end)

		-- Also load if character already exists
		if player.Character then
			task.wait(1.5)
			self:LoadPlayerBlueprints(player)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Cleanup when players leave
	Players.PlayerRemoving:Connect(function(player)
		local blueprints = playerBlueprints[player]
		if blueprints then
			for _, blueprint in pairs(blueprints) do
				blueprint:DestroyModel()
			end
			playerBlueprints[player] = nil
		end
	end)
end

return BlueprintService
