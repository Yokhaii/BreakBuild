--[=[
	Blueprint Definitions
	Central module that combines all blueprint definitions

	IMPORTANT: Block offset system
	- The PrimaryPart of the model in ReplicatedStorage is the ANCHOR point
	- The anchor should be on the ground, at the left-front corner when facing the blueprint
	- All block offsets are RELATIVE to the anchor's position
	- Offset (0,0,0) means the block is at the same position as the anchor
	- Each block is 4x4x4 studs, so offsets should be multiples of 4

	Example for a 2x1x2 blueprint (viewed from above, anchor marked as [A]):

	      Z+
	      ↑
	  +---+---+
	  |   |   |
	  +---+---+
	  |[A]|   |  → X+
	  +---+---+

	  Anchor at (0,0,0), other blocks at (4,0,0), (0,0,4), (4,0,4)

	To add a new blueprint:
	1. Create a new file: Blueprints/YourBlueprint.lua
	2. Require it below and add to Definitions table
]=]

-- Individual blueprint definitions
local Workbench = require(script.Workbench)
local Furnace = require(script.Furnace)

local Blueprints = {}

-- Combine all blueprint definitions
Blueprints.Definitions = {
	Workbench = Workbench,
	Furnace = Furnace,
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

	return offset.X >= 0 and offset.X < definition.size.X and
	       offset.Y >= 0 and offset.Y < definition.size.Y and
	       offset.Z >= 0 and offset.Z < definition.size.Z
end

-- Get total number of blocks required for a blueprint
function Blueprints.GetTotalBlockCount(blueprintId: string): number
	local definition = Blueprints.GetDefinition(blueprintId)
	if not definition then return 0 end
	return #definition.blocks
end

return Blueprints
