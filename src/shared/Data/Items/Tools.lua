-- Tools.lua
-- Item data for tool-type items

--[[
	Breaking Tool Properties:
	- isBreakingTool: boolean - whether this tool can break blocks
	- breakSpeed: number - multiplier for breaking speed (1 = normal, 2 = twice as fast)
	- toolTier: string - determines which materials this tool can break
	  Tiers: "Wood" < "Stone" < "Iron" < "Gold" < "Diamond"
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
		description = "A hammer for removing placed blocks",
		modelPath = "Assets.Items.Hammer",
		isRemovalTool = true,
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
		breakSpeed = 30,
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
		-- Breaking properties
		isBreakingTool = true,
		breakSpeed = 2.0,
		toolTier = "Iron",
	},
}

return Tools
