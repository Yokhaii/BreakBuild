local ServerBaseBlueprint = require(script.Parent.BaseBlueprint)

local Furnace = {}
Furnace.__index = Furnace
setmetatable(Furnace, { __index = ServerBaseBlueprint })

function Furnace.new(data)
	local self = ServerBaseBlueprint.new(data)
	setmetatable(self, Furnace)

	self.IsActive = false

	self.OnCompleted:Connect(function()
		self:_OnFurnaceCompleted()
	end)

	if self.CompletedAt > 0 then
		self:_OnFurnaceCompleted()
	elseif self:IsComplete() then
		self.CompletedAt = os.time()
		self:_OnFurnaceCompleted()
	end

	return self
end

function Furnace:_OnFurnaceCompleted()
	self.IsActive = true
end

function Furnace:CanPlayerUse(playerId: number): boolean
	if not self.IsActive then
		return false
	end

	return playerId == self.OwnerId
end

function Furnace:DestroyModel()
	self.IsActive = false
	ServerBaseBlueprint.DestroyModel(self)
end

return Furnace
