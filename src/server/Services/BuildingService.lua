-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Signal = require(game:GetService("ReplicatedStorage").Packages.Signal)

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

-- Services (to be initialized)
local DataService
local InventoryService

local BuildingService = Knit.CreateService({
	Name = "BuildingService",
	Client = {
		-- Signals for client updates
		BlockPlaced = Knit.CreateSignal(), -- (blockData)
		BlockRemoved = Knit.CreateSignal(), -- (blockId)
	},
})

-- Constants
local GRID_SIZE = 2 -- 2-stud grid
local BUILDING_AREA_SIZE = Vector3.new(64, 64, 64) -- BuildingArea dimensions

-- Types
type BlockData = {
	id: string,
	itemName: string,
	position: Vector3,
	size: Vector3,
}

-- References
local buildingZone = nil
local buildingArea = nil
local grassPart = nil

--|| Private Functions ||--

-- Get building zone references
local function getBuildingZone()
	if not buildingZone then
		buildingZone = Workspace:FindFirstChild("BuildingZone")
		if buildingZone then
			buildingArea = buildingZone:FindFirstChild("BuildingArea")
			grassPart = buildingZone:FindFirstChild("Grass")
		end
	end
	return buildingZone, buildingArea, grassPart
end

-- Snap position to 2-stud grid
local function snapToGrid(position: Vector3): Vector3?
	if not position then
		warn("snapToGrid: position is nil")
		return nil
	end

	-- Handle serialized Vector3 from network (table with X, Y, Z fields)
	local x, y, z
	if typeof(position) == "table" then
		x, y, z = position.X, position.Y, position.Z
	elseif typeof(position) == "Vector3" then
		x, y, z = position.X, position.Y, position.Z
	else
		warn("snapToGrid: invalid position type:", typeof(position))
		return nil
	end

	if not x or not y or not z then
		warn("snapToGrid: position has nil components")
		return nil
	end

	return Vector3.new(
		math.round(x / GRID_SIZE) * GRID_SIZE,
		math.round(y / GRID_SIZE) * GRID_SIZE,
		math.round(z / GRID_SIZE) * GRID_SIZE
	)
end

-- Convert world position to grid coordinates
local function worldToGrid(position: Vector3): Vector3
	return position / GRID_SIZE
end

-- Convert grid coordinates to world position
local function gridToWorld(gridPos: Vector3): Vector3
	return gridPos * GRID_SIZE
end

-- Get player's building data
local function getBuildingData(player: Player)
	local playerData = DataService:GetData(player)
	if not playerData then return nil end
	return playerData.Building
end

-- Generate unique block ID
local function generateBlockId(player: Player): string
	local playerData = DataService:GetData(player)
	if not playerData then return tostring(tick()) end

	local id = string.format("%s_block_%d", player.UserId, playerData.Building.NextBlockId)
	playerData.Building.NextBlockId = playerData.Building.NextBlockId + 1

	return id
end

-- Check if position is within building area bounds
-- BuildingArea origin is at floor level (0,0,0)
-- Bounds: X/Z from -32 to +32, Y from 0 to 64
local function isWithinBounds(position: Vector3, blockSize: Vector3): boolean
	local _, area, _ = getBuildingZone()
	if not area then
		warn("BuildingArea not found for bounds check")
		return false
	end

	-- Get BuildingArea origin position (floor level)
	-- BuildingArea Part.Position.Y - 32 = floor level (Y=0)
	local areaPosition = area.Position
	local areaOrigin = Vector3.new(areaPosition.X, areaPosition.Y - 32, areaPosition.Z)

	-- Calculate relative position
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

-- Check if position overlaps with existing blocks
local function hasCollision(player: Player, position: Vector3, blockSize: Vector3): boolean
	local buildingData = getBuildingData(player)
	if not buildingData then return false end

	-- Get BuildingArea to convert relative → world position
	local _, area, _ = getBuildingZone()
	if not area then
		warn("BuildingArea not found for collision check")
		return false
	end

	-- Get BuildingArea origin position (floor level)
	local areaPosition = area.Position
	local areaOrigin = Vector3.new(areaPosition.X, areaPosition.Y - 32, areaPosition.Z)

	local halfSize = blockSize / 2

	for _, block in ipairs(buildingData.PlacedBlocks) do
		-- Handle both old (position) and new (relativePosition) data formats
		local existingPos
		if block.relativePosition then
			-- New format: convert relative → world
			local relativePos = Vector3.new(
				block.relativePosition.x,
				block.relativePosition.y,
				block.relativePosition.z
			)
			existingPos = areaOrigin + relativePos
		elseif block.position then
			-- Old format: use absolute position (backwards compatibility)
			existingPos = Vector3.new(block.position.x, block.position.y, block.position.z)
		else
			warn("Block has neither position nor relativePosition!")
			continue
		end

		local existingSize = Vector3.new(block.size.x, block.size.y, block.size.z)
		local existingHalfSize = existingSize / 2

		-- AABB collision detection
		if math.abs(position.X - existingPos.X) < (halfSize.X + existingHalfSize.X) and
		   math.abs(position.Y - existingPos.Y) < (halfSize.Y + existingHalfSize.Y) and
		   math.abs(position.Z - existingPos.Z) < (halfSize.Z + existingHalfSize.Z) then
			return true
		end
	end

	return false
