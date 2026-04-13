--[=[
	BaseBlueprint - Shared Base Class
	Common blueprint functionality for both server and client
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BlueprintDefinitions = require(ReplicatedStorage.Shared.Data.Blueprints)

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
	if not self.Definition then
		print("[BaseBlueprint:IsComplete] No definition, returning false")
		return false
	end

	print("[BaseBlueprint:IsComplete] Checking completion for blueprint:", self.Id)
	print("[BaseBlueprint:IsComplete] Required blocks:", #self.Definition.blocks)

	-- Debug: print all filled blocks
	local filledCount = 0
	for key, data in pairs(self.FilledBlocks) do
		filledCount = filledCount + 1
		print("[BaseBlueprint:IsComplete] Filled block at key:", key, "type:", data.blockType)
	end
	print("[BaseBlueprint:IsComplete] Total filled blocks:", filledCount)

	for i, blockReq in ipairs(self.Definition.blocks) do
		local offsetKey = self:_OffsetToKey(blockReq.offset)
		local filledBlock = self.FilledBlocks[offsetKey]

		print("[BaseBlueprint:IsComplete] Checking block", i, "- offset:", blockReq.offset, "key:", offsetKey, "required:", blockReq.blockType)

		if not filledBlock then
			print("[BaseBlueprint:IsComplete] MISSING block at key:", offsetKey)
			return false -- Missing block
		end

		if filledBlock.blockType ~= blockReq.blockType then
			print("[BaseBlueprint:IsComplete] WRONG TYPE at key:", offsetKey, "- got:", filledBlock.blockType, "expected:", blockReq.blockType)
			return false -- Wrong block type
		end

		print("[BaseBlueprint:IsComplete] Block", i, "OK - key:", offsetKey)
	end

	print("[BaseBlueprint:IsComplete] *** BLUEPRINT IS COMPLETE! ***")
	return true
end

-- Get the required block type at a specific offset
function BaseBlueprint:GetRequiredBlockAt(offset: Vector3): string?
	if not self.Definition then
		print("[BaseBlueprint:GetRequiredBlockAt] No definition!")
		return nil
	end

	-- Apply rotation to offset
	local rotatedOffset = self:_RotateOffset(offset)
	print("[BaseBlueprint:GetRequiredBlockAt] Looking for block at offset:", offset, "rotated:", rotatedOffset)

	for i, blockReq in ipairs(self.Definition.blocks) do
		print("[BaseBlueprint:GetRequiredBlockAt] Checking block", i, "offset:", blockReq.offset, "type:", blockReq.blockType)
		if blockReq.offset == rotatedOffset then
			print("[BaseBlueprint:GetRequiredBlockAt] FOUND! Required type:", blockReq.blockType)
			return blockReq.blockType
		end
	end

	print("[BaseBlueprint:GetRequiredBlockAt] No block required at this offset")
	return nil
end

-- Check if a position is within blueprint bounds
function BaseBlueprint:IsPositionInBounds(offset: Vector3): boolean
	if not self.Definition then return false end

	local size = self.Definition.size
	return offset.X >= 0 and offset.X < size.X and
	       offset.Y >= 0 and offset.Y < size.Y and
	       offset.Z >= 0 and offset.Z < size.Z
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

-- Internal: Rotate offset based on blueprint rotation
function BaseBlueprint:_RotateOffset(offset: Vector3): Vector3
	if not self.Definition then return offset end

	local size = self.Definition.size
	local rotation = self.Rotation

	if rotation == 0 then
		return offset
	elseif rotation == 90 then
		return Vector3.new(size.Z - 1 - offset.Z, offset.Y, offset.X)
	elseif rotation == 180 then
		return Vector3.new(size.X - 1 - offset.X, offset.Y, size.Z - 1 - offset.Z)
	elseif rotation == 270 then
		return Vector3.new(offset.Z, offset.Y, size.X - 1 - offset.X)
	end

	return offset
end

return BaseBlueprint
