--[=[
	HotbarSlot Component
	Individual slot in the hotbar
	Displays items using ImageLabel from the Images registry
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local FancyText = require(Components.Global.FancyText)
local DurabilityBar = require(Components.Global.DurabilityBar)
local TutorialTargets = require(StarterPlayer.StarterPlayerScripts.Client.Modules.TutorialTargets)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local function HotbarSlot(props, hooks)
	local slotNumber = props.slotNumber
	local item = props.item
	local isEquipped = props.isEquipped or false
	local onSlotClick = props.onSlotClick
	local onPressStart = props.onPressStart
	local isDropZone = props.isDropZone or false
	local baseZIndex = props.ZIndex or 1

	local dropZoneRef = hooks.useValue(Roact.createRef())

	-- Drop zone (grid index 22-28) so items can be dragged between HUD slots
	hooks.useEffect(function()
		local dropZone = dropZoneRef.value:getValue()
		if not isDropZone or not dropZone then return end

		local InventoryController = Knit.GetController("InventoryController")
		if not InventoryController then return end

		return InventoryController:RegisterDropZone(
			"hud_hotbar_slot_" .. slotNumber,
			Config.BackpackSlotCount + slotNumber,
			dropZone
		)
	end, { slotNumber, isDropZone })

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
			Size = Config.ItemImageSize,
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
		[Roact.Ref] = TutorialTargets.Ref("HotbarSlot_" .. slotNumber),
		[Roact.Event.MouseButton1Down] = function()
			if item and onPressStart then
				onPressStart(slotNumber, item)
			end
		end,
		[Roact.Event.MouseButton1Click] = function()
			if onSlotClick then
				onSlotClick(slotNumber)
			end
		end,
	}, {
		DropZone = Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			[Roact.Ref] = dropZoneRef.value,
		}),

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

		Durability = Roact.createElement(DurabilityBar, {
			Item = item,
			ZIndex = baseZIndex + 3,
		}),
	})
end

HotbarSlot = RoactHooks.new(Roact)(HotbarSlot)
return HotbarSlot
