local Workbench = {
	id = "Workbench",
	name = "Workbench",
	displayName = "Workbench",
	description = "Description here.",

	-- Block requirements: offset is relative to anchor (PrimaryPart position)
	blocks = {
		{ offset = Vector3.new(0, 0, 0), blockType = "SprucePlank" }, -- Anchor block
		{ offset = Vector3.new(0, 0, 6), blockType = "SprucePlank" },
		{ offset = Vector3.new(2, 0, 0), blockType = "SprucePlank" },
		{ offset = Vector3.new(2, 0, 6), blockType = "SprucePlank" },
		{ offset = Vector3.new(0, 2, 0), blockType = "SprucePlank" },
		{ offset = Vector3.new(0, 2, 2), blockType = "SprucePlank" },
		{ offset = Vector3.new(0, 2, 4), blockType = "SprucePlank" },
		{ offset = Vector3.new(0, 2, 6), blockType = "SprucePlank" },
		{ offset = Vector3.new(2, 2, 0), blockType = "SprucePlank" },
		{ offset = Vector3.new(2, 2, 2), blockType = "SprucePlank" },
		{ offset = Vector3.new(2, 2, 4), blockType = "SprucePlank" },
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