--[=[
	Chicken (client) - BaseMob visuals (Idle / Walk / Run animations)
	Override BaseMob methods here for Chicken-specific visuals.
]=]

local BaseMob = require(script.Parent.BaseMob)

local Chicken = {}
Chicken.__index = Chicken
setmetatable(Chicken, { __index = BaseMob })

function Chicken.new(model: Model, data)
	local self = BaseMob.new(model, data)
	setmetatable(self, Chicken)
	return self
end

return Chicken
