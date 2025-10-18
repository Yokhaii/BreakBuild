-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Player
local player = Players.LocalPlayer

-- TemplateController
local TemplateController = Knit.CreateController({
	Name = "TemplateController",
})

--|| Local Functions ||--

--|| Functions ||--

function TemplateController:KnitStart() end

return TemplateController