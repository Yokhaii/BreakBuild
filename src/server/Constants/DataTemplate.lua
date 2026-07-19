return {
	TemplateData = 1,

	-- Inventory System (Unified Hotbar)
	Inventory = {
		-- Hotbar: 7 slots for any non-Ore item (tools, blocks, blueprints, structures)
		Hotbar = {
			-- Each slot: {id: string, itemName: string, quantity: number} or nil
		},

		-- Backpack: Expandable array of items
		Backpack = {
			-- Array of items: {id: string, itemName: string, quantity: number}
		},

		-- Currently equipped slot (nil, 0 for Hammer, or 1-7)
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

	-- Crafting System
	Crafting = {
		-- In-progress craft saved across sessions.
		-- nil fields mean no craft was in progress when the player left.
		ActiveCraft = {
			-- blueprintId:  string  — which station owns the craft
			-- recipeId:     string
			-- quantity:     number
			-- startedAt:    number (os.time())
			-- duration:     number (total seconds, already scaled by quantity)
		},
	},

	-- Blueprint System
	Blueprints = {
		-- Set to true after the starter LogCutter has been placed once; never resets.
		HasReceivedLogCutter = false,

		-- Array of placed blueprints in BuildingArea
		PlacedBlueprints = {
			-- Each blueprint: {
			--   id: string,
			--   blueprintType: string (e.g., "Workbench", "Furnace"),
			--   relativePosition: {x: number, y: number, z: number}, -- Relative to BuildingArea origin
			--   rotation: number (0, 90, 180, 270 degrees),
			--   ownerId: number (player UserId),
			--   completedAt: number (os.time() when completed, or 0 if not completed),
			--   filledBlocks: {
			--     -- Keyed by offset string "x,y,z"
			--     ["0,0,0"] = { blockType = "SprucePlank", blockId = "abc123" },
			--   },
			-- }
		},

		-- Next unique ID counter for blueprints
		NextBlueprintId = 1,
	},

	-- Chest System
	Chest = {
		-- Items persisted across all chest placements: array of { id, itemName, quantity }
		Items = {},
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
