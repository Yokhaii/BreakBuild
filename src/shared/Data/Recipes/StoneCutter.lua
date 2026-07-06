return {
	HalfStone = {
		id = "HalfStone",
		displayName = "Half Stone",
		stationType = "StoneCutter",
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
		stationType = "StoneCutter",
		craftTime = 3,
		inputs = {
			{ itemName = "HalfStone", quantity = 4 },
			{ itemName = "Stone", quantity = 1 },
		},
		outputs = {
			{ itemName = "StoneShard", quantity = 1 },
		},
	},
}
