-- Tools.lua
-- Item data for tool-type items

--[[
	Breaking Tool Properties:
	- isBreakingTool: boolean - whether this tool can break blocks
	- breakSpeed: number - multiplier for breaking speed (1 = normal, 2 = twice as fast)
	- toolTier: string - determines which materials this tool can break
	  Tiers: "Wood" < "Stone" < "Iron" < "Steel" < "Gold" < "Diamond"
	  A tool can break materials of its tier or lower
]]

local Tools = {
	Hammer = {
		name = "Hammer",
		displayName = "Hammer",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = false,
		description = "A hammer for removing placed blocks and structures",
		modelPath = "Assets.Items.Hammer",
		isRemovalTool = true,
		-- Breaking properties for structures
		isBreakingTool = true,
		breakSpeed = 1.0,
		toolTier = "Wood",
	},
	DevPickaxe = {
		name = "DevPickaxe",
		displayName = "DEv Pickaxe",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "I'm fast as f*** boy",
		modelPath = "Assets.Items.DevPickaxe",
		-- Breaking properties
		isBreakingTool = true,
		breakSpeed = 50,
		toolTier = "Wood",
		-- For testing: bypass tier check and break anything
		canBreakAll = true,
	},

	WoodenPickaxe = {
		name = "WoodenPickaxe",
		displayName = "Wooden Pickaxe",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A basic wooden pickaxe for mining",
		modelPath = "Assets.Items.WoodenPickaxe",
		-- Breaking properties
		isBreakingTool = true,
		breakSpeed = 1,
		toolTier = "Wood",
		-- For testing: bypass tier check and break anything
		canBreakAll = true,
	},

	StonePickaxe = {
		name = "StonePickaxe",
		displayName = "Stone Pickaxe",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A stone pickaxe for mining harder materials",
		modelPath = "Assets.Items.StonePickaxe",
		-- Breaking properties
		isBreakingTool = true,
		breakSpeed = 1.5,
		toolTier = "Stone",
	},

	IronPickaxe = {
		name = "IronPickaxe",
		displayName = "Iron Pickaxe",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "An iron pickaxe for mining rare materials",
		modelPath = "Assets.Items.IronPickaxe",
		isBreakingTool = true,
		breakSpeed = 2.0,
		toolTier = "Iron",
	},

	SteelPickaxe = {
		name = "SteelPickaxe",
		displayName = "Steel Pickaxe",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A steel pickaxe for mining the toughest materials",
		modelPath = "Assets.Items.SteelPickaxe",
		isBreakingTool = true,
		breakSpeed = 2.5,
		toolTier = "Steel",
	},

	-- Axes
	WoodenAxe = {
		name = "WoodenAxe",
		displayName = "Wooden Axe",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A basic wooden axe for chopping",
		modelPath = "Assets.Items.WoodenAxe",
		isBreakingTool = true,
		breakSpeed = 1.0,
		toolTier = "Wood",
	},

	StoneAxe = {
		name = "StoneAxe",
		displayName = "Stone Axe",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A stone axe for chopping harder materials",
		modelPath = "Assets.Items.StoneAxe",
		isBreakingTool = true,
		breakSpeed = 1.5,
		toolTier = "Stone",
	},

	IronAxe = {
		name = "IronAxe",
		displayName = "Iron Axe",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "An iron axe for chopping tough materials",
		modelPath = "Assets.Items.IronAxe",
		isBreakingTool = true,
		breakSpeed = 2.0,
		toolTier = "Iron",
	},

	SteelAxe = {
		name = "SteelAxe",
		displayName = "Steel Axe",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A steel axe for chopping the toughest materials",
		modelPath = "Assets.Items.SteelAxe",
		isBreakingTool = true,
		breakSpeed = 2.5,
		toolTier = "Steel",
	},

	-- Shovels
	WoodenShovel = {
		name = "WoodenShovel",
		displayName = "Wooden Shovel",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A basic wooden shovel for digging",
		modelPath = "Assets.Items.WoodenShovel",
		isBreakingTool = true,
		breakSpeed = 1.0,
		toolTier = "Wood",
	},

	StoneShovel = {
		name = "StoneShovel",
		displayName = "Stone Shovel",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A stone shovel for digging faster",
		modelPath = "Assets.Items.StoneShovel",
		isBreakingTool = true,
		breakSpeed = 1.5,
		toolTier = "Stone",
	},

	IronShovel = {
		name = "IronShovel",
		displayName = "Iron Shovel",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "An iron shovel for digging through tough ground",
		modelPath = "Assets.Items.IronShovel",
		isBreakingTool = true,
		breakSpeed = 2.0,
		toolTier = "Iron",
	},

	SteelShovel = {
		name = "SteelShovel",
		displayName = "Steel Shovel",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A steel shovel for digging through the toughest ground",
		modelPath = "Assets.Items.SteelShovel",
		isBreakingTool = true,
		breakSpeed = 2.5,
		toolTier = "Steel",
	},

	-- Swords (combat tools)
	WoodenSword = {
		name = "WoodenSword",
		displayName = "Wooden Sword",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A basic wooden sword for combat",
		modelPath = "Assets.Items.WoodenSword",
		isCombatTool = true,
		damage = 4,
		attackSpeed = 1.0,
		toolTier = "Wood",
	},

	StoneSword = {
		name = "StoneSword",
		displayName = "Stone Sword",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A stone sword with improved damage",
		modelPath = "Assets.Items.StoneSword",
		isCombatTool = true,
		damage = 6,
		attackSpeed = 1.0,
		toolTier = "Stone",
	},

	IronSword = {
		name = "IronSword",
		displayName = "Iron Sword",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "An iron sword with high damage",
		modelPath = "Assets.Items.IronSword",
		isCombatTool = true,
		damage = 8,
		attackSpeed = 1.0,
		toolTier = "Iron",
	},
	SteelSword = {
		name = "SteelSword",
		displayName = "Steel Sword",
		type = "Tool",
		stackable = false,
		maxStack = 1,
		dropable = true,
		description = "A steel sword with devastating damage",
		modelPath = "Assets.Items.SteelSword",
		isCombatTool = true,
		damage = 10,
		attackSpeed = 1.0,
		toolTier = "Steel",
	},
}

return Tools
