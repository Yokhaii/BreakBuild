local LogCutter = {
	id = "LogCutter",
	name = "LogCutter",
	displayName = "Log Cutter",
	description = "Cuts logs into planks. 1 log = 4 planks.",

	-- No blocks to fill; this blueprint is always pre-completed.
	blocks = {},

	modelPath = "ReplicatedStorage.Assets.CompletedBlueprints.LogCutter",
	completedModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.LogCutter",
	completedItemName = "CompletedLogCutter",
	clientClass = "LogCutter",
	serverClass = "LogCutter",
	maxQuantity = 1,
	requiredRebirth = 0,
}

return LogCutter
