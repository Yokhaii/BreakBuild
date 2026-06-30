local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local FancyText = require(Components.Global.FancyText)

local Config = require(script.Config)

local function ItemTooltip(props, hooks)
	local itemName = props.ItemName
	local visible = props.Visible

	local position, setPosition = hooks.useState(UDim2.fromOffset(0, 0))

	hooks.useEffect(function()
		if not visible then return end

		local connection = RunService.RenderStepped:Connect(function()
			local mousePos = UserInputService:GetMouseLocation()
			setPosition(UDim2.fromOffset(
				mousePos.X + Config.Offset.X,
				mousePos.Y + Config.Offset.Y
			))
		end)

		return function()
			connection:Disconnect()
		end
	end, { visible })

	if not visible or not itemName then
		return nil
	end

	return Roact.createElement("Frame", {
		Name = "ItemTooltip",
		AutomaticSize = Enum.AutomaticSize.XY,
		Position = position,
		BackgroundTransparency = 1,
		ZIndex = 999,
	}, {
		Background = Roact.createElement(StudBackground, {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor = Config.BackgroundColor,
			ImageTransparency = Config.StudImageTransparency,
			CornerRadius = Config.CornerRadius,
			StrokeColor = Config.StrokeColor,
			StrokeThickness = Config.StrokeThickness,
			StrokeTransparency = Config.StrokeTransparency,
			ZIndex = 999,
		}),

		Content = Roact.createElement("Frame", {
			AutomaticSize = Enum.AutomaticSize.XY,
			BackgroundTransparency = 1,
			ZIndex = 1000,
		}, {
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = Config.PaddingHorizontal,
				PaddingRight = Config.PaddingHorizontal,
				PaddingTop = Config.PaddingVertical,
				PaddingBottom = Config.PaddingVertical,
			}),

			NameLabel = Roact.createElement(FancyText, {
				Text = itemName,
				AutomaticSize = Enum.AutomaticSize.XY,
				Size = UDim2.fromScale(0, 0),
				TextColor3 = Config.TextColor,
				StrokeColor = Config.TextStrokeColor,
				StrokeThickness = Config.TextStrokeThickness,
				TextScaled = false,
				TextSize = 14,
				ZIndex = 1000,
			}),
		}),
	})
end

ItemTooltip = RoactHooks.new(Roact)(ItemTooltip)
return ItemTooltip
