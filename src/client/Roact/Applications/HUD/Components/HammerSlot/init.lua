--[=[
	HammerSlot Component
	Contextual Hammer slot that appears to the left of the hotbar
	Only visible when player is inside BuildingArea
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

local function HammerSlot(props, hooks)
	local isEquipped = props.isEquipped or false
	local onSlotClick = props.onSlotClick

	local isHovered, setIsHovered = hooks.useState(false)

	local hammerImage = Images["Hammer"]

	local strokeColor = isEquipped and Config.EquippedStrokeColor or Config.StrokeColor
	local strokeThickness = isEquipped and Config.EquippedStrokeThickness or Config.StrokeThickness
	local strokeTransparency = isEquipped and Config.EquippedStrokeTransparency or Config.StrokeTransparency
	local backgroundColor = isHovered and Config.HoverColor or Config.BackgroundColor

	local itemDisplay = nil
	if hammerImage then
		itemDisplay = Roact.createElement("ImageLabel", {
			Size = UDim2.fromScale(0.75, 0.75),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = hammerImage,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = 3,
		})
	end

	return Roact.createElement("ImageButton", {
		Name = "HammerSlot",
		Size = Config.ButtonSize,
		Position = Config.ButtonPosition,
		AnchorPoint = Vector2.new(1, 0.5),
		BackgroundColor3 = backgroundColor,
		BackgroundTransparency = 0,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
		ZIndex = 1,
		ClipsDescendants = true,
		[Roact.Event.MouseButton1Click] = onSlotClick,
		[Roact.Event.MouseEnter] = function()
			setIsHovered(true)
		end,
		[Roact.Event.MouseLeave] = function()
			setIsHovered(false)
		end,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = strokeColor,
			Thickness = strokeThickness,
			Transparency = strokeTransparency,
		}),

		Background = Roact.createElement(StudBackground, {
			ZIndex = 1,
			BackgroundColor = backgroundColor,
			ImageTransparency = 0.91,
			CornerRadius = Config.CornerRadius,
		}),

		ItemDisplay = itemDisplay,

		Keybind = Roact.createElement(FancyText, {
			Text = "H",
			Size = UDim2.fromScale(0.3, 0.3),
			Position = UDim2.fromScale(0.05, 0.02),
			AnchorPoint = Vector2.new(0, 0),
			TextColor3 = Config.KeybindColor,
			StrokeColor = Config.KeybindStrokeColor,
			StrokeThickness = Config.KeybindStrokeThickness,
			ZIndex = 4,
		}),
	})
end

HammerSlot = RoactHooks.new(Roact)(HammerSlot)
return HammerSlot
