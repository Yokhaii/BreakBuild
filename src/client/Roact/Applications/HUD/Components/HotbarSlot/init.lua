--[=[
	HotbarSlot Component
	Individual slot in the hotbar
	Displays items using ImageLabel from the Images registry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local FancyText = require(Components.Global.FancyText)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local function HotbarSlot(props, hooks)
	local slotNumber = props.slotNumber
	local item = props.item
	local isEquipped = props.isEquipped or false
	local onSlotClick = props.onSlotClick
	local baseZIndex = props.ZIndex or 1

	local isEmpty = item == nil
	local displayAmount = ""
	local itemImage = nil

	if item then
		itemImage = Images[item.itemName]

		if item.quantity and item.quantity > 1 then
			displayAmount = "x" .. tostring(item.quantity)
		end
	end

	local strokeColor = isEquipped and Config.EquippedStrokeColor or Config.ImageStrokeColor
	local strokeThickness = isEquipped and Config.EquippedStrokeThickness or Config.ImageStrokeThickness
	local strokeTransparency = isEquipped and Config.EquippedStrokeTransparency or Config.ImageStrokeTransparency

	local itemDisplay = nil
	if not isEmpty and itemImage then
		itemDisplay = Roact.createElement("ImageLabel", {
			Size = UDim2.fromScale(0.75, 0.75),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = itemImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = baseZIndex + 2,
		})
	end

	return Roact.createElement("ImageButton", {
		Name = tostring(slotNumber),
		Size = Config.SlotSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
		LayoutOrder = slotNumber,
		ZIndex = baseZIndex,
		ClipsDescendants = true,
		[Roact.Event.MouseButton1Click] = function()
			if onSlotClick then
				onSlotClick(slotNumber)
			end
		end,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.ImageCornerRadius,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = strokeColor,
			Thickness = strokeThickness,
			Transparency = strokeTransparency,
		}),

		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
		}),

		ImageBackground = Roact.createElement(StudBackground, {
			ZIndex = baseZIndex + 1,
			BackgroundColor = Config.ImageBackgroundColor,
			ImageTransparency = Config.ImageStudTransparency,
			CornerRadius = Config.ImageCornerRadius,
		}),

		ItemDisplay = itemDisplay,

		Amount = displayAmount ~= "" and Roact.createElement(FancyText, {
			Text = displayAmount,
			Size = UDim2.fromScale(0.5, 0.3),
			Position = UDim2.fromScale(0.95, 0.95),
			AnchorPoint = Vector2.new(1, 1),
			TextColor3 = Config.AmountColor,
			StrokeColor = Config.AmountStrokeColor,
			StrokeThickness = Config.AmountStrokeThickness,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = baseZIndex + 3,
		}) or nil,
	})
end

HotbarSlot = RoactHooks.new(Roact)(HotbarSlot)
return HotbarSlot
