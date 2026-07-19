local ServerBaseBlueprint = require(script.Parent.BaseBlueprint)

local Chest = {}
Chest.__index = Chest
setmetatable(Chest, { __index = ServerBaseBlueprint })

function Chest.new(data)
	local self = ServerBaseBlueprint.new(data)
	setmetatable(self, Chest)

	self.IsActive = false

	self.OnCompleted:Connect(function()
		self:_OnChestCompleted()
	end)

	if self.CompletedAt > 0 then
		self:_OnChestCompleted()
	elseif self:IsComplete() then
		self.CompletedAt = os.time()
		self:_OnChestCompleted()
	end

	return self
end

function Chest:_OnChestCompleted()
	self.IsActive = true
end

function Chest:CanPlayerUse(playerId: number): boolean
	return self.IsActive and playerId == self.OwnerId
end

function Chest:DestroyModel()
	self.IsActive = false
	ServerBaseBlueprint.DestroyModel(self)
end

return Chest
