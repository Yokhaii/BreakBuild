--[=[
	Sheep (server) - passive mob: wanders around its herd, flees when hurt (BaseMob defaults)
	Stats, speeds and patrol / flee tuning live in Shared.Data.MobData.Sheep.
	Override BaseMob hooks here for Sheep-specific behavior.
]=]

local BaseMob = require(script.Parent.BaseMob)

local Sheep = {}
Sheep.__index = Sheep
setmetatable(Sheep, { __index = BaseMob })

function Sheep.new(id: number, mobType: string, data, model: Model, options)
	local self = BaseMob.new(id, mobType, data, model, options)
	setmetatable(self, Sheep)
	return self
end

return Sheep
