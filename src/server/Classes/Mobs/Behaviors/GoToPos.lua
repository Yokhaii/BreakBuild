--[=[
	GoToPos - go to a specific position, then finish
	Straight line when free, else a computed path (BaseBehavior:NavigateTo).
	params:
	  position   Vector3            where to go (required)
	  speedMode  "Walk" | "Run"?    default "Walk"
	  timeout    number?            seconds before giving up (default 30)
	  arriveDistance  number?       studs from the position that count as arrived (default 2)
	  onArrived  (mob) -> ()?       called once when the position is reached
]=]

local BaseBehavior = require(script.Parent.BaseBehavior)

local GoToPos = {}
GoToPos.__index = GoToPos
setmetatable(GoToPos, { __index = BaseBehavior })

local DEFAULT_TIMEOUT = 30
local ARRIVE_DISTANCE = 2

function GoToPos.new(mob, params)
	local self = BaseBehavior.new(mob, params)
	setmetatable(self, GoToPos)
	self.Speed = mob:GetSpeed(self.Params.speedMode or "Walk")
	self.TimeLeft = self.Params.timeout or DEFAULT_TIMEOUT
	self.ArriveDistance = self.Params.arriveDistance or ARRIVE_DISTANCE
	return self
end

function GoToPos:Enter()
	if not self.Params.position then
		self:Finish()
	end
end

function GoToPos:Update(dt: number)
	local goal = self.Params.position
	self.TimeLeft -= dt
	if self.TimeLeft <= 0 then
		self:Finish()
		return
	end

	local offset = goal - self.Mover:GetPosition()
	if Vector3.new(offset.X, 0, offset.Z).Magnitude <= self.ArriveDistance then
		self.Mover:Stop()
		if self.Params.onArrived then
			self.Params.onArrived(self.Mob)
		end
		self:Finish()
		return
	end

	self:NavigateTo(goal, self.Speed, self.ArriveDistance)
end

return GoToPos
