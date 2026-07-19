local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ClientBaseBlueprint = require(script.Parent.BaseBlueprint)

local Chest = {}
Chest.__index = Chest
setmetatable(Chest, { __index = ClientBaseBlueprint })

function Chest.new(data)
	local self = ClientBaseBlueprint.new(data)
	setmetatable(self, Chest)
	return self
end

function Chest:_OnInteract(player)
	local UIController = Knit.GetController("UIController")
	local InventoryController = Knit.GetController("InventoryController")
	local ChestController = Knit.GetController("ChestController")

	if UIController and InventoryController and ChestController then
		UIController:SetCurrentFrame("Chest")
		InventoryController:OpenBackpack()
		ChestController:OpenChest(self.Id)
	end
end

return Chest
