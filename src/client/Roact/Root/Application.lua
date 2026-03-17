--[=[
	Owner: CategoryTheory
	Version: 0.0.1
	Contact owner if any question, concern or feedback
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Directories
local Applications = StarterPlayer.StarterPlayerScripts.Client.Roact.Applications
local Contexts = StarterPlayer.StarterPlayerScripts.Client.Roact.Contexts
local AllowedApplicationsContext = require(Contexts.AllowedApplicationsContext)
local ContextStack = require(Contexts.ContextStack)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

-- Modules
local Roact = require(ReplicatedStorage.Packages.Roact)
local HUD = require(Applications.HUD.Application)
local BlueprintApplication = require(Applications.Blueprint.Application)

--local GlobalHoveredFrame = require(Applications.GlobalHoveredFrame.Application)

local function Root(props, hooks)
	return Roact.createElement(ContextStack, {
		providers = {
			AllowedApplicationsContext.Provider,
		},
	}, Roact.createFragment(props[Roact.Children]))
end
Root = RoactHooks.new(Roact)(Root)

-- Component
local function GameFrame()
	return Roact.createElement(Root, {}, {
		GameScreenGui = Roact.createElement("ScreenGui", {
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Global,
			ResetOnSpawn = false,
		}, {
			HUD = Roact.createElement(HUD),
			Blueprint = Roact.createElement(BlueprintApplication),
		}),
	})
end

return {
	Game = GameFrame,
}
