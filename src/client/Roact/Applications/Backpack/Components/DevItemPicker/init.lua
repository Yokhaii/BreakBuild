--[=[
	DevItemPicker Component
	Dev-only panel that appears to the left of the backpack.
	Shows all items in the game and lets devs give themselves any item on click.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local PanelFrame = require(Components.Frames.PanelFrame)

local DEFAULT_ITEM_ICON = "rbxassetid://95016840981722"

local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local function isDev()
	if RunService:IsStudio() then
		return true
	end
	local player = Players.LocalPlayer
	for _, id in ipairs(Config.DevUserIds) do
		if player.UserId == id then
			return true
		end
	end
	return false
end

local sortedItems
local function getSortedItems()
	if sortedItems then return sortedItems end
	local items = {}
	for _, itemConfig in pairs(ItemData.Items) do
		table.insert(items, itemConfig)
	end
	table.sort(items, function(a, b)
		local typeOrder = { Tool = 1, Block = 2, Ore = 3, Blueprint = 4, Structure = 5 }
		local aOrder = typeOrder[a.type] or 99
		local bOrder = typeOrder[b.type] or 99
		if aOrder ~= bOrder then
			return aOrder < bOrder
		end
		return (a.displayName or a.name) < (b.displayName or b.name)
	end)
	sortedItems = items
	return items
end

local function DevItemPicker(props, hooks)
	if not isDev() then
		return Roact.createElement("Frame", { Visible = false })
	end

	local frameRef = hooks.useValue(Roact.createRef())

	hooks.useEffect(function()
		local frame = frameRef.value:getValue()
		if not frame then return end

		local InventoryController = Knit.GetController("InventoryController")
		if not InventoryController then return end

		local cleanup = InventoryController:RegisterDropZone("dev_trash", -1, frame)
		return cleanup
	end, {})

	local items = getSortedItems()

	local function handleItemClick(itemName)
		local InventoryService = Knit.GetService("InventoryService")
		if InventoryService then
			InventoryService:AddItem(itemName, 1)
		end
	end

	local gridChildren = {
		UIGridLayout = Roact.createElement("UIGridLayout", {
			CellSize = UDim2.fromScale(1 / Config.GridColumns - 0.03, 1 / Config.GridColumns - 0.03),
			CellPadding = Config.CellPadding,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}

	for i, itemConfig in ipairs(items) do
		local itemImage = Images[itemConfig.name]

		gridChildren["Item_" .. itemConfig.name] = Roact.createElement("Frame", {
			Name = itemConfig.name,
			BackgroundTransparency = 1,
			LayoutOrder = i,
		}, {
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),

			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.SlotCornerRadius,
			}),

			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.SlotStrokeColor,
				Thickness = Config.SlotStrokeThickness,
				Transparency = Config.SlotStrokeTransparency,
			}),

			SlotBackground = Roact.createElement(StudBackground, {
				ZIndex = 14,
				BackgroundColor = Config.SlotBackgroundColor,
				ImageTransparency = Config.SlotStudImageTransparency,
				CornerRadius = Config.SlotCornerRadius,
			}),

			ItemImage = Roact.createElement("ImageLabel", {
				Size = UDim2.fromScale(0.75, 0.75),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = (itemImage and itemImage ~= "rbxassetid://0") and itemImage or DEFAULT_ITEM_ICON,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 15,
			}),

			Button = Roact.createElement("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 16,
				[Roact.Event.MouseButton1Click] = function()
					handleItemClick(itemConfig.name)
				end,
			}),
		})
	end

	return Roact.createElement(PanelFrame, {
		Name = "DevItemPicker",
		AnchorPoint = Config.FrameAnchorPoint,
		Position = Config.FramePosition,
		Size = Config.FrameSize,
		AspectRatio = Config.AspectRatio,
		ZIndex = 11,
		[Roact.Ref] = frameRef.value,
	}, {
		ScrollFrame = Roact.createElement("ScrollingFrame", {
			Name = "ItemGrid",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.95, 0.97),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = Color3.fromRGB(200, 200, 200),
			ScrollBarImageTransparency = 0.3,
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ZIndex = 14,
		}, gridChildren),
	})
end

DevItemPicker = RoactHooks.new(Roact)(DevItemPicker)
return DevItemPicker
