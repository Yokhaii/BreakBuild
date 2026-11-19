local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local CropField = {}

local function getBlueprint(blueprintId)
	local ctrl = Knit.GetController("BlueprintPlacementController")
	return ctrl and ctrl:GetActiveBlueprint(blueprintId)
end

function CropField:Init()
	local CropFieldService = Knit.GetService("CropFieldService")

	-- Drive the plot labels (crop + time left) after planting, harvesting or loading
	CropFieldService.StateUpdated:Connect(function(blueprintId, state)
		local blueprint = getBlueprint(blueprintId)
		if blueprint and blueprint.SetCropState then
			blueprint:SetCropState(state)
		end
	end)
end

return CropField
