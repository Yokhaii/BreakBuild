--[=[
	CropData
	Crops grown on the CropField, keyed by the seed item that plants them.

	- growTime: seconds from planting to ripe (offline time counts)
	- stageModels: ReplicatedStorage paths, shown in order while the crop grows.
	  The last one is the ripe crop. Each model's PrimaryPart sits on the plot's top surface
	- harvest: items given when a ripe crop is harvested
]=]

local CropData = {}

CropData.Crops = {
	WheatSeeds = {
		cropName = "Wheat",
		growTime = 60,
		stageModels = {
			"ReplicatedStorage.Assets.Crops.WheatStage1",
			"ReplicatedStorage.Assets.Crops.WheatStage2",
			"ReplicatedStorage.Assets.Crops.WheatStage3",
		},
		harvest = {
			{ itemName = "Wheat", quantity = 1 },
			{ itemName = "WheatSeeds", quantity = 1 },
		},
	},

	CarrotSeeds = {
		cropName = "Carrot",
		growTime = 120,
		stageModels = {
			"ReplicatedStorage.Assets.Crops.CarrotStage1",
			"ReplicatedStorage.Assets.Crops.CarrotStage2",
			"ReplicatedStorage.Assets.Crops.CarrotStage3",
		},
		harvest = {
			{ itemName = "Carrot", quantity = 1 },
			{ itemName = "CarrotSeeds", quantity = 1 },
		},
	},

	MelonSeeds = {
		cropName = "Melon",
		growTime = 240,
		stageModels = {
			"ReplicatedStorage.Assets.Crops.MelonStage1",
			"ReplicatedStorage.Assets.Crops.MelonStage2",
			"ReplicatedStorage.Assets.Crops.MelonStage3",
		},
		harvest = {
			{ itemName = "Melon", quantity = 1 },
			{ itemName = "MelonSeeds", quantity = 1 },
		},
	},
}

-- Crop planted by a seed item, or nil if the item is not a seed
function CropData.GetBySeed(seedItemName: string)
	return CropData.Crops[seedItemName]
end

-- Growth stage index (1..#stageModels) after `elapsed` seconds. The last stage means ripe
function CropData.GetStage(crop, elapsed: number): number
	local stageCount = #crop.stageModels
	if elapsed >= crop.growTime then
		return stageCount
	end
	-- The growing stages share the grow time evenly
	return math.clamp(math.floor(elapsed / crop.growTime * (stageCount - 1)) + 1, 1, stageCount - 1)
end

return CropData
