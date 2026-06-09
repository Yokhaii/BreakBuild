--[[
	Furnace Blueprint Definition
	Smelt ores and cook food with this blazing furnace.

	Anchor: Bottom block (PrimaryPart of the model)
	All offsets are relative to the anchor position.
]]

local Furnace = {
	id = "furnace",
	name = "Furnace",
	displayName = "Furnace",
	description = "Smelt ores and cook food with this blazing furnace.",
	size = Vector3.new(4, 8, 4), -- Total size: 1x2x1 blocks

	-- Block requirements: offset is relative to anchor (PrimaryPart position)
	blocks = {
		{ offset = Vector3.new(0, 0, 0), blockType = "Stone" }, -- Anchor block (bottom)
		{ offset = Vector3.new(0, 4, 0), blockType = "Stone" }, -- Above anchor
	},

	-- Model in ReplicatedStorage with PrimaryPart set as anchor
	modelPath = "ReplicatedStorage.Assets.Blueprints.Furnace",
	completedModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.Furnace",
	completedItemName = "CompletedFurnace",
	clientClass = "Furnace",
	serverClass = "Furnace",
	maxQuantity = 1,
	requiredRebirth = 1,
}

return Furnace
