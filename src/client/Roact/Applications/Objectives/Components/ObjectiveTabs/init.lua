--[=[
	ObjectiveTabs Component
	Row of tab buttons filtering the Objectives frame list.

	Props:
		Tabs         ({ { key, label, count } })
		SelectedTab  (string)
		OnSelect     (function(key))
		Size, Position, AnchorPoint, ZIndex
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function ObjectiveTabs(props, hooks)
	local baseZIndex = props.ZIndex or 1

	local buttons = {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = Config.ButtonSpacing,
		}),
	}

	for index, tab in ipairs(props.Tabs or {}) do
		local isSelected = props.SelectedTab == tab.key
		buttons["Tab_" .. tab.key] = Roact.createElement("TextButton", {
			Size = Config.ButtonSize,
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			LayoutOrder = index,
			ZIndex = baseZIndex,
			[Roact.Event.MouseButton1Click] = function()
				if props.OnSelect then
					props.OnSelect(tab.key)
				end
			end,
		}, {
			Background = Roact.createElement(StudBackground, {
				ZIndex = baseZIndex,
				BackgroundColor = isSelected and Config.ActiveColor or Config.InactiveColor,
				ImageTransparency = Config.ButtonStudImageTransparency,
				CornerRadius = Config.ButtonCornerRadius,
			}),

			Label = Roact.createElement("TextLabel", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = string.format(Config.LabelFormat, tab.label, tab.count or 0),
				TextColor3 = Config.ButtonTextColor,
				TextScaled = true,
				FontFace = Config.ButtonFont,
				ZIndex = baseZIndex + 1,
			}, {
				UIPadding = Roact.createElement("UIPadding", {
					PaddingLeft = Config.ButtonPaddingHorizontal,
					PaddingRight = Config.ButtonPaddingHorizontal,
					PaddingTop = Config.ButtonPaddingVertical,
					PaddingBottom = Config.ButtonPaddingVertical,
				}),
			}),
		})
	end

	return Roact.createElement("Frame", {
		Name = "ObjectiveTabs",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,
	}, buttons)
end

ObjectiveTabs = RoactHooks.new(Roact)(ObjectiveTabs)
return ObjectiveTabs
