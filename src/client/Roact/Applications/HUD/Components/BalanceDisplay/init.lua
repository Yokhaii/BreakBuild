local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local FancyText = require(Components.Global.FancyText)

local Config = require(script.Config)

local function BalanceDisplay(_, hooks)
	local balance = RoduxHooks.useSelector(hooks, function(state)
		return state.ShopReducer.Balance
	end)

	return Roact.createElement(FancyText, {
		Text = "$" .. tostring(balance),
		Position = Config.Position,
		AnchorPoint = Config.AnchorPoint,
		Size = Config.Size,
		TextColor3 = Config.TextColor,
		StrokeColor = Config.StrokeColor,
		StrokeThickness = Config.StrokeThickness,
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 5,
	})
end

BalanceDisplay = RoactHooks.new(Roact)(BalanceDisplay)
return BalanceDisplay
