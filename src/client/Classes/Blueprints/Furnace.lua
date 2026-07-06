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

local function getFireEffects(model)
	if not model then return nil, nil end
	local particle, light
	for _, v in ipairs(model:GetDescendants()) do
		if not particle and v:IsA("ParticleEmitter") then particle = v end
		if not light and v:IsA("Light") then light = v end
		if particle and light then break end
	end
	return particle, light
end

function Furnace:OnCrafting(progress: number)
	if self._fireActive then return end
	self._fireActive = true
	local particle, light = getFireEffects(self.Model)
	if particle then particle.Enabled = true end
	if light then light.Enabled = true end
end

function Furnace:OnCraftReceived()
	self._fireActive = false
	local particle, light = getFireEffects(self.Model)
	if particle then particle.Enabled = false end
	if light then light.Enabled = false end
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
