--[=[
	UIController
	Manages UI state and provides helpers for UI operations
	The actual UI is rendered by Roact components
]=]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Rodux
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local UIActions = require(Actions.UIActions)

-- UIController
local UIController = Knit.CreateController({
	Name = "UIController",
})

--|| Public Functions ||--

-- Set the current visible frame
function UIController:SetCurrentFrame(frameName: string)
	Store:dispatch(UIActions.setCurrentFrame(frameName))
end

-- Get the current frame name
function UIController:GetCurrentFrame(): string
	return Store:getState().UIReducer.CurrentFrame
end

-- Show HUD
function UIController:ShowHUD()
	self:SetCurrentFrame("HUD")
end

-- Remove HUD (set to empty/none)
function UIController:RemoveHUD(options)
	-- If ignoreTopFrame is needed, handle it here
	self:SetCurrentFrame("None")
end

--|| Initialization ||--

function UIController:KnitStart()
	-- UI is now managed by Roact/Rodux
	-- No need to wait for ScreenGui instances
	print("[UIController] Started - Roact/Rodux UI system active")
end

return UIController
