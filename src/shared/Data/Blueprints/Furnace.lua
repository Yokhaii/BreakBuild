local Furnace = {
	id = "Furnace",
	name = "Furnace",
	displayName = "Furnace",
	description = "Description here.",

	-- Block requirements: offset is relative to anchor (PrimaryPart position)
	blocks = {
		{ offset = Vector3.new(0, 0, 0), blockType = "HalfStone" }, -- Anchor block
		{ offset = Vector3.new(0, 0, 2), blockType = "HalfStone" },
		{ offset = Vector3.new(0, 0, 4), blockType = "HalfStone" },
		{ offset = Vector3.new(0, 0, 6), blockType = "HalfStone" },
		{ offset = Vector3.new(2, 0, 0), blockType = "HalfStone" },
		{ offset = Vector3.new(2, 0, 6), blockType = "HalfStone" },
		{ offset = Vector3.new(4, 0, 0), blockType = "HalfStone" },
		{ offset = Vector3.new(4, 0, 2), blockType = "HalfStone" },
		{ offset = Vector3.new(4, 0, 4), blockType = "HalfStone" },
		{ offset = Vector3.new(4, 0, 6), blockType = "HalfStone" },
		{ offset = Vector3.new(0, 2, 0), blockType = "HalfStone" },
		{ offset = Vector3.new(0, 2, 6), blockType = "HalfStone" },
		{ offset = Vector3.new(2, 2, 0), blockType = "HalfStone" },
		{ offset = Vector3.new(2, 2, 6), blockType = "HalfStone" },
		{ offset = Vector3.new(4, 2, 0), blockType = "HalfStone" },
		{ offset = Vector3.new(4, 2, 2), blockType = "HalfStone" },
		{ offset = Vector3.new(4, 2, 4), blockType = "HalfStone" },
		{ offset = Vector3.new(4, 2, 6), blockType = "HalfStone" },
		{ offset = Vector3.new(0, 4, 2), blockType = "HalfStone" },
		{ offset = Vector3.new(0, 4, 4), blockType = "HalfStone" },
		{ offset = Vector3.new(2, 4, 2), blockType = "HalfStone" },
		{ offset = Vector3.new(2, 4, 4), blockType = "HalfStone" },
		{ offset = Vector3.new(4, 4, 2), blockType = "HalfStone" },
		{ offset = Vector3.new(4, 4, 4), blockType = "HalfStone" },
	},

	modelPath = "ReplicatedStorage.Assets.Blueprints.Furnace",
	completedModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.Furnace",
	completedItemName = "CompletedFurnace",
	clientClass = "Furnace",
	serverClass = "Furnace",
	maxQuantity = 1,
	requiredRebirth = 0,
}

return Furnace 