local ServerBaseBlueprint = require(script.Parent.BaseBlueprint)

local StoneCutter = {}
StoneCutter.__index = StoneCutter
setmetatable(StoneCutter, { __index = ServerBaseBlueprint })

function StoneCutter.new(data)
	local self = ServerBaseBlueprint.new(data)
	setmetatable(self, StoneCutter)

	self.IsActive = false

	self.OnCompleted:Connect(function()
		self:_OnStoneCutterCompleted()
	end)

	if self.CompletedAt > 0 then
		self:_OnStoneCutterCompleted()
	elseif self:IsComplete() then
		self.CompletedAt = os.time()
		self:_OnStoneCutterCompleted()
	end

	return self
end

function StoneCutter:_OnStoneCutterCompleted()
	self.IsActive = true
end

function StoneCutter:CanPlayerUse(playerId: number): boolean
	if not self.IsActive then
		return false
	end

	return playerId == self.OwnerId
end

function StoneCutter:DestroyModel()
	self.IsActive = false
	ServerBaseBlueprint.DestroyModel(self)
end

return StoneCutter
