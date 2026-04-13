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

local BlueprintService = Knit.CreateService({
	Name = "BlueprintService",
	Client = {
		BlueprintPlaced = Knit.CreateSignal(), -- (blueprintData)
		BlueprintRemoved = Knit.CreateSignal(), -- (blueprintId)
		BlueprintBlockFilled = Knit.CreateSignal(), -- (blueprintId, offset, blockType, isCorrect)
		BlueprintBlockRemoved = Knit.CreateSignal(), -- (blueprintId, offset)
		BlueprintCompleted = Knit.CreateSignal(), -- (blueprintId)
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
	print("[createBlueprintInstance] Creating instance for type:", data.blueprintType)

	local definition = BlueprintDefinitions.GetDefinition(data.blueprintType)
	if not definition then
		print("[createBlueprintInstance] No definition found, using base class")
		return ServerBaseBlueprint.new(data)
	end

	-- Try to load specific class
	local serverClassName = definition.serverClass
	print("[createBlueprintInstance] Server class name from definition:", serverClassName)

	if serverClassName then
		local success, classModule = pcall(function()
			return require(game:GetService("ServerScriptService").Server.Classes.Blueprints[serverClassName])
		end)

		if success and classModule then
			print("[createBlueprintInstance] Successfully loaded class:", serverClassName)
			return classModule.new(data)
		else
			print("[createBlueprintInstance] Failed to load class:", serverClassName, "error:", classModule)
		end
	end

	-- Fallback to base class
	print("[createBlueprintInstance] Using fallback base class")
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

-- Check if blueprint overlaps with existing blocks or blueprints
local function hasCollision(player, relativePosition, blueprintSize)
	-- Check collision with existing blueprints
	local blueprints = playerBlueprints[player]
	if blueprints then
		for _, blueprint in pairs(blueprints) do
			local bpMin = blueprint.RelativePosition
			local bpMax = blueprint.RelativePosition + blueprint.Definition.size

			local newMin = relativePosition
			local newMax = relativePosition + blueprintSize

			-- AABB collision
			if newMin.X < bpMax.X and newMax.X > bpMin.X and
			   newMin.Y < bpMax.Y and newMax.Y > bpMin.Y and
			   newMin.Z < bpMax.Z and newMax.Z > bpMin.Z then
				return true
			end
		end
	end

	-- TODO: Check collision with existing blocks in BuildingService

	return false
end

--|| Public Functions ||--

-- Place a new blueprint
function BlueprintService:PlaceBlueprint(player, position, blueprintType, rotation)
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

	-- For collision checking, calculate bounding box from anchor
	local halfAnchorSize = anchorBlockSize / 2
	local cornerRelative = anchorRelative - halfAnchorSize

	if hasCollision(player, cornerRelative, definition.size) then
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
		rotation = rotation or 0,
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
	end)

	-- Notify client
	self.Client.BlueprintPlaced:Fire(player, newBlueprintData)

	print("[BlueprintService] Blueprint placed:", blueprintId)
	return true, blueprintId
end

-- Get blueprint at a specific world position
function BlueprintService:GetBlueprintAtPosition(player, worldPosition)
	print("[BlueprintService:GetBlueprintAtPosition] Called for player:", player.Name, "worldPos:", worldPosition)

	local blueprints = playerBlueprints[player]
	if not blueprints then
		print("[BlueprintService:GetBlueprintAtPosition] No blueprints found for player")
		return nil, nil
	end

	local areaOrigin = getBuildingAreaOrigin()
	local relativePos = worldPosition - areaOrigin
	print("[BlueprintService:GetBlueprintAtPosition] Area origin:", areaOrigin, "relativePos:", relativePos)

	for bpId, blueprint in pairs(blueprints) do
		print("[BlueprintService:GetBlueprintAtPosition] Checking blueprint:", bpId)

		if not blueprint.Definition then
			print("[BlueprintService:GetBlueprintAtPosition] Blueprint has no definition, skipping")
			continue
		end

		local bpMin = blueprint.RelativePosition
		local bpMax = blueprint.RelativePosition + blueprint.Definition.size

		print("[BlueprintService:GetBlueprintAtPosition] Blueprint bounds - min:", bpMin, "max:", bpMax)
		print("[BlueprintService:GetBlueprintAtPosition] Block relative pos:", relativePos)

		-- Check if position is within blueprint bounds
		if relativePos.X >= bpMin.X and relativePos.X < bpMax.X and
		   relativePos.Y >= bpMin.Y and relativePos.Y < bpMax.Y and
		   relativePos.Z >= bpMin.Z and relativePos.Z < bpMax.Z then
			-- Calculate offset within blueprint
			local offset = relativePos - blueprint.RelativePosition

			-- Snap to grid
			offset = Vector3.new(
				math.floor(offset.X / GRID_SIZE) * GRID_SIZE,
				math.floor(offset.Y / GRID_SIZE) * GRID_SIZE,
				math.floor(offset.Z / GRID_SIZE) * GRID_SIZE
			)

			print("[BlueprintService:GetBlueprintAtPosition] MATCH! Blueprint:", bpId, "Offset:", offset)
			return blueprint, offset
		else
			print("[BlueprintService:GetBlueprintAtPosition] No match for blueprint:", bpId)
		end
	end

	print("[BlueprintService:GetBlueprintAtPosition] No blueprint found at this position")
	return nil, nil
end

-- Called when a block is placed inside a blueprint
function BlueprintService:OnBlockPlacedInBlueprint(player, blueprintId, offset, blockType, blockId)
	print("[BlueprintService:OnBlockPlacedInBlueprint] Called!")
	print("[BlueprintService:OnBlockPlacedInBlueprint] Player:", player.Name, "BlueprintId:", blueprintId)
	print("[BlueprintService:OnBlockPlacedInBlueprint] Offset:", offset, "BlockType:", blockType, "BlockId:", blockId)

	local blueprints = playerBlueprints[player]
	if not blueprints then
		print("[BlueprintService:OnBlockPlacedInBlueprint] No blueprints found for player")
		return false, false
	end

	local blueprint = blueprints[blueprintId]
	if not blueprint then
		print("[BlueprintService:OnBlockPlacedInBlueprint] Blueprint not found:", blueprintId)
		print("[BlueprintService:OnBlockPlacedInBlueprint] Available blueprints:")
		for id, _ in pairs(blueprints) do
			print("  -", id)
		end
		return false, false
	end

	print("[BlueprintService:OnBlockPlacedInBlueprint] Found blueprint, calling FillBlock...")

	-- Fill the block slot
	local success, isCorrect = blueprint:FillBlock(offset, blockType, blockId)
	print("[BlueprintService:OnBlockPlacedInBlueprint] FillBlock result - success:", success, "isCorrect:", isCorrect)

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
					print("[BlueprintService:OnBlockPlacedInBlueprint] Persisted block at key:", offsetKey)

					if blueprint.CompletedAt > 0 then
						bpData.completedAt = blueprint.CompletedAt
						print("[BlueprintService:OnBlockPlacedInBlueprint] Blueprint marked as completed in data!")
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
		print("[BlueprintService:OnBlockPlacedInBlueprint] Client notified")
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

-- Remove a blueprint
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

-- Load all blueprints for a player (called on join)
function BlueprintService:LoadPlayerBlueprints(player)
	print("[BlueprintService] ========== LOADING BLUEPRINTS ==========")
	print("[BlueprintService] Player:", player.Name)

	local blueprintData = getBlueprintData(player)
	if not blueprintData then
		print("[BlueprintService] No blueprint data found for player")
		return
	end

	local areaOrigin = getBuildingAreaOrigin()
	print("[BlueprintService] Area origin:", areaOrigin)

	-- Initialize player blueprint table
	playerBlueprints[player] = {}

	for i, bpData in ipairs(blueprintData.PlacedBlueprints) do
		print("[BlueprintService] --- Loading blueprint", i, "---")
		print("[BlueprintService] ID:", bpData.id)
		print("[BlueprintService] Type:", bpData.blueprintType)
		print("[BlueprintService] CompletedAt:", bpData.completedAt)

		-- Count filled blocks in saved data
		local savedFilledCount = 0
		if bpData.filledBlocks then
			for key, _ in pairs(bpData.filledBlocks) do
				savedFilledCount = savedFilledCount + 1
			end
		end
		print("[BlueprintService] Saved filled blocks:", savedFilledCount)

		-- Create blueprint instance (this will use the specific class like Workbench)
		local blueprint = createBlueprintInstance(bpData)
		print("[BlueprintService] Blueprint instance created, class type check - IsActive property exists:", blueprint.IsActive ~= nil)

		playerBlueprints[player][bpData.id] = blueprint

		-- Create model in world
		blueprint:CreateModel(areaOrigin)

		-- Connect events for future completions
		blueprint.OnCompleted:Connect(function()
			print("[BlueprintService] OnCompleted fired for blueprint:", bpData.id)
			self.Client.BlueprintCompleted:Fire(player, bpData.id)
		end)

		-- Notify client
		self.Client.BlueprintPlaced:Fire(player, bpData)
	end

	print("[BlueprintService] Loaded", #blueprintData.PlacedBlueprints, "blueprints for", player.Name)
	print("[BlueprintService] ==========================================")
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

--|| Client Functions ||--

function BlueprintService.Client:PlaceBlueprint(player, position, blueprintType, rotation)
	return self.Server:PlaceBlueprint(player, position, blueprintType, rotation)
end

function BlueprintService.Client:RemoveBlueprint(player, blueprintId)
	return self.Server:RemoveBlueprint(player, blueprintId)
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

	-- For collision checking, calculate bounding box from anchor
	local halfAnchorSize = anchorBlockSize / 2
	local cornerRelative = anchorRelative - halfAnchorSize

	if hasCollision(player, cornerRelative, definition.size) then
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
