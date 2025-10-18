local GuiService = game:GetService("GuiService")

GuiService.AutoSelectGuiEnabled = true
GuiService.GuiNavigationEnabled = true

--game:GetService("StarterGui"):SetCore("ResetButtonCallback", false)
-- Game Services

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local KnitClient = require(ReplicatedStorage.Packages.Knit)
local Roact = require(ReplicatedStorage.Packages.Roact)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local Preloader = require(ReplicatedStorage.Packages.Preloader)

local UserInputService = game:GetService("UserInputService")


if UserInputService.TouchEnabled then -- Check if device has touch capabilities
	-- Set the preferred orientation to landscape
	task.wait()
	local playerGUI = Players.LocalPlayer:WaitForChild("PlayerGui")
	playerGUI.ScreenOrientation = Enum.ScreenOrientation.LandscapeRight
end
-- This will run when the game starts

Preloader:Configure({
	showLoadingScreen = true,
	loadControllers = true,
	loadImages = false,
	loadUI = false,
	initialDelay = 0.5,
	finalDelay = 1,
	skipEnabled = false,
	batchSize = 10, 
	keepLoadingScreen = false,
	paths = {
		controllersPath = StarterPlayer.StarterPlayerScripts.Client.Controllers,
		imagesPath = nil,
		componentsPath = nil,
	},
})
Preloader.ControllersLoadedSignal:Connect(function()
	KnitClient.Start()
		:andThen(function()
			print("Knit Client Successfully Started")
		end)
		:catch(warn)
		:await()

	local Root = require(StarterPlayer.StarterPlayerScripts.Client.Roact.Root.Application)
	local Sync = require(StarterPlayer.StarterPlayerScripts.Client.Modules.Synchronization)
	Sync()
	Roact.mount(
		Roact.createElement(RoduxHooks.Provider, {
			store = Store,
		}, {
			GameScreenGui = Roact.createElement(Root.Game),
		}),
		Players.LocalPlayer.PlayerGui,
		"UI"
	)
end)

Preloader.EndPreloaderSignal:Connect(function(bool)
	
end)

Preloader:PreloadContent()
