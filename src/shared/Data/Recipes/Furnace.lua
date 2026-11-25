return {
	Charcoal = {
		id = "Charcoal",
		displayName = "Charcoal",
		stationType = "Furnace",
		craftTime = 8,
		order = 1,
		inputs = {
			{ itemName = "Log", quantity = 2 },
			{ fuelTier = 1, quantity = 2 },
		},
		outputs = {
			{ itemName = "Charcoal", quantity = 1 },
		},
	},

	IronIngot = {
		id = "IronIngot",
		displayName = "Iron Ingot",
		stationType = "Furnace",
		craftTime = 10,
		order = 2,
		inputs = {
			{ itemName = "IronOre", quantity = 4 },
			{ fuelTier = 1, quantity = 4 },
		},
		outputs = {
			{ itemName = "IronIngot", quantity = 1 },
		},
	},
	Sand = {
		id = "Sand",
		displayName = "Sand",
		stationType = "Furnace",
		craftTime = 4,
		order = 3,
		inputs = {
			{ itemName = "Dirt", quantity = 1 },
			{ fuelTier = 1, quantity = 1 },
		},
		outputs = {
			{ itemName = "Sand", quantity = 1 },
		},
	},
	SteelIngot = {
		id = "SteelIngot",
		displayName = "Steel Ingot",
		stationType = "Furnace",
		craftTime = 15,
		order = 4,
		inputs = {
			{ itemName = "IronIngot", quantity = 2 },
			{ fuelTier = 2, quantity = 4 },
		},
		outputs = {
			{ itemName = "SteelIngot", quantity = 1 },
		},
	},
	GoldIngot = {
		id = "GoldIngot",
		displayName = "Gold Ingot",
		stationType = "Furnace",
		craftTime = 15,
		order = 5,
		inputs = {
			{ itemName = "RawGold", quantity = 4 },
			{ fuelTier = 2, quantity = 4 },
		},
		outputs = {
			{ itemName = "GoldIngot", quantity = 1 },
		},
	},
}
