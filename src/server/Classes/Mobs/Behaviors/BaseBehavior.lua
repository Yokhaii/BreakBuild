--[=[
	BaseBehavior - parent of every movement behavior
	A behavior decides WHERE the mob goes; it only moves it through mob.Mover (MobMover).
	The mob runs one behavior at a time (BaseMob:SetBehavior):
	  Enter()        once when it starts
	  Update(dt)     MobConfig.ThinkRate times per second while the mob is enabled and awake
	  Exit()         once when it is replaced
	Call self:Finish() when done; the mob then goes back to its default behavior.
]=]

local PathFollower = require(script.Parent.Parent.Navigation.PathFollower)
local Steering = require(script.Parent.Parent.Navigation.Steering)

local BaseBehavior = {}
BaseBehavior.__index = BaseBehavior

function BaseBehavior.new(mob, params)
	local self = setmetatable({}, BaseBehavior)
	self.Mob = mob
	self.Mover = mob.Mover
	self.Params = params or {}
	self.Finished = false
	self.PathFollower = nil
	return self
end

function BaseBehavior:Enter() end

function BaseBehavior:Update(_dt: number) end

function BaseBehavior:Exit()
	if self.PathFollower then
		self.PathFollower:Destroy()
		self.PathFollower = nil
	end
	self.Mover:FaceTowards(nil)
	self.Mover:Stop()
end

function BaseBehavior:Finish()
	self.Finished = true
end

-- Walk toward `goal`: straight line when it is free, else along a computed path.
-- arriveRadius: stop this far from the goal (MobMover default otherwise).
-- Returns false while no way is known yet (the mob waits in place).
function BaseBehavior:NavigateTo(goal: Vector3, speed: number, arriveRadius: number?): boolean
	if Steering.HasLineOfSight(self.Mob, goal) then
		self.Mover:MoveTo(goal, speed, arriveRadius)
		return true
	end

	self.PathFollower = self.PathFollower or PathFollower.new(self.Mob)
	self.PathFollower:SetGoal(goal)
	local waypoint = self.PathFollower:GetNextWaypoint()
	if waypoint then
		self.Mover:MoveTo(waypoint, speed)
		return true
	end

	self.Mover:Stop()
	return false
end

return BaseBehavior
