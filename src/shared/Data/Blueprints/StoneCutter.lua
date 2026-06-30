local StoneCutter = {
	id = "StoneCutter",
	name = "StoneCutter",
	displayName = "StoneCutter",
	description = "Description here.",

	-- Block requirements: offset is relative to anchor (PrimaryPart position)
	-- 2x2x2 blocks use odd offsets (mixed parity with 4x4x4 anchor)
	blocks = {
		{ offset = Vector3.new(0, 0, 0), blockType = "Stone" }, -- Anchor block (4x4x4)
		{ offset = Vector3.new(-1, 1, -3), blockType = "SprucePlank" }, -- front-left (2x2x2)
		{ offset = Vector3.new( 1, 1, -3), blockType = "SprucePlank" }, -- front-right
		{ offset = Vector3.new(-1, 1,  3), blockType = "SprucePlank" }, -- back-left
		{ offset = Vector3.new( 1, 1,  3), blockType = "SprucePlank" }, -- back-right
	},

	modelPath = "ReplicatedStorage.Assets.Blueprints.StoneCutter",
	completedModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.StoneCutter",
	completedItemName = "CompletedStoneCutter",
	clientClass = "StoneCutter",
	serverClass = "StoneCutter",
	maxQuantity = 1,
	requiredRebirth = 0,
}

return StoneCutter