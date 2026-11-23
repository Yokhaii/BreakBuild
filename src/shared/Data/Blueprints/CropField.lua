local CropField = {
	id = "CropField",
	name = "CropField",
	displayName = "Crop Field",
	description = "Grow your own crops on its 4 dirt plots. Hold seeds and click an empty plot to plant them, then click the field to harvest everything that is ripe. Wheat, carrots and melons each take a different time to grow, and they keep growing while you are away. Every harvest gives you the crop and its seed back. Seeds are found by the bird of the Bird Nest.",

	-- Block requirements: offset is relative to anchor (PrimaryPart position)
	-- Mixed block sizes: 4x4x4 slots use even offsets, 2x2x2 slots use odd offsets
	blocks = {
		{ offset = Vector3.new(0, 0, -18), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, -16), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, -14), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, -12), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, -10), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, -8), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, -6), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, -4), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, -2), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 0, 0), blockType = "SprucePlank" }, -- Anchor block (2x2x2)
		{ offset = Vector3.new(2, 0, -18), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(2, 0, 0), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 0, -18), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(4, 0, 0), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 0, -18), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 0, -16), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 0, -14), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 0, -12), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 0, -10), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 0, -8), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 0, -6), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 0, -4), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 0, -2), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 0, 0), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(3, 1, -15), blockType = "Dirt" }, -- 4x4x4
		{ offset = Vector3.new(3, 1, -11), blockType = "Dirt" }, -- 4x4x4
		{ offset = Vector3.new(3, 1, -7), blockType = "Dirt" }, -- 4x4x4
		{ offset = Vector3.new(3, 1, -3), blockType = "Dirt" }, -- 4x4x4
		{ offset = Vector3.new(0, 2, -18), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(0, 2, 0), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 2, -18), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(6, 2, 0), blockType = "SprucePlank" }, -- 2x2x2
	},

	modelPath = "ReplicatedStorage.Assets.Blueprints.CropField",
	completedModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.CropField",
	completedItemName = "CompletedCropField",
	clientClass = "CropField",
	serverClass = "CropField",
	maxQuantity = 1,
	requiredRebirth = 0,
	order = 999, -- position in the Blueprint menu

	-- Crop plots (handled by CropFieldService): every block of this type is one plot,
	-- numbered in the order of the blocks list. Crops grow on the plot's top surface
	plotBlockType = "Dirt",
}

return CropField