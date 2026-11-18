local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ClientBaseBlueprint = require(script.Parent.BaseBlueprint)

local Furnace = {}
Furnace.__index = Furnace
setmetatable(Furnace, { __index = ClientBaseBlueprint })

function Furnace.new(data)
	local self = ClientBaseBlueprint.new(data)
	setmetatable(self, Furnace)
	self._fireActive = false
	return self
end

local function setFireEnabled(model, enabled: boolean)
	if not model then return end
	-- Every ParticleEmitter under the Fire part
	local fire = model:FindFirstChild("Fire", true)
	if fire then
		for _, v in ipairs(fire:GetDescendants()) do
			if v:IsA("ParticleEmitter") then v.Enabled = enabled end
		end
	end
	local light = model:FindFirstChildWhichIsA("Light", true)
	if light then light.Enabled = enabled end
end

function Furnace:OnCrafting(progress: number)
	if self._fireActive then return end
	self._fireActive = true
	setFireEnabled(self.Model, true)
end

function Furnace:OnCraftReceived()
	self._fireActive = false
	setFireEnabled(self.Model, false)
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
