local BirdNest = {
	id = "BirdNest",
	name = "BirdNest",
	displayName = "Bird Nest",
	description = "Let a bird build its nest on top of it, the bird will fly around and bring back random items",

	-- Block requirements: offset is relative to anchor (PrimaryPart position)
	-- Mixed block sizes: 4x4x4 slots use even offsets, 2x2x2 slots use odd offsets
	blocks = {
		{ offset = Vector3.new(0, 0, 0), blockType = "Log" }, -- Anchor block (4x4x4)
		{ offset = Vector3.new(0, 4, 0), blockType = "Log" }, -- 4x4x4
		{ offset = Vector3.new(0, 8, 0), blockType = "Log" }, -- 4x4x4
		{ offset = Vector3.new(-3, 11, -1), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(-3, 11, 1), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(-1, 11, -3), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(-1, 11, -1), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(-1, 11, 1), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(-1, 11, 3), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(1, 11, -3), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(1, 11, -1), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(1, 11, 1), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(1, 11, 3), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(3, 11, -1), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(3, 11, 1), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(-3, 13, -1), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(-1, 13, 3), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(1, 13, -3), blockType = "SprucePlank" }, -- 2x2x2
		{ offset = Vector3.new(3, 13, 1), blockType = "SprucePlank" }, -- 2x2x2
	},

	modelPath = "ReplicatedStorage.Assets.Blueprints.BirdNest",
	completedModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.BirdNest",
	completedItemName = "CompletedBirdNest",
	clientClass = "BirdNest",
	serverClass = "BirdNest",
	maxQuantity = 1,
	requiredRebirth = 0,
	order = 999, -- position in the Blueprint menu

	-- Passive production (handled by PassiveBlueprintService)
	passive = {
		interval = 120, -- seconds between two trips of the bird
		maxStored = 10, -- trips waiting in the nest before the bird stops
		-- One entry is rolled per trip (weights are relative). min/max = quantity range (default 1)
		loot = {
			{ itemName = "Seed", weight = 70, min = 1, max = 3 },
			{ itemName = "StoneShard", weight = 12 },
			{ itemName = "IronOre", weight = 10 },
			{ itemName = "Coal", weight = 5 },
			{ itemName = "IronIngot", weight = 2 },
			{ itemName = "RawGold", weight = 1 },
		},
	},
}

return BirdNest