end

-- Check if a block is on the ground level
local function isOnGround(position: Vector3, blockSize: Vector3): boolean
	local _, _, grass = getBuildingZone()
	if not grass then return false end

	local grassTop = grass.Position.Y + (grass.Size.Y / 2)
	local blockBottom = position.Y - (blockSize.Y / 2)

	-- Block is on ground if its bottom aligns with grass top (within grid tolerance)
	return math.abs(blockBottom - grassTop) < GRID_SIZE
end

-- Get blocks at a specific grid position (checking for support)
local function getBlocksAt(player: Player, gridX: number, gridY: number, gridZ: number): {BlockData}
	local buildingData = getBuildingData(player)
	if not buildingData then return {} end

	-- Get BuildingArea to convert relative → world position
	local _, area, _ = getBuildingZone()
	if not area then
		warn("BuildingArea not found for getBlocksAt")
		return {}
	end

	-- Get BuildingArea origin position (floor level)
	local areaPosition = area.Position
	local areaOrigin = Vector3.new(areaPosition.X, areaPosition.Y - 32, areaPosition.Z)

	local blocks = {}

	for _, block in ipairs(buildingData.PlacedBlocks) do
		-- Handle both old (position) and new (relativePosition) data formats
		local blockWorldPos
		if block.relativePosition then
			-- New format: convert relative → world
			local relativePos = Vector3.new(
				block.relativePosition.x,
				block.relativePosition.y,
				block.relativePosition.z
			)
			blockWorldPos = areaOrigin + relativePos
		elseif block.position then
			-- Old format: use absolute position (backwards compatibility)
			blockWorldPos = Vector3.new(block.position.x, block.position.y, block.position.z)
		else
			warn("Block has neither position nor relativePosition!")
			continue
		end

		local blockGridPos = worldToGrid(blockWorldPos)
		local blockGridSize = worldToGrid(Vector3.new(block.size.x, block.size.y, block.size.z))

		-- Calculate grid bounds of this block
		local minX = blockGridPos.X - blockGridSize.X / 2
		local maxX = blockGridPos.X + blockGridSize.X / 2
		local minY = blockGridPos.Y - blockGridSize.Y / 2
		local maxY = blockGridPos.Y + blockGridSize.Y / 2
		local minZ = blockGridPos.Z - blockGridSize.Z / 2
		local maxZ = blockGridPos.Z + blockGridSize.Z / 2

		-- Check if target grid position is within this block
		if gridX >= minX and gridX < maxX and
		   gridY >= minY and gridY < maxY and
		   gridZ >= minZ and gridZ < maxZ then
			table.insert(blocks, block)
		end
	end

	return blocks
end

-- Check if a block has proper support underneath
local function hasProperSupport(player: Player, position: Vector3, blockSize: Vector3): boolean
	-- Check if on ground first
	if isOnGround(position, blockSize) then
		return true
	end

	local buildingData = getBuildingData(player)
	if not buildingData then return false end

	-- Convert to grid coordinates
	local gridPos = worldToGrid(position)
	local gridSize = worldToGrid(blockSize)

	-- Calculate required grid cells underneath
	-- A 4x4x4 block is 2x2x2 in grid space, needs 2x2 cells filled below
	-- A 2x2x2 block is 1x1x1 in grid space, needs 1x1 cell filled below
	local gridWidth = gridSize.X -- How many grid cells wide
	local gridDepth = gridSize.Z -- How many grid cells deep

	-- Check each grid cell underneath the block
	local requiredCells = {}
	local startX = gridPos.X - gridWidth / 2
	local startZ = gridPos.Z - gridDepth / 2
	local checkY = gridPos.Y - gridSize.Y / 2 - 0.5 -- Just below the block

	-- Generate all required grid positions underneath
	for x = 0, gridWidth - 1 do
		for z = 0, gridDepth - 1 do
			table.insert(requiredCells, {
				x = startX + x + 0.5,
				z = startZ + z + 0.5,
			})
		end
	end

	-- Check if all required cells have support
	for _, cell in ipairs(requiredCells) do
		local blocksBelow = getBlocksAt(player, cell.x, checkY, cell.z)
		if #blocksBelow == 0 then
			return false -- Missing support in this cell
		end
	end

	return true -- All cells have support
