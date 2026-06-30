--[=[
	Blueprint Definitions
	Central module that combines all blueprint definitions

	Block offset system:
	- The PrimaryPart of the model in ReplicatedStorage is the ANCHOR point
	- The anchor can be ANY block in the blueprint (not necessarily a corner)
	- All block offsets are RELATIVE to the anchor's position
	- Offset (0,0,0) means the block is at the same position as the anchor
	- Offsets can be negative (blocks behind/below/left of anchor)

	To add a new blueprint:
	1. Create a new file: Blueprints/YourBlueprint.lua
	2. Require it below and add to Definitions table
]=]

-- Individual blueprint definitions
local Workbench = require(script.Workbench)
local Furnace = require(script.Furnace)
local StoneCutter = require(script.StoneCutter)

local Blueprints = {}

-- Combine all blueprint definitions
Blueprints.Definitions = {
	Workbench = Workbench,
	Furnace = Furnace,
	StoneCutter = StoneCutter,
}

-- Get blueprint definition by ID or name (flexible lookup)
function Blueprints.GetDefinition(blueprintIdOrName: string)
	-- First try direct key lookup (e.g., "Workbench")
	if Blueprints.Definitions[blueprintIdOrName] then
		return Blueprints.Definitions[blueprintIdOrName]
	end

	-- Then try matching by id field (e.g., "workbench")
	for _, definition in pairs(Blueprints.Definitions) do
		if definition.id == blueprintIdOrName then
			return definition
		end
	end

	return nil
end

-- Alias for backwards compatibility
function Blueprints.GetDefinitionByName(blueprintName: string)
	return Blueprints.GetDefinition(blueprintName)
end

-- Get all blueprint definitions
function Blueprints.GetAllDefinitions()
	return Blueprints.Definitions
end

-- Compute the min and max offsets from a blueprint definition's blocks array
function Blueprints.GetBounds(definition)
	if not definition or not definition.blocks or #definition.blocks == 0 then
		return Vector3.new(0, 0, 0), Vector3.new(0, 0, 0)
	end

	local minX, minY, minZ = math.huge, math.huge, math.huge
	local maxX, maxY, maxZ = -math.huge, -math.huge, -math.huge

	for _, blockReq in ipairs(definition.blocks) do
		local o = blockReq.offset
		minX = math.min(minX, o.X)
		minY = math.min(minY, o.Y)
		minZ = math.min(minZ, o.Z)
		maxX = math.max(maxX, o.X)
		maxY = math.max(maxY, o.Y)
		maxZ = math.max(maxZ, o.Z)
	end

	return Vector3.new(minX, minY, minZ), Vector3.new(maxX, maxY, maxZ)
end

-- Check if a block type is valid for a specific offset in a blueprint
function Blueprints.GetRequiredBlockAt(blueprintId: string, offset: Vector3): string?
	local definition = Blueprints.GetDefinition(blueprintId)
	if not definition then return nil end

	for _, blockReq in ipairs(definition.blocks) do
		if blockReq.offset == offset then
			return blockReq.blockType
		end
	end
	return nil
end

-- Check if an offset is within the blueprint bounds
function Blueprints.IsOffsetInBounds(blueprintId: string, offset: Vector3): boolean
	local definition = Blueprints.GetDefinition(blueprintId)
	if not definition then return false end

	local minOffset, maxOffset = Blueprints.GetBounds(definition)
	return offset.X >= minOffset.X and offset.X <= maxOffset.X and
	       offset.Y >= minOffset.Y and offset.Y <= maxOffset.Y and
	       offset.Z >= minOffset.Z and offset.Z <= maxOffset.Z
end

-- Get total number of blocks required for a blueprint
function Blueprints.GetTotalBlockCount(blueprintId: string): number
	local definition = Blueprints.GetDefinition(blueprintId)
	if not definition then return 0 end
	return #definition.blocks
end

return Blueprints
