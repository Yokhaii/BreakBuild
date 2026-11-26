--[=[
	Cow (server) - passive mob: wanders around its herd, flees when hurt (BaseMob defaults)
	Stats, speeds and patrol / flee tuning live in Shared.Data.MobData.Cow.
	Override BaseMob hooks here for Cow-specific behavior.
]=]

local BaseMob = require(script.Parent.BaseMob)

local Cow = {}
Cow.__index = Cow
setmetatable(Cow, { __index = BaseMob })

function Cow.new(id: number, mobType: string, data, model: Model, options)
	local self = BaseMob.new(id, mobType, data, model, options)
	setmetatable(self, Cow)
	return self
end

return Cow