end

-- Check if a block has at least one adjacent neighbor
local function hasAdjacentBlock(player: Player, position: Vector3, blockSize: Vector3): boolean
	local buildingData = getBuildingData(player)
	if not buildingData then return false end

	local gridPos = worldToGrid(position)
	local gridSize = worldToGrid(blockSize)

	-- Check 4 horizontal directions (left, right, forward, back)
	local directions = {
		Vector3.new(-gridSize.X, 0, 0), -- Left
		Vector3.new(gridSize.X, 0, 0),  -- Right
		Vector3.new(0, 0, -gridSize.Z), -- Back
		Vector3.new(0, 0, gridSize.Z),  -- Forward
	}

	for _, dir in ipairs(directions) do
		local checkPos = gridPos + dir
		local blocks = getBlocksAt(player, checkPos.X, checkPos.Y, checkPos.Z)
		if #blocks > 0 then
			return true
		end
	end

	return false
end

-- Check if there's at least one block in the structure with ground support (flood fill check)
local function hasGroundConnection(player: Player, position: Vector3, blockSize: Vector3): boolean
	-- If this block is on ground, structure is valid
	if isOnGround(position, blockSize) then
		return true
	end

	local buildingData = getBuildingData(player)
	if not buildingData then return false end

	-- Get BuildingArea to convert relative → world position
	local _, area, _ = getBuildingZone()
	if not area then
		warn("BuildingArea not found for hasGroundConnection")
		return false
	end

	-- Get BuildingArea origin position (floor level)
	local areaPosition = area.Position
	local areaOrigin = Vector3.new(areaPosition.X, areaPosition.Y - 32, areaPosition.Z)

	-- Flood fill to find if any connected block reaches ground
	local visited = {}
	local queue = {worldToGrid(position)}

	while #queue > 0 do
		local current = table.remove(queue, 1)
		local key = string.format("%.2f_%.2f_%.2f", current.X, current.Y, current.Z)

		if visited[key] then
			continue
		end
		visited[key] = true

		-- Check if this position has a block
		local blocks = getBlocksAt(player, current.X, current.Y, current.Z)
		for _, block in ipairs(blocks) do
			-- Handle both old (position) and new (relativePosition) data formats
			local blockPos
			if block.relativePosition then
				-- New format: convert relative → world
				local relativePos = Vector3.new(
					block.relativePosition.x,
					block.relativePosition.y,
					block.relativePosition.z
				)
				blockPos = areaOrigin + relativePos
			elseif block.position then
				-- Old format: use absolute position (backwards compatibility)
				blockPos = Vector3.new(block.position.x, block.position.y, block.position.z)
			else
				warn("Block has neither position nor relativePosition!")
				continue
			end

			local blockSize = Vector3.new(block.size.x, block.size.y, block.size.z)

			-- If this block is on ground, we found a connection
			if isOnGround(blockPos, blockSize) then
				return true
			end

			-- Add adjacent blocks to queue
			local blockGridSize = worldToGrid(blockSize)
			local directions = {
				Vector3.new(-blockGridSize.X, 0, 0),
				Vector3.new(blockGridSize.X, 0, 0),
				Vector3.new(0, 0, -blockGridSize.Z),
				Vector3.new(0, 0, blockGridSize.Z),
				Vector3.new(0, blockGridSize.Y, 0), -- Up
				Vector3.new(0, -blockGridSize.Y, 0), -- Down
			}

			for _, dir in ipairs(directions) do
				table.insert(queue, current + dir)
			end
		end
	end

	return false
end

--|| Public Functions ||--

