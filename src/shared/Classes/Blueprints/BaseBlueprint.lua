--[=[
	BaseBlueprint - Shared Base Class
	Common blueprint functionality for both server and client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlueprintDefinitions = require(ReplicatedStorage.Shared.Data.Blueprints)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local BaseBlueprint = {}
BaseBlueprint.__index = BaseBlueprint

export type BlueprintData = {
	id: string,
	blueprintType: string,
	relativePosition: { x: number, y: number, z: number },
	rotation: number,
	ownerId: number,
	completedAt: number,
	filledBlocks: { [string]: { blockType: string, blockId: string } },
}

function BaseBlueprint.new(data: BlueprintData)
	local self = setmetatable({}, BaseBlueprint)

	self.Id = data.id
	self.BlueprintType = data.blueprintType
	self.RelativePosition = Vector3.new(data.relativePosition.x, data.relativePosition.y, data.relativePosition.z)
	self.Rotation = data.rotation or 0
	self.OwnerId = data.ownerId
	self.CompletedAt = data.completedAt or 0
	self.FilledBlocks = data.filledBlocks or {}

	-- Get definition
	self.Definition = BlueprintDefinitions.GetDefinition(data.blueprintType)
	if not self.Definition then
		warn("[BaseBlueprint] Unknown blueprint type:", data.blueprintType)
	end

	return self
end

-- Check if blueprint is complete (all required blocks filled with correct types)
function BaseBlueprint:IsComplete(): boolean
	if not self.Definition then return false end

	for _, blockReq in ipairs(self.Definition.blocks) do
		local offsetKey = self:_OffsetToKey(blockReq.offset)
		local filledBlock = self.FilledBlocks[offsetKey]

		if not filledBlock then
			return false -- Missing block
		end

		if filledBlock.blockType ~= blockReq.blockType then
			return false -- Wrong block type
		end
	end

	return true
end

-- Get the required block type at a specific offset
function BaseBlueprint:GetRequiredBlockAt(offset: Vector3): string?
	if not self.Definition then return nil end

	for _, blockReq in ipairs(self.Definition.blocks) do
		if blockReq.offset == offset then
			return blockReq.blockType
		end
	end

	return nil
end

-- Check if a position is within blueprint bounds (supports negative offsets)
function BaseBlueprint:IsPositionInBounds(offset: Vector3): boolean
	if not self.Definition then return false end

	local minOffset, maxOffset = BlueprintDefinitions.GetBounds(self.Definition)
	return offset.X >= minOffset.X and offset.X <= maxOffset.X and
	       offset.Y >= minOffset.Y and offset.Y <= maxOffset.Y and
	       offset.Z >= minOffset.Z and offset.Z <= maxOffset.Z
end

-- Get the filled block at a specific offset
function BaseBlueprint:GetFilledBlockAt(offset: Vector3): { blockType: string, blockId: string }?
	local offsetKey = self:_OffsetToKey(offset)
	return self.FilledBlocks[offsetKey]
end

-- Get the number of correctly filled blocks
function BaseBlueprint:GetFilledBlockCount(): number
	local count = 0
	for _ in pairs(self.FilledBlocks) do
		count = count + 1
	end
	return count
end

-- Get progress as a percentage (0-100)
function BaseBlueprint:GetProgress(): number
	if not self.Definition then return 0 end

	local total = #self.Definition.blocks
	if total == 0 then return 100 end

	local filled = self:GetFilledBlockCount()
	return math.floor((filled / total) * 100)
end

-- Convert world position to blueprint-relative offset
function BaseBlueprint:WorldToOffset(worldPosition: Vector3, buildingAreaOrigin: Vector3): Vector3
	-- Convert world position to relative position
	local relativeToArea = worldPosition - buildingAreaOrigin

	-- Convert to offset relative to blueprint origin
	local offsetFromBlueprint = relativeToArea - self.RelativePosition

	-- Snap to grid (4-stud blocks)
	local GRID_SIZE = 4
	return Vector3.new(
		math.floor(offsetFromBlueprint.X / GRID_SIZE) * GRID_SIZE,
		math.floor(offsetFromBlueprint.Y / GRID_SIZE) * GRID_SIZE,
		math.floor(offsetFromBlueprint.Z / GRID_SIZE) * GRID_SIZE
	)
end

-- Convert blueprint-relative offset to world position
function BaseBlueprint:OffsetToWorld(offset: Vector3, buildingAreaOrigin: Vector3): Vector3
	local GRID_SIZE = 4
	local blockCenter = offset + Vector3.new(GRID_SIZE / 2, GRID_SIZE / 2, GRID_SIZE / 2)
	return buildingAreaOrigin + self.RelativePosition + blockCenter
end

-- Get all required block positions (offsets)
function BaseBlueprint:GetAllRequiredOffsets(): { Vector3 }
	if not self.Definition then return {} end

	local offsets = {}
	for _, blockReq in ipairs(self.Definition.blocks) do
		table.insert(offsets, blockReq.offset)
	end
	return offsets
end

-- Build a neighbor map: for each block, find all face-adjacent blocks.
-- Two blocks are face-adjacent if their bounding boxes overlap on two axes
-- and their edges touch (gap = 0) on the third axis.
function BaseBlueprint:_BuildNeighborMap(): { [string]: { [string]: boolean } }
	if not self.Definition then return {} end

	local neighborMap = {}
	local TOLERANCE = 0.1
	local DEFAULT_BLOCK_SIZE = Vector3.new(4, 4, 4)

	local function addPair(key1, key2)
		if not neighborMap[key1] then neighborMap[key1] = {} end
		if not neighborMap[key2] then neighborMap[key2] = {} end
		neighborMap[key1][key2] = true
		neighborMap[key2][key1] = true
	end

	local function getBlockSize(blockReq)
		local config = ItemData.GetItem(blockReq.blockType)
		return config and config.blockSize or DEFAULT_BLOCK_SIZE
	end

	-- Check if two ranges overlap (exclusive — just touching doesn't count as overlap)
	local function rangesOverlap(aMin, aMax, bMin, bMax)
		return aMin < bMax - TOLERANCE and bMin < aMax - TOLERANCE
	end

	-- Check if two edges touch on an axis
	local function edgesTouch(aMin, aMax, bMin, bMax)
		return math.abs(aMax - bMin) < TOLERANCE or math.abs(bMax - aMin) < TOLERANCE
	end

	local blocks = self.Definition.blocks

	for i = 1, #blocks do
		local a = blocks[i]
		local aSize = getBlockSize(a)
		local aMin = a.offset - aSize / 2
		local aMax = a.offset + aSize / 2

		for j = i + 1, #blocks do
			local b = blocks[j]
			local bSize = getBlockSize(b)
			local bMin = b.offset - bSize / 2
			local bMax = b.offset + bSize / 2

			-- Check each axis as the "touch" axis, other two must overlap
			local xOverlap = rangesOverlap(aMin.X, aMax.X, bMin.X, bMax.X)
			local yOverlap = rangesOverlap(aMin.Y, aMax.Y, bMin.Y, bMax.Y)
			local zOverlap = rangesOverlap(aMin.Z, aMax.Z, bMin.Z, bMax.Z)
			local xTouch = edgesTouch(aMin.X, aMax.X, bMin.X, bMax.X)
			local yTouch = edgesTouch(aMin.Y, aMax.Y, bMin.Y, bMax.Y)
			local zTouch = edgesTouch(aMin.Z, aMax.Z, bMin.Z, bMax.Z)

			if (xTouch and yOverlap and zOverlap)
				or (yTouch and xOverlap and zOverlap)
				or (zTouch and xOverlap and yOverlap) then
				addPair(self:_OffsetToKey(a.offset), self:_OffsetToKey(b.offset))
			end
		end
	end

	return neighborMap
end

-- Get offset keys that should be visible as ghost blocks (progressive reveal).
-- The anchor block (0,0,0) is always visible. Filled blocks reveal their face-neighbors,
-- but a block is only shown if every block below it in the same column is filled.
-- If showAll is true, all unfilled blocks are visible.
function BaseBlueprint:GetVisibleOffsetKeys(showAll: boolean?): { [string]: boolean }
	if not self.Definition then return {} end

	-- Show all unfilled blocks when no building block is equipped
	if showAll then
		local visible = {}
		for _, blockReq in ipairs(self.Definition.blocks) do
			visible[self:_OffsetToKey(blockReq.offset)] = true
		end
		return visible
	end

	local neighborMap = self:_BuildNeighborMap()

	local offsetKeyToBlock = {}
	for _, blockReq in ipairs(self.Definition.blocks) do
		offsetKeyToBlock[self:_OffsetToKey(blockReq.offset)] = blockReq
	end

	local function getBlockSize(blockReq)
		local config = ItemData.GetItem(blockReq.blockType)
		return config and config.blockSize or Vector3.new(4, 4, 4)
	end

	-- A block has support if no unfilled block exists directly below it (touching on Y, overlapping on X/Z)
	local TOLERANCE = 0.1
	local function hasSupport(offsetKey)
		local blockReq = offsetKeyToBlock[offsetKey]
		if not blockReq then return false end

		local size = getBlockSize(blockReq)
		local myMinY = blockReq.offset.Y - size.Y / 2
		local myMinX = blockReq.offset.X - size.X / 2
		local myMaxX = blockReq.offset.X + size.X / 2
		local myMinZ = blockReq.offset.Z - size.Z / 2
		local myMaxZ = blockReq.offset.Z + size.Z / 2

		for _, other in ipairs(self.Definition.blocks) do
			if other == blockReq then continue end
			local oSize = getBlockSize(other)
			local oMaxY = other.offset.Y + oSize.Y / 2
			-- Is this block directly below? (its top touches our bottom, and overlaps on X/Z)
			if math.abs(oMaxY - myMinY) < TOLERANCE then
				local oMinX = other.offset.X - oSize.X / 2
				local oMaxX = other.offset.X + oSize.X / 2
				local oMinZ = other.offset.Z - oSize.Z / 2
				local oMaxZ = other.offset.Z + oSize.Z / 2
				if oMinX < myMaxX - TOLERANCE and myMinX < oMaxX - TOLERANCE
					and oMinZ < myMaxZ - TOLERANCE and myMinZ < oMaxZ - TOLERANCE then
					local oKey = self:_OffsetToKey(other.offset)
					if not self.FilledBlocks[oKey] then
						return false
					end
				end
			end
		end
		return true
	end

	local visible = {}

	-- Anchor block always visible
	local anchorKey = self:_OffsetToKey(Vector3.new(0, 0, 0))
	if offsetKeyToBlock[anchorKey] then
		visible[anchorKey] = true
	end

	-- Neighbors of filled blocks become visible, but only if supported from below
	for _, blockReq in ipairs(self.Definition.blocks) do
		local key = self:_OffsetToKey(blockReq.offset)
		if self.FilledBlocks[key] and neighborMap[key] then
			for neighborKey, _ in pairs(neighborMap[key]) do
				if hasSupport(neighborKey) then
					visible[neighborKey] = true
				end
			end
		end
	end

	return visible
end

-- Serialize blueprint data for persistence
function BaseBlueprint:Serialize(): BlueprintData
	return {
		id = self.Id,
		blueprintType = self.BlueprintType,
		relativePosition = {
			x = self.RelativePosition.X,
			y = self.RelativePosition.Y,
			z = self.RelativePosition.Z,
		},
		rotation = self.Rotation,
		ownerId = self.OwnerId,
		completedAt = self.CompletedAt,
		filledBlocks = self.FilledBlocks,
	}
end

-- Internal: Convert offset Vector3 to string key
function BaseBlueprint:_OffsetToKey(offset: Vector3): string
	return string.format("%d,%d,%d", offset.X, offset.Y, offset.Z)
end

-- Internal: Convert string key to offset Vector3
function BaseBlueprint:_KeyToOffset(key: string): Vector3
	local parts = string.split(key, ",")
	return Vector3.new(tonumber(parts[1]), tonumber(parts[2]), tonumber(parts[3]))
end

return BaseBlueprint
