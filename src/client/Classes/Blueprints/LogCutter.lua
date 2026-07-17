local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ClientBaseBlueprint = require(script.Parent.BaseBlueprint)

local LogCutter = {}
LogCutter.__index = LogCutter
setmetatable(LogCutter, { __index = ClientBaseBlueprint })

function LogCutter.new(data)
	local self = ClientBaseBlueprint.new(data)
	setmetatable(self, LogCutter)
	return self
end

function LogCutter:_OnInteract(player)
	local UIController = Knit.GetController("UIController")
	local InventoryController = Knit.GetController("InventoryController")
	local CraftingController = Knit.GetController("CraftingController")

	if UIController and InventoryController and CraftingController then
		UIController:SetCurrentFrame("LogCutter")
		InventoryController:OpenBackpack()
		CraftingController:StartSession(self.Id)
	end
end

return LogCutter
