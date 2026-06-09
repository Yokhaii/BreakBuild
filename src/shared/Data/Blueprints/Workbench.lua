--[[
	Workbench Blueprint Definition
	A sturdy workbench for crafting tools and items.

	Anchor: Bottom-left-front block (PrimaryPart of the model)
	All offsets are relative to the anchor position.
]]

local Workbench = {
	id = "Workbench",
	name = "Workbench",
	displayName = "Workbench",
	description = "Craft tools",
	size = Vector3.new(4, 4, 8),

	-- Block requirements: offset is relative to anchor (PrimaryPart position)
	-- SprucePlank is 2x2x2, so offsets use 2-stud spacing for ALL axes
	-- Workbench shape: full front/back walls with top-only middle section (table shape)
	blocks = {
		-- Z=0 level (front wall - full 2x2 grid)
		{ offset = Vector3.new(0, 0, 0), blockType = "SprucePlank" }, -- Anchor block
		{ offset = Vector3.new(2, 0, 0), blockType = "SprucePlank" },
		{ offset = Vector3.new(0, 2, 0), blockType = "SprucePlank" },
		{ offset = Vector3.new(2, 2, 0), blockType = "SprucePlank" },
		-- Z=2 level (middle - top row only, table surface)
		{ offset = Vector3.new(0, 2, 2), blockType = "SprucePlank" },
		{ offset = Vector3.new(2, 2, 2), blockType = "SprucePlank" },
		-- Z=4 level (middle - top row only, table surface)
		{ offset = Vector3.new(0, 2, 4), blockType = "SprucePlank" },
		{ offset = Vector3.new(2, 2, 4), blockType = "SprucePlank" },
		-- Z=6 level (back wall - full 2x2 grid)
		{ offset = Vector3.new(0, 0, 6), blockType = "SprucePlank" },
		{ offset = Vector3.new(2, 0, 6), blockType = "SprucePlank" },
		{ offset = Vector3.new(0, 2, 6), blockType = "SprucePlank" },
		{ offset = Vector3.new(2, 2, 6), blockType = "SprucePlank" },
	},

	modelPath = "ReplicatedStorage.Assets.Blueprints.Workbench",
	completedModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.Workbench",
	completedItemName = "CompletedWorkbench",
	clientClass = "Workbench",
	serverClass = "Workbench",
	maxQuantity = 1,
	requiredRebirth = 0,
}

return Workbench 