-- Validate block placement
function BuildingService:CanPlaceBlock(player: Player, position: Vector3, itemName: string): (boolean, string?)
	-- Get item config
	local itemConfig = ItemData.GetItem(itemName)
	if not itemConfig or itemConfig.type ~= "Block" then
		return false, "Invalid block item"
	end

	if not itemConfig.blockSize then
		return false, "Item is not a building block"
	end

	local blockSize = itemConfig.blockSize

	-- Snap position to grid
	local snappedPos = snapToGrid(position)
	if not snappedPos then
		return false, "Invalid position"
	end

	-- Check bounds
	if not isWithinBounds(snappedPos, blockSize) then
		return false, "Outside building area"
	end

	-- Check collision
	if hasCollision(player, snappedPos, blockSize) then
		return false, "Overlapping with existing block"
	end

	-- Check support
	if not hasProperSupport(player, snappedPos, blockSize) then
		-- If no support underneath, check if adjacent to another block
		if not hasAdjacentBlock(player, snappedPos, blockSize) then
			return false, "No support or adjacent block"
		end

		-- If adjacent, check if structure has ground connection
		if not hasGroundConnection(player, snappedPos, blockSize) then
			return false, "Structure must connect to ground"
		end
	end

	return true, nil
end

-- Place a block
function BuildingService:PlaceBlock(player: Player, position: Vector3, itemName: string): boolean
	print("[BuildingService] PlaceBlock called for", player.Name, "at position:", position, "item:", itemName)

	-- Validate placement
	local canPlace, errorMsg = self:CanPlaceBlock(player, position, itemName)
	if not canPlace then
		warn("[BuildingService] Cannot place block:", errorMsg)
		return false
	end

	print("[BuildingService] Validation passed")

	-- Get item config
	local itemConfig = ItemData.GetItem(itemName)
	local blockSize = itemConfig.blockSize
	local snappedPos = snapToGrid(position)

	if not snappedPos then
		warn("[BuildingService] Invalid position for block placement")
		return false
	end

	print("[BuildingService] Snapped position:", snappedPos)

	-- Check if player has the item equipped
	local inventory = InventoryService:GetInventory(player)
	if not inventory or not inventory.EquippedSlot then
		warn("No item equipped")
		return false
	end

	local equippedItem = inventory.Hotbar[inventory.EquippedSlot]
	if not equippedItem or equippedItem.itemName ~= itemName then
		warn("Different item equipped")
		return false
	end

	-- Consume item from inventory
	local consumed = InventoryService:RemoveItem(player, equippedItem.id, 1)
	if not consumed then
		warn("Failed to consume item")
		return false
	end

	-- Create block in world
	local blockModel = self:CreateBlockInWorld(itemName, snappedPos, blockSize)
	if not blockModel then
		-- Refund item if block creation failed
		InventoryService:AddItem(player, itemName, 1)
		return false
	end

	-- Save to player data
	local buildingData = getBuildingData(player)
	if not buildingData then return false end

	-- Initialize BuildingAreaId if not set
	if not buildingData.BuildingAreaId then
		buildingData.BuildingAreaId = tostring(player.UserId)
	end

	-- Get BuildingArea to convert world → relative position
	local _, area, _ = getBuildingZone()
	if not area then
		warn("[BuildingService] BuildingArea not found for saving block")
		InventoryService:AddItem(player, itemName, 1) -- Refund
		return false
	end

	-- Convert world position to relative position
	-- BuildingArea Part.Position.Y - 32 = floor level (Y=0)
	local areaPosition = area.Position
	local areaOrigin = Vector3.new(areaPosition.X, areaPosition.Y - 32, areaPosition.Z)
	local relativePos = snappedPos - areaOrigin

	local blockId = generateBlockId(player)
	local blockData = {
		id = blockId,
		itemName = itemName,
		relativePosition = {x = relativePos.X, y = relativePos.Y, z = relativePos.Z},
		size = {x = blockSize.X, y = blockSize.Y, z = blockSize.Z},
		buildingAreaId = buildingData.BuildingAreaId,
	}

	print("[BuildingService] Saving block - World pos:", snappedPos, "Relative pos:", relativePos)

	table.insert(buildingData.PlacedBlocks, blockData)

	-- Store block ID in model for reference
	local idValue = Instance.new("StringValue")
	idValue.Name = "BlockId"
	idValue.Value = blockId
	idValue.Parent = blockModel

	-- Store player ID in model
	local playerIdValue = Instance.new("IntValue")
	playerIdValue.Name = "PlayerId"
	playerIdValue.Value = player.UserId
	playerIdValue.Parent = blockModel

	-- Notify client
	self.Client.BlockPlaced:Fire(player, blockData)

	return true
end

-- Create a block in the world
function BuildingService:CreateBlockInWorld(itemName: string, position: Vector3, size: Vector3): Model?
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
	local blockModel = current:Clone()
	blockModel.Name = itemName .. "_Block"

	-- Set position and size
	if blockModel:IsA("Model") and blockModel.PrimaryPart then
		blockModel:SetPrimaryPartCFrame(CFrame.new(position))
		-- Scale model to match size if needed
	elseif blockModel:IsA("BasePart") then
		blockModel.Position = position
		blockModel.Size = size
		blockModel.Anchored = true
		blockModel.CanCollide = true
	end

	-- Parent to BuildingZone
	local zone, _, _ = getBuildingZone()
	if zone then
		blockModel.Parent = zone
	else
		blockModel.Parent = Workspace
	end

	return blockModel
