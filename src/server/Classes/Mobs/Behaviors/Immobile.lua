--[=[
	Immobile - the mob stands still (frozen dev spawns, idle bosses, stunned mobs...)
	params:
	  faceTowards  Vector3?  position to look at
]=]

local BaseBehavior = require(script.Parent.BaseBehavior)

local Immobile = {}
Immobile.__index = Immobile
setmetatable(Immobile, { __index = BaseBehavior })

function Immobile.new(mob, params)
	local self = BaseBehavior.new(mob, params)
	setmetatable(self, Immobile)
	return self
end

function Immobile:Enter()
	self.Mover:Stop()
	self.Mover:FaceTowards(self.Params.faceTowards)
end

return Immobile
