return {
	IronIngot = {
		id = "IronIngot",
		displayName = "Iron Ingot",
		stationType = "Furnace",
		craftTime = 10,
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
		inputs = {
			{ itemName = "Dirt", quantity = 1 },
			{ fuelTier = 1, quantity = 1 },
		},
		outputs = {
			{ itemName = "Sand", quantity = 1 },
		},
	},
	Charcoal = {
		id = "Charcoal",
		displayName = "Charcoal",
		stationType = "Furnace",
		craftTime = 8,
		inputs = {
			{ itemName = "Log", quantity = 2 },
			{ fuelTier = 1, quantity = 2 },
		},
		outputs = {
			{ itemName = "Charcoal", quantity = 1 },
		},
	},
}
