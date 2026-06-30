local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ClientBaseBlueprint = require(script.Parent.BaseBlueprint)

local Furnace = {}
Furnace.__index = Furnace
setmetatable(Furnace, { __index = ClientBaseBlueprint })

function Furnace.new(data)
	local self = ClientBaseBlueprint.new(data)
	setmetatable(self, Furnace)
	return self
end

function Furnace:_OnInteract(player)
	local UIController = Knit.GetController("UIController")
	local InventoryController = Knit.GetController("InventoryController")
	local CraftingController = Knit.GetController("CraftingController")

	if UIController and InventoryController and CraftingController then
		UIController:SetCurrentFrame("Furnace")
		InventoryController:OpenBackpack()
		CraftingController:StartSession(self.Id)
	end
end

return Furnace
