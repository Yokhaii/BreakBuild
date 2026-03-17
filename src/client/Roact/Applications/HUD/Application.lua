--[=[
	Owner: Yokhaii
	Version: 0.0.2
	Contact owner if any question, concern or feedback

	HUD Application - Main game HUD with Hotbar and Backpack
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Modules
local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

-- Components
local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local Hotbar = require(Components.Inventory.Hotbar)
local Backpack = require(Components.Inventory.Backpack)

-- Component
local function HUD(_, hooks)
	-- Check if HUD should be visible based on UIReducer
	local uiState = RoduxHooks.useSelector(hooks, function(state)
		return state.UIReducer
	end)

	local isVisible = uiState.CurrentFrame == "HUD"

	if not isVisible then
		return Roact.createElement("Frame", {
			Visible = false,
		})
	end

	return Roact.createElement("Frame", {
		Name = "HUD",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		-- Hotbar at the bottom
		Hotbar = Roact.createElement(Hotbar),

		-- Backpack (shown/hidden via its own state)
		Backpack = Roact.createElement(Backpack),
	})
end

HUD = RoactHooks.new(Roact)(HUD)
return HUD
