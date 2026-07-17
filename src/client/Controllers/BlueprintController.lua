--[[
	BlueprintController.lua
	Manages the Blueprint menu open/close state.
	The menu is opened by clicking the Blueprints table model in BuildingController.
]]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Rodux
local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)
local UIActions = require(Client.Rodux.Actions.UIActions)

-- BlueprintController
local BlueprintController = Knit.CreateController({
	Name = "BlueprintController",
})

-- Private state
local isBlueprintMenuOpen = false

-- Close the Blueprint menu
local function closeBlueprintMenu()
	if not isBlueprintMenuOpen then return end
	isBlueprintMenuOpen = false
	Store:dispatch(UIActions.setCurrentFrame("HUD"))
end

--|| Public Functions ||--

function BlueprintController:OpenBlueprintMenu()
	if isBlueprintMenuOpen then return end
	isBlueprintMenuOpen = true
	Store:dispatch(UIActions.setCurrentFrame("Blueprint"))
end

function BlueprintController:CloseBlueprintMenu()
	closeBlueprintMenu()
end

function BlueprintController:IsBlueprintMenuOpen()
	return isBlueprintMenuOpen
end

--|| Initialization ||--

function BlueprintController:KnitStart()
	-- Sync state if the menu is closed externally (e.g. back button in UI)
	Store.changed:connect(function(newState, oldState)
		local oldFrame = oldState.UIReducer and oldState.UIReducer.CurrentFrame
		local newFrame = newState.UIReducer and newState.UIReducer.CurrentFrame

		if oldFrame == "Blueprint" and newFrame ~= "Blueprint" and isBlueprintMenuOpen then
			isBlueprintMenuOpen = false
		end
	end)
end

return BlueprintController
