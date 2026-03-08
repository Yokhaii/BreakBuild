--[[
	TreeData.lua
	Configuration for all tree types in the game
	Including spawn times, respawn logic, and breakable parts
]]

local TreeData = {}

-- Tree type configurations
TreeData.Trees = {
	Spruce = {
		displayName = "Spruce Tree",
		modelPath = "ReplicatedStorage.Assets.Tree.Spruce",
		spawnTime = 10, -- Seconds to spawn
		respawnMultiplier = 10, -- Partial break respawn = spawnTime * this
		breakablePartName = "Log", -- Parts with this name can be broken
		dropItem = "Log", -- Item dropped when breaking a log
		breakTime = 1.5, -- Base time to break a log
		requiredTier = "Wood", -- Minimum tool tier required
		materialType = "Log", -- Material type for breaking system (determines tool tier check)
	},
	-- Add more tree types here
	-- Oak = {
	-- 	displayName = "Oak Tree",
	-- 	modelPath = "ReplicatedStorage.Assets.Tree.Oak",
	-- 	spawnTime = 15,
	-- 	respawnMultiplier = 10,
	-- 	breakablePartName = "Log",
	-- 	dropItem = "Log",
	-- 	breakTime = 2.0,
	-- 	requiredTier = "Wood",
	-- },
}

-- Default tree type
TreeData.DefaultTreeType = "Spruce"

-- Tool tier hierarchy (same as MaterialData)
TreeData.ToolTierOrder = {
	Hand = 0,
	Wood = 1,
	Stone = 2,
	Iron = 3,
	Gold = 4,
	Diamond = 5,
}

-- Get tree config by type
function TreeData.GetTree(treeType: string)
	return TreeData.Trees[treeType]
end

-- Get all available tree types
function TreeData.GetAvailableTreeTypes(): {string}
	local types = {}
	for treeType, _ in pairs(TreeData.Trees) do
		table.insert(types, treeType)
	end
	return types
end

-- Check if tool can break tree logs
function TreeData.CanToolBreak(toolTier: string, treeType: string): boolean
	local treeConfig = TreeData.Trees[treeType]
	if not treeConfig then return false end

	local toolLevel = TreeData.ToolTierOrder[toolTier] or 0
	local requiredLevel = TreeData.ToolTierOrder[treeConfig.requiredTier] or 0

	return toolLevel >= requiredLevel
end

-- Get break time for a tree log with tool speed applied
function TreeData.GetBreakTime(treeType: string, toolBreakSpeed: number): number
	local treeConfig = TreeData.Trees[treeType]
	if not treeConfig then return 2.0 end

	local baseTime = treeConfig.breakTime or 2.0
	return baseTime / (toolBreakSpeed or 1.0)
end

return TreeData
