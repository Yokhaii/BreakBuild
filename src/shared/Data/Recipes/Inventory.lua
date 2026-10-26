return {
	SprucePlank = {
		id = "SprucePlank",
		displayName = "Spruce Plank",
		stationType = "Inventory",
		craftTime = 2,
		inputs = {
			{ itemName = "Log", quantity = 1 },
		},
		outputs = {
			{ itemName = "SprucePlank", quantity = 4 },
		},
	},
	HalfStone = {
		id = "HalfStone",
		displayName = "Half Stone",
		stationType = "Inventory",
		craftTime = 3,
		inputs = {
			{ itemName = "Stone", quantity = 1 },
		},
		outputs = {
			{ itemName = "HalfStone", quantity = 4 },
		},
	},
	StoneShard = {
		id = "StoneShard",
		displayName = "Stone Shard",
		stationType = "Inventory",
		craftTime = 3,
		inputs = {
			{ itemName = "HalfStone", quantity = 4 },
		},
		outputs = {
			{ itemName = "StoneShard", quantity = 1 },
		},
	},
}
