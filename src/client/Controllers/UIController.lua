-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- UIController
local UIController = Knit.CreateController({
	Name = "UIController",
})

-- UI references
local screenGui = nil

--|| Initialization ||--

function UIController:KnitStart()
	-- Get ScreenGui reference
	screenGui = playerGui:WaitForChild("ScreenGui")

	-- Enable the ScreenGui
	screenGui.Enabled = true

	print("UIController started - ScreenGui enabled")
end

return UIController
