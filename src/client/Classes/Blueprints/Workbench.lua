local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ClientBaseBlueprint = require(script.Parent.BaseBlueprint)

local Workbench = {}
Workbench.__index = Workbench
setmetatable(Workbench, { __index = ClientBaseBlueprint })

function Workbench.new(data)
	local self = ClientBaseBlueprint.new(data)
	setmetatable(self, Workbench)
	return self
end

function Workbench:_OnInteract(player)
	local UIController = Knit.GetController("UIController")
	local InventoryController = Knit.GetController("InventoryController")
	local CraftingController = Knit.GetController("CraftingController")

	if UIController and InventoryController and CraftingController then
		UIController:SetCurrentFrame("Workbench")
		InventoryController:OpenBackpack()
		CraftingController:StartSession(self.Id)
	end
end

return Workbench
