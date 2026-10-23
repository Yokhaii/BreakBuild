local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)
local ShopActions = require(Client.Rodux.Actions.ShopActions)

local Components = Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local Config = require(script.Config)

local function CategoryFilter(props, hooks)
	local currentFilter = RoduxHooks.useSelector(hooks, function(state)
		return state.ShopReducer.CategoryFilter
	end)

	local baseZIndex = props.ZIndex or 12

	local buttons = {}

	for i, cat in ipairs(Config.Categories) do
		local isActive = currentFilter == cat.key
		local bgColor = isActive and Config.ActiveColor or Config.InactiveColor

		buttons["Cat_" .. (cat.label)] = Roact.createElement("TextButton", {
			Size = UDim2.fromScale(1 / #Config.Categories - 0.02, 1),
			BackgroundTransparency = 1,
			Text = cat.label,
			TextColor3 = Config.ButtonTextColor,
			TextScaled = true,
			FontFace = Config.ButtonFont,
			AutoButtonColor = false,
			LayoutOrder = i,
			ZIndex = baseZIndex + 2,
			[Roact.Event.MouseButton1Click] = function()
				Store:dispatch(ShopActions.setCategoryFilter(cat.key))
			end,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.ButtonCornerRadius,
			}),
			StudBackground = Roact.createElement(StudBackground, {
				ZIndex = baseZIndex + 1,
				BackgroundColor = bgColor,
				ImageTransparency = Config.ButtonStudImageTransparency,
				CornerRadius = Config.ButtonCornerRadius,
			}),
			UIPadding = Roact.createElement("UIPadding", {
				PaddingLeft = Config.ButtonPaddingH,
				PaddingRight = Config.ButtonPaddingH,
				PaddingTop = Config.ButtonPaddingV,
				PaddingBottom = Config.ButtonPaddingV,
			}),
		})
	end

	return Roact.createElement("Frame", {
		Size = Config.Size,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = baseZIndex,
	}, {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			Padding = Config.ButtonSpacing,
		}),
		Buttons = Roact.createFragment(buttons),
	})
end

CategoryFilter = RoactHooks.new(Roact)(CategoryFilter)
return CategoryFilter
