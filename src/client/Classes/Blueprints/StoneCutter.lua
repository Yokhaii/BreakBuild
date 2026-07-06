local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ClientBaseBlueprint = require(script.Parent.BaseBlueprint)

local StoneCutter = {}
StoneCutter.__index = StoneCutter
setmetatable(StoneCutter, { __index = ClientBaseBlueprint })

function StoneCutter.new(data)
	local self = ClientBaseBlueprint.new(data)
	setmetatable(self, StoneCutter)
	return self
end

function StoneCutter:OnCrafting(progress: number)
	-- Add StoneCutter-specific sounds or fx here when crafting is active.
end

function StoneCutter:OnCraftReceived()
	-- Add StoneCutter-specific sounds or fx here when the player collects a finished craft.
end

function StoneCutter:_OnInteract(player)
	local UIController = Knit.GetController("UIController")
	local InventoryController = Knit.GetController("InventoryController")
	local CraftingController = Knit.GetController("CraftingController")

	if UIController and InventoryController and CraftingController then
		UIController:SetCurrentFrame("StoneCutter")
		InventoryController:OpenBackpack()
		CraftingController:StartSession(self.Id)
	end
end

return StoneCutter