end

-- Load all placed blocks for a player
function BuildingService:LoadPlacedBlocks(player: Player)
	local buildingData = getBuildingData(player)
	if not buildingData then return end

	-- Get BuildingArea to convert relative → world position
	local _, area, _ = getBuildingZone()
	if not area then
		warn("[BuildingService] BuildingArea not found for loading blocks")
		return
	end

	-- Get BuildingArea origin position (floor level)
	-- BuildingArea Part.Position.Y - 32 = floor level (Y=0)
	local areaPosition = area.Position
	local areaOrigin = Vector3.new(areaPosition.X, areaPosition.Y - 32, areaPosition.Z)

	for _, blockData in ipairs(buildingData.PlacedBlocks) do
		-- Handle both old (absolute position) and new (relative position) data formats
		local worldPosition
		if blockData.relativePosition then
			-- New format: convert relative → world
			local relativePos = Vector3.new(
				blockData.relativePosition.x,
				blockData.relativePosition.y,
				blockData.relativePosition.z
			)
			worldPosition = areaOrigin + relativePos
			print("[BuildingService] Loading block - Relative:", relativePos, "World:", worldPosition)
		else
			-- Old format: use absolute position (backwards compatibility)
			worldPosition = Vector3.new(blockData.position.x, blockData.position.y, blockData.position.z)
			warn("[BuildingService] Loading old format block with absolute position")
		end

		local size = Vector3.new(blockData.size.x, blockData.size.y, blockData.size.z)

		local blockModel = self:CreateBlockInWorld(blockData.itemName, worldPosition, size)
		if blockModel then
			-- Store block ID in model
			local idValue = Instance.new("StringValue")
			idValue.Name = "BlockId"
			idValue.Value = blockData.id
			idValue.Parent = blockModel

			-- Store player ID in model
			local playerIdValue = Instance.new("IntValue")
			playerIdValue.Name = "PlayerId"
			playerIdValue.Value = player.UserId
			playerIdValue.Parent = blockModel
		end
	end
end

-- Get snapped position for preview
function BuildingService.Client:GetSnappedPosition(player: Player, position: Vector3)
	local snapped = snapToGrid(position)
	if not snapped then
		return nil
	end

	-- Return as a plain table to avoid serialization issues
	return {
		x = snapped.X,
		y = snapped.Y,
		z = snapped.Z,
	}
end

-- Validate placement for client preview
function BuildingService.Client:ValidatePlacement(player: Player, position: Vector3, itemName: string): (boolean, string?)
	return self.Server:CanPlaceBlock(player, position, itemName)
end

-- Place block (client call)
function BuildingService.Client:PlaceBlock(player: Player, position: Vector3, itemName: string): boolean
	return self.Server:PlaceBlock(player, position, itemName)
end

-- Get building area info for client
function BuildingService.Client:GetBuildingAreaInfo(player: Player)
	local zone, area, grass = getBuildingZone()
	if not area or not grass then
		return nil
	end

	return {
		position = area.Position,
		size = area.Size,
		grassY = grass.Position.Y + (grass.Size.Y / 2),
	}
end

-- KNIT START
function BuildingService:KnitStart()
	DataService = Knit.GetService("DataService")
	InventoryService = Knit.GetService("InventoryService")

	-- Get building zone references
	getBuildingZone()

	if not buildingZone then
		warn("BuildingZone not found in workspace!")
	end

	-- Load blocks when players join
	local Players = game:GetService("Players")

	local function onPlayerAdded(player)
		player.CharacterAdded:Connect(function()
			task.wait(1) -- Wait for data to load
			self:LoadPlacedBlocks(player)
		end)

		-- Also load if character already exists
		if player.Character then
			task.wait(1)
			self:LoadPlacedBlocks(player)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	-- Clean up blocks when player leaves
	Players.PlayerRemoving:Connect(function(player)
		-- Find and remove all blocks belonging to this player
		local zone, _, _ = getBuildingZone()
		if zone then
			for _, child in ipairs(zone:GetChildren()) do
				local playerIdValue = child:FindFirstChild("PlayerId")
				if playerIdValue and playerIdValue.Value == player.UserId then
					child:Destroy()
				end
			end
		end
	end)
end

return BuildingService
