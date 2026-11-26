--[=[
	Chicken (server) - passive mob: wanders around its herd, flees when hurt (BaseMob defaults)
	Stats, speeds and patrol / flee tuning live in Shared.Data.MobData.Chicken.
	Override BaseMob hooks here for Chicken-specific behavior.
]=]

local BaseMob = require(script.Parent.BaseMob)

local Chicken = {}
Chicken.__index = Chicken
setmetatable(Chicken, { __index = BaseMob })

function Chicken.new(id: number, mobType: string, data, model: Model, options)
	local self = BaseMob.new(id, mobType, data, model, options)
	setmetatable(self, Chicken)
	return self
end

return Chicken
