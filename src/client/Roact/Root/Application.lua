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
local HUD = require(Applications.HUD)
local BlueprintApplication = require(Applications.Blueprint)
local BackpackApplication = require(Applications.Backpack)
local Notifications = require(Applications.HUD.Components.Notifications)
local BiomeTransition = require(Applications.BiomeTransition)
local TutorialApplication = require(Applications.Tutorial)

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
			Backpack = Roact.createElement(BackpackApplication),
		}),
		TutorialScreenGui = Roact.createElement("ScreenGui", {
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Global,
			DisplayOrder = 50,
			ResetOnSpawn = false,
		}, {
			Tutorial = Roact.createElement(TutorialApplication),
		}),
		NotificationScreenGui = Roact.createElement("ScreenGui", {
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Global,
			DisplayOrder = 100,
			ResetOnSpawn = false,
		}, {
			Notifications = Roact.createElement(Notifications),
		}),
		BiomeTransitionScreenGui = Roact.createElement("ScreenGui", {
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Global,
			DisplayOrder = 200,
			ResetOnSpawn = false,
		}, {
			BiomeTransition = Roact.createElement(BiomeTransition),
		}),
	})
end

return {
	Game = GameFrame,
}
