return {
	TemplateData = 1,

	-- Inventory System
	Inventory = {
		-- Hotbar: 10 slots, numbered 1-10
		Hotbar = {
			-- Each slot: {id: string, itemName: string, quantity: number} or nil
			-- Example: [1] = {id = "abc123", itemName = "Dirt", quantity = 5}
		},

		-- Backpack: Expandable array of items
		Backpack = {
			-- Array of items: {id: string, itemName: string, quantity: number}
			-- Example: {id = "def456", itemName = "Stone", quantity = 10}
		},

		-- Currently equipped slot (1-10, or nil if nothing equipped)
		EquippedSlot = nil,

		-- Next unique ID counter for items
		NextItemId = 1,
	},

	-- Building System
	Building = {
		-- Array of placed blocks
		PlacedBlocks = {
			-- Each block: {
			--   id: string,
			--   itemName: string,
			--   relativePosition: {x: number, y: number, z: number}, -- Relative to BuildingArea origin
			--   size: {x: number, y: number, z: number},
			--   buildingAreaId: string -- Player's BuildingArea identifier (UserId)
			-- }
		},

		-- Next unique ID counter for blocks
		NextBlockId = 1,

		-- BuildingArea identifier for this player (defaults to UserId)
		BuildingAreaId = nil,
	},
}
