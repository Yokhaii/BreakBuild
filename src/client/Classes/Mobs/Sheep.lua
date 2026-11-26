--[=[
	Sheep (client) - BaseMob visuals (Idle / Walk / Run animations)
	Override BaseMob methods here for Sheep-specific visuals.
]=]

local BaseMob = require(script.Parent.BaseMob)

local Sheep = {}
Sheep.__index = Sheep
setmetatable(Sheep, { __index = BaseMob })

function Sheep.new(model: Model, data)
	local self = BaseMob.new(model, data)
	setmetatable(self, Sheep)
	return self
end

return Sheep
