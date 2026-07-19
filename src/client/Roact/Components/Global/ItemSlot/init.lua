--[=[
	ItemSlot Component
	Generic square item slot with a StudBackground, optional item image, and optional click handler.

	Props:
		Image            (string?)   -- asset id to display inside the slot
		ItemName         (string?)   -- item name shown in tooltip on hover
		ZIndex           (number?)   -- base ZIndex; defaults to 1
		LayoutOrder      (number?)   -- for use inside UIGridLayout
		OnClick          (function?) -- fired on MouseButton1Click
		OnHoverStart     (function?) -- called with itemName on mouse enter (optional; tooltip is self-managed when absent)
		OnHoverEnd       (function?) -- called on mouse leave (optional)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local TooltipConfig = require(Components.Global.ItemTooltip.Config)

local Config = require(script.Config)

-- Imperatively builds and returns a tooltip Frame parented to PlayerGui.
-- Returns a cleanup function that destroys it.
local function createImperativeTooltip(itemName: string)
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not playerGui then return function() end end

	-- Target the game's main ScreenGui specifically so the tooltip is always on top.
	local screenGui = playerGui:FindFirstChild("GameScreenGui")
	if not screenGui then return function() end end

	-- GameScreenGui uses IgnoreGuiInset = true, so mouse Y needs no inset correction.
	local function calcPos()
		local mousePos = UserInputService:GetMouseLocation()
		return UDim2.fromOffset(
			mousePos.X + TooltipConfig.Offset.X,
			mousePos.Y + TooltipConfig.Offset.Y
		)
	end

	local initialPos = calcPos()

	local tooltip = Instance.new("Frame")
	tooltip.Name = "ItemTooltip_" .. itemName
	tooltip.AutomaticSize = Enum.AutomaticSize.XY
	tooltip.BackgroundTransparency = 1
	tooltip.ZIndex = 10000
	tooltip.Position = initialPos
	tooltip.Parent = screenGui

	-- Background
	local bg = Instance.new("Frame")
	bg.Name = "Background"
	bg.Size = UDim2.fromScale(1, 1)
	bg.AutomaticSize = Enum.AutomaticSize.XY
	bg.BackgroundColor3 = TooltipConfig.BackgroundColor
	bg.BorderSizePixel = 0
	bg.ZIndex = 10000
	bg.Parent = tooltip

	local bgCorner = Instance.new("UICorner")
	bgCorner.CornerRadius = TooltipConfig.CornerRadius
	bgCorner.Parent = bg

	local bgStroke = Instance.new("UIStroke")
	bgStroke.Color = TooltipConfig.StrokeColor
	bgStroke.Thickness = TooltipConfig.StrokeThickness
	bgStroke.Transparency = TooltipConfig.StrokeTransparency
	bgStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	bgStroke.Parent = bg

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = TooltipConfig.PaddingHorizontal
	padding.PaddingRight = TooltipConfig.PaddingHorizontal
	padding.PaddingTop = TooltipConfig.PaddingVertical
	padding.PaddingBottom = TooltipConfig.PaddingVertical
	padding.Parent = bg

	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromScale(0, 0)
	label.BackgroundTransparency = 1
	label.Text = itemName
	label.TextColor3 = TooltipConfig.TextColor
	label.TextScaled = false
	label.TextSize = 14
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
	label.ZIndex = 10001
	label.Parent = bg

	local labelStroke = Instance.new("UIStroke")
	labelStroke.Color = TooltipConfig.TextStrokeColor
	labelStroke.Thickness = TooltipConfig.TextStrokeThickness
	labelStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	labelStroke.Parent = label

	-- Follow mouse every frame
	local connection = RunService.RenderStepped:Connect(function()
		tooltip.Position = calcPos()
	end)

	return function()
		connection:Disconnect()
		tooltip:Destroy()
	end
end

local function ItemSlot(props, hooks)
	local zIndex = props.ZIndex or 1
	local image = props.Image
	local itemName = props.ItemName
	local onClickHandler = props.OnClick
	local onHoverStart = props.OnHoverStart
	local onHoverEnd = props.OnHoverEnd

	-- Self-managed tooltip (used when parent does not supply OnHoverStart/OnHoverEnd)
	local isHovered, setIsHovered = hooks.useState(false)
	local selfManaged = not onHoverStart

	hooks.useEffect(function()
		if not selfManaged or not isHovered or not itemName then return end
		local cleanup = createImperativeTooltip(itemName)
		return cleanup
	end, { isHovered, itemName, selfManaged })

	local needsButton = onClickHandler or itemName

	local function handleMouseEnter()
		if onHoverStart and itemName then
			onHoverStart(itemName)
		elseif selfManaged then
			setIsHovered(true)
		end
	end

	local function handleMouseLeave()
		if onHoverEnd then
			onHoverEnd()
		elseif selfManaged then
			setIsHovered(false)
		end
	end

	return Roact.createElement("Frame", {
		Name = props.Name or "ItemSlot",
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		LayoutOrder = props.LayoutOrder,
	}, {
		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
		}),

		UICorner = Roact.createElement("UICorner", {
			CornerRadius = props.CornerRadius or Config.CornerRadius,
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Color = props.StrokeColor or Config.StrokeColor,
			Thickness = props.StrokeThickness or Config.StrokeThickness,
			Transparency = props.StrokeTransparency or Config.StrokeTransparency,
		}),

		SlotBackground = Roact.createElement(StudBackground, {
			ZIndex = zIndex + 1,
			BackgroundColor = props.BackgroundColor or Config.BackgroundColor,
			ImageTransparency = props.StudImageTransparency or Config.StudImageTransparency,
			CornerRadius = props.CornerRadius or Config.CornerRadius,
		}),

		ItemImage = image and Roact.createElement("ImageLabel", {
			Size = UDim2.fromScale(0.75, 0.75),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = image,
			ImageTransparency = props.ImageTransparency or 0,
			ScaleType = Enum.ScaleType.Fit,
			ZIndex = zIndex + 2,
		}) or nil,

		Button = needsButton and Roact.createElement("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			ZIndex = zIndex + 3,
			[Roact.Event.MouseButton1Click] = onClickHandler,
			[Roact.Event.MouseEnter] = handleMouseEnter,
			[Roact.Event.MouseLeave] = handleMouseLeave,
		}) or nil,

		QuantityLabel = props.Quantity and Roact.createElement("TextLabel", {
			Size = UDim2.fromScale(0.6, 0.38),
			Position = UDim2.fromScale(1, 1),
			AnchorPoint = Vector2.new(1, 1),
			BackgroundTransparency = 1,
			Text = tostring(props.Quantity),
			TextColor3 = Color3.fromRGB(255, 255, 255),
			TextScaled = true,
			FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = zIndex + 4,
		}, {
			UIStroke = Roact.createElement("UIStroke", {
				Color = Color3.fromRGB(0, 0, 0),
				Thickness = 1.5,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
			}),
		}) or nil,
	})
end

ItemSlot = RoactHooks.new(Roact)(ItemSlot)
return ItemSlot
