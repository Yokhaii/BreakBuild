local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local Workspace = game:GetService("Workspace")

local Knit = require(ReplicatedStorage.Packages.Knit)
local CropData = require(ReplicatedStorage.Shared.Data.CropData)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)

local ClientBaseBlueprint = require(script.Parent.BaseBlueprint)

-- Crop field: click (or tap) an empty plot while holding seeds to plant one there
-- (CropFieldService:Plant); any other click harvests every ripe crop (CropFieldService:Harvest).
-- While holding seeds only the plot under the cursor is highlighted, otherwise the whole field.
-- Each planted plot shows the crop name and its time left above it.
local CropField = {}
CropField.__index = CropField
setmetatable(CropField, { __index = ClientBaseBlueprint })

local REFRESH_INTERVAL = 0.25
local ERROR_COLOR = Color3.fromRGB(255, 80, 80)
local HARVEST_COLOR = Color3.fromRGB(140, 220, 120)

local LABEL_SIZE = UDim2.fromScale(4, 0.8)
local LABEL_OFFSET = Vector3.new(0, 5, 0) -- above the plot block centre, clear of the tallest crop
local LABEL_MAX_DIST = 60
local LABEL_FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local LABEL_COLOR = Color3.fromRGB(255, 255, 255)
local READY_COLOR = Color3.fromRGB(140, 230, 110)
local LABEL_STROKE_COLOR = Color3.fromRGB(30, 30, 30)
local LABEL_STROKE_THICKNESS = 1.5

local function formatTime(secs: number): string
	secs = math.ceil(secs)
	local mins = math.floor(secs / 60)
	local displaySecs = secs % 60
	return mins > 0 and string.format("%d:%02d", mins, displaySecs) or string.format("%ds", displaySecs)
end

local function buildPlotLabel(adornee: BasePart)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "CropPlotLabel"
	billboard.Size = LABEL_SIZE
	billboard.StudsOffsetWorldSpace = LABEL_OFFSET
	billboard.LightInfluence = 0
	billboard.MaxDistance = LABEL_MAX_DIST
	billboard.Adornee = adornee
	billboard.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.FontFace = LABEL_FONT
	label.TextScaled = true
	label.TextColor3 = LABEL_COLOR
	label.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Color = LABEL_STROKE_COLOR
	stroke.Thickness = LABEL_STROKE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label

	return billboard, label
end

function CropField.new(data)
	local self = ClientBaseBlueprint.new(data)
	setmetatable(self, CropField)
	self._Plots = {} -- [plotIndex] = { seed, readyAt (os.clock()) }
	self._PlotLabels = {} -- [plotIndex] = { billboard, label }
	self._RefreshThread = nil
	return self
end

function CropField:SetModel(model: Model)
	ClientBaseBlueprint.SetModel(self, model)

	Knit.GetService("CropFieldService"):GetState(self.Id):andThen(function(state)
		if state then
			self:SetCropState(state)
		end
	end)
end

-- state: { plots = { [tostring(plotIndex)] = { seed, secsRemaining } } } (CropFieldService)
function CropField:SetCropState(state)
	local now = os.clock()
	self._Plots = {}
	for key, plot in pairs(state.plots) do
		self._Plots[tonumber(key)] = { seed = plot.seed, readyAt = now + plot.secsRemaining }
	end
	self:_RefreshLabels()

	if not self._RefreshThread then
		self._RefreshThread = task.spawn(function()
			while not self._Destroyed do
				task.wait(REFRESH_INTERVAL)
				self:_RefreshLabels()
			end
		end)
	end
end

-- The plot blocks of the completed model, by PlotIndex (set by the server class)
function CropField:_GetPlotParts(): { [number]: BasePart }
	local parts = {}
	local model = self:_GetCompletedModel()
	if not model then return parts end
	for _, descendant in ipairs(model:GetDescendants()) do
		local plotIndex = descendant:IsA("BasePart") and descendant:GetAttribute("PlotIndex")
		if plotIndex then
			parts[plotIndex] = descendant
		end
	end
	return parts
end

