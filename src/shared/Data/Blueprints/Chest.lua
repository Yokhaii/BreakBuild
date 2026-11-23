local Chest = {
	id = "Chest",
	name = "Chest",
	displayName = "Chest",
	description = "Store the items you don't want to carry around. Open it to move items between your backpack and the chest, tools keep their durability. Everything inside stays safe, even when you pick the chest up and place it somewhere else.",

	-- Block requirements: offset is relative to anchor (PrimaryPart position)
	-- Mixed block sizes: 4x4x4 slots use even offsets, 2x2x2 slots use odd offsets
	blocks = {
		{ offset = Vector3.new(0, 0, 0), blockType = "SprucePlank" }, -- Anchor block (2x2x2)
		{ offset = Vector3.new(0, 0, 2), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, 4), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, 6), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(2, 0, 0), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(2, 0, 6), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 0, 0), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 0, 2), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 0, 4), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 0, 6), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 2, 0), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 2, 2), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 2, 4), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 2, 6), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(2, 2, 0), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(2, 2, 6), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 2, 0), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 2, 2), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 2, 4), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 2, 6), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(2, 4, 2), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(2, 4, 4), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 4, 2), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 4, 4), blockType = "SprucePlank" }, -- 2x2x2
	},
	modelPath = "ReplicatedStorage.Assets.Blueprints.Chest",
	completedModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.Chest",
	completedItemName = "CompletedChest",
	clientClass = "Chest",
	serverClass = "Chest",
	maxQuantity = 1,
	requiredRebirth = 0,
	order = 3,
}

return Chest
