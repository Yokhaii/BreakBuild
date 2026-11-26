--[=[
	Cow (client) - BaseMob visuals (Idle / Walk / Run animations)
	Override BaseMob methods here for Cow-specific visuals.
]=]

local BaseMob = require(script.Parent.BaseMob)

local Cow = {}
Cow.__index = Cow
setmetatable(Cow, { __index = BaseMob })

function Cow.new(model: Model, data)
	local self = BaseMob.new(model, data)
	setmetatable(self, Cow)
	return self
end

return Cow
