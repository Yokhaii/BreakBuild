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

	-- Breaking System
	Breaking = {
		-- Array of spawned blocks in BreakingZone
		SpawnedBlocks = {
			-- Each block: {
			--   id: string,
			--   materialType: string (e.g., "Dirt", "Stone", "Sand"),
			--   gridX: number (0-15),
			--   gridZ: number (0-15),
			--   floor: number (1, 2, or 3)
			-- }
		},

		-- Next unique ID counter for blocks
		NextBlockId = 1,

		-- BreakingArea identifier for this player (defaults to UserId)
		BreakingAreaId = nil,

		-- Spawn interval in seconds (can be decreased by player upgrades)
		SpawnInterval = 5,
	},

	-- Tree System
	Tree = {
		-- Currently selected tree type
		SelectedTreeType = "Spruce",

		-- Tree state
		-- nil = no tree ever spawned
		-- "spawning" = tree is spawning (check SpawnedAt + spawnTime)
		-- "spawned" = tree is fully spawned and can be interacted with
		-- "respawning" = tree is respawning after being fully/partially broken
		State = nil,

		-- Timestamp when tree started spawning (os.time())
		SpawnStartedAt = 0,

		-- Timestamp when respawn started (os.time()), 0 if not respawning
		RespawnStartedAt = 0,

		-- Duration for current respawn (seconds), calculated based on full/partial break
		RespawnDuration = 0,

		-- Array of broken log names/indices
		-- Example: {"Log_1", "Log_3"} means Log_1 and Log_3 are broken
		BrokenLogs = {},

		-- Total number of logs in the current tree (set when tree spawns)
		TotalLogs = 0,
	},
}
