local ServerBaseBlueprint = require(script.Parent.BaseBlueprint)

local LogCutter = {}
LogCutter.__index = LogCutter
setmetatable(LogCutter, { __index = ServerBaseBlueprint })

function LogCutter.new(data)
	local self = ServerBaseBlueprint.new(data)
	setmetatable(self, LogCutter)

	self.IsActive = false

	self.OnCompleted:Connect(function()
		self:_OnLogCutterCompleted()
	end)

	if self.CompletedAt > 0 then
		self:_OnLogCutterCompleted()
	end

	return self
end

function LogCutter:_OnLogCutterCompleted()
	self.IsActive = true
end

function LogCutter:CanPlayerUse(playerId: number): boolean
	if not self.IsActive then return false end
	return playerId == self.OwnerId
end

function LogCutter:DestroyModel()
	self.IsActive = false
	ServerBaseBlueprint.DestroyModel(self)
end

return LogCutter
