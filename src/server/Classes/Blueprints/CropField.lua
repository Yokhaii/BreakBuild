local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ServerBaseBlueprint = require(script.Parent.BaseBlueprint)
local CropData = require(ReplicatedStorage.Shared.Data.CropData)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

-- Crop plots: every `plotBlockType` block of the definition is one plot (numbered in the
-- order of the blocks list). CropFieldService owns what is planted and calls SyncPlots;
-- this class shows the matching crop model on top of each plot of the completed field.
-- The completed model names its plot parts "<...>_Plot<index>" (details parented under them);
-- they and the crop models carry a "PlotIndex" attribute so the client can tell which plot
-- was clicked.
local CropField = {}
CropField.__index = CropField
setmetatable(CropField, { __index = ServerBaseBlueprint })

local function findModel(path: string): Instance?
	local current = ReplicatedStorage
	local parts = string.split(path, ".")
	for i = parts[1] == "ReplicatedStorage" and 2 or 1, #parts do
		current = current and current:FindFirstChild(parts[i])
	end
	return current
end

function CropField.new(data)
	local self = ServerBaseBlueprint.new(data)
	setmetatable(self, CropField)

	-- Offsets (from the anchor) of the top surface centre of each plot
	self.PlotTops = {}
	local plotBlockType = self.Definition and self.Definition.plotBlockType
	local blockConfig = plotBlockType and ItemData.GetItem(plotBlockType)
	local halfHeight = blockConfig and blockConfig.blockSize and blockConfig.blockSize.Y / 2 or 2
	for _, blockReq in ipairs(self.Definition and self.Definition.blocks or {}) do
		if blockReq.blockType == plotBlockType then
			table.insert(self.PlotTops, blockReq.offset + Vector3.new(0, halfHeight, 0))
		end
	end

	self._AnchorPosition = nil
	self._PlotVisuals = {} -- [plotIndex] = { key = "WheatSeeds:2", model = Model }

	return self
end

function CropField:GetPlotCount(): number
	return #self.PlotTops
end

function CropField:CreateCompletedModel(buildingAreaOrigin: Vector3, parentZone: Instance?): Model?
	local model = ServerBaseBlueprint.CreateCompletedModel(self, buildingAreaOrigin, parentZone)
	self._AnchorPosition = buildingAreaOrigin + self.RelativePosition
	self._PlotVisuals = {}

	if model then
		self:_TagPlotBlocks(model)
	end
	return model
end

-- Mark each plot part of the completed model ("CropField_Plot2" -> 2) with its PlotIndex
function CropField:_TagPlotBlocks(model: Model)
	for _, part in ipairs(model:GetDescendants()) do
		local plotIndex = part:IsA("BasePart") and tonumber(string.match(part.Name, "_Plot(%d+)$"))
		if plotIndex and plotIndex <= #self.PlotTops then
			part:SetAttribute("PlotIndex", plotIndex)
		end
	end
end

-- plots: { [tostring(plotIndex)] = { seed, plantedAt } } (CropFieldService storage)
-- Swaps a plot's model only when its crop or growth stage changed
function CropField:SyncPlots(plots, now: number)
	local model = self.CompletedModel
	if not model or not model.Parent or not self._AnchorPosition then return end

	for plotIndex, top in ipairs(self.PlotTops) do
		local plot = plots[tostring(plotIndex)]
		local crop = plot and CropData.GetBySeed(plot.seed)
		local stage = crop and CropData.GetStage(crop, now - plot.plantedAt)
		local key = crop and plot.seed .. ":" .. stage

		local visual = self._PlotVisuals[plotIndex]
		if visual and visual.key == key and visual.model.Parent then continue end

		if visual then
			visual.model:Destroy()
			self._PlotVisuals[plotIndex] = nil
		end

		if crop then
			local template = findModel(crop.stageModels[stage])
			if not template then
				warn("[CropField] Crop model not found:", crop.stageModels[stage])
				continue
			end

			local cropModel = template:Clone()
			cropModel.Name = "Crop_" .. plotIndex
			cropModel:SetAttribute("PlotIndex", plotIndex)
			cropModel:PivotTo(CFrame.new(self._AnchorPosition + top))
			cropModel.Parent = model
			self._PlotVisuals[plotIndex] = { key = key, model = cropModel }
		end
	end
end

return CropField