function CropField:_RefreshLabels()
	local plotParts = self:_GetPlotParts()
	local now = os.clock()

	for plotIndex, entry in pairs(self._PlotLabels) do
		local part = plotParts[plotIndex]
		if not self._Plots[plotIndex] or entry.billboard.Adornee ~= part then
			entry.billboard:Destroy()
			self._PlotLabels[plotIndex] = nil
		end
	end

	for plotIndex, plot in pairs(self._Plots) do
		local part = plotParts[plotIndex]
		local crop = CropData.GetBySeed(plot.seed)
		if not part or not crop then continue end

		local entry = self._PlotLabels[plotIndex]
		if not entry then
			local billboard, label = buildPlotLabel(part)
			entry = { billboard = billboard, label = label }
			self._PlotLabels[plotIndex] = entry
		end

		local cropConfig = ItemData.GetItem(crop.cropName)
		local cropName = cropConfig and cropConfig.displayName or crop.cropName
		local secsRemaining = plot.readyAt - now
		if secsRemaining <= 0 then
			entry.label.Text = cropName .. " · Ready!"
			entry.label.TextColor3 = READY_COLOR
		else
			entry.label.Text = cropName .. " · " .. formatTime(secsRemaining)
			entry.label.TextColor3 = LABEL_COLOR
		end
	end
end

-- PlotIndex of the plot block or crop under a screen position, or nil
function CropField:_GetPlotAt(screenPosition: Vector2?): number?
	if not screenPosition then return nil end

	local model = self:_GetCompletedModel()
	if not model then return nil end

	local ray = Workspace.CurrentCamera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { model }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 1000, params)

	local current = result and result.Instance
	while current and current ~= model do
		local plotIndex = current:GetAttribute("PlotIndex")
		if plotIndex then
			return plotIndex
		end
		current = current.Parent
	end
	return nil
end

local function isHoldingSeeds(): boolean
	local inventory = Store:getState().InventoryReducer
	local slot = inventory.EquippedSlot
	local item = slot and slot > 0 and inventory.Hotbar[slot]
	return item ~= nil and item ~= false and CropData.GetBySeed(item.itemName) ~= nil
end

function CropField:_Plant(plotIndex: number)
	local TextNotificationController = Knit.GetController("TextNotificationController")
	Knit.GetService("CropFieldService"):Plant(self.Id, plotIndex):andThen(function(success, errorMessage)
		if not success and errorMessage then
			TextNotificationController:Show(errorMessage, ERROR_COLOR)
		end
	end)
end

function CropField:_Harvest()
	local TextNotificationController = Knit.GetController("TextNotificationController")
	Knit.GetService("CropFieldService"):Harvest(self.Id):andThen(function(harvested, message, inventoryFull)
		if message then
			TextNotificationController:Show(message, inventoryFull and ERROR_COLOR or nil)
		end
		if harvested > 0 then
			TextNotificationController:Show(
				string.format("Harvested %d crop%s!", harvested, harvested > 1 and "s" or ""),
				HARVEST_COLOR
			)
		end
	end)
end

-- Click or tap on the field: plant on an empty plot while holding seeds, otherwise harvest
function CropField:_OnInteract(player, screenPosition: Vector2?)
	local plotIndex = self:_GetPlotAt(screenPosition)
	if plotIndex and not self._Plots[plotIndex] and isHoldingSeeds() then
		self:_Plant(plotIndex)
	else
		self:_Harvest()
	end
end

-- BuildingController hover highlight: the plot under the cursor while holding seeds
-- (false = nothing to plant on), the whole field otherwise (nil)
function CropField:GetHoverHighlightAdornee(screenPosition: Vector2)
	if not isHoldingSeeds() then return nil end
	local plotIndex = self:_GetPlotAt(screenPosition)
	return plotIndex and self:_GetPlotParts()[plotIndex] or false
end

-- ControlHints left click action: "Plant" on an empty plot while holding seeds
function CropField:GetHoverAction(screenPosition: Vector2): string?
	if not isHoldingSeeds() then return nil end
	local plotIndex = self:_GetPlotAt(screenPosition)
	if plotIndex and not self._Plots[plotIndex] then
		return "Plant"
	end
	return nil
end

function CropField:Destroy()
	for _, entry in pairs(self._PlotLabels) do
		entry.billboard:Destroy()
	end
	self._PlotLabels = {}
	self._RefreshThread = nil
	ClientBaseBlueprint.Destroy(self)
end

return CropField
