--[=[
	HUD Application - Main game HUD with Hotbar
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

-- Components
local Hotbar = require(script.Components.Hotbar)
local CycleTimer = require(script.Components.CycleTimer)

-- Component
local function HUD(_, hooks)
	local uiState = RoduxHooks.useSelector(hooks, function(state)
		return state.UIReducer
	end)

	local isVisible = true


	return Roact.createElement("Frame", {
		Name = "HUD",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Visible = isVisible
	}, {
		Hotbar = Roact.createElement(Hotbar),
		CycleTimer = Roact.createElement(CycleTimer),
	})
end

HUD = RoactHooks.new(Roact)(HUD)
return HUD
