--[=[
	Patrolling - walk, stop, wait, walk again
	Without waypoints the mob wanders to random ground points around its home position
	(passive animals); with waypoints it loops through them (guards, bosses...).
	params:
	  waypoints  {Vector3}?          fixed route, looped
	  radius     number?             wander radius (default: mob data patrol.radius)
	  waitTime   {min, max}?         seconds idling between walks (default: patrol.waitTime)
	  speedMode  "Walk" | "Run"?     default "Walk"
	Never finishes by itself.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BaseBehavior = require(script.Parent.BaseBehavior)
local Steering = require(script.Parent.Parent.Navigation.Steering)
local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)

local Patrolling = {}
Patrolling.__index = Patrolling
setmetatable(Patrolling, { __index = BaseBehavior })

local BLOCKED_WAIT = { 0.5, 1.5 } -- shorter wait when the way was blocked

function Patrolling.new(mob, params)
	local self = BaseBehavior.new(mob, params)
	setmetatable(self, Patrolling)

	local patrol = mob.Data.patrol or {}
	self.Radius = self.Params.radius or patrol.radius or 20
	self.WaitTime = self.Params.waitTime or patrol.waitTime or { 3, 8 }
	self.Speed = mob:GetSpeed(self.Params.speedMode or "Walk")
	-- Mobs living on the Outside Ground stay on it; mobs placed elsewhere (dev spawns in a
	-- building zone...) wander on any walkable surface
	self.AnySurface = not Steering.IsOnGroundTag(mob.HomePosition)
	self.WaypointIndex = 0
	self.Target = nil
	self.WaitLeft = 0
	return self
end

function Patrolling:Enter()
	self.Mover:Stop()
	self:_Wait(self.WaitTime)
end

function Patrolling:_Wait(range)
	self.Target = nil
	self.Mover:Stop()
	self.WaitLeft = range[1] + math.random() * (range[2] - range[1])
end

function Patrolling:_PickTarget(): Vector3?
	local waypoints = self.Params.waypoints
	if waypoints and #waypoints > 0 then
		self.WaypointIndex = self.WaypointIndex % #waypoints + 1
		return waypoints[self.WaypointIndex]
	end
	return Steering.RandomGroundPoint(self.Mob.HomePosition, self.Radius, self.AnySurface, self.Mob.Habitat)
end

function Patrolling:Update(dt: number)
	if not self.Target then
		self.WaitLeft -= dt
		if self.WaitLeft > 0 then return end

		self.Target = self:_PickTarget()
		if not self.Target then
			self:_Wait(BLOCKED_WAIT)
			return
		end
		self.Mover:MoveTo(self.Target, self.Speed)
		return
	end

	if self.Mover:HasArrived() then
		self:_Wait(self.WaitTime)
		return
	end

	local direction = self.Target - self.Mover:GetPosition()
	direction = Vector3.new(direction.X, 0, direction.Z)
	local lookAhead = math.min(MobConfig.LookAheadDistance, direction.Magnitude)
	if self.Mover:IsStuck() or not Steering.IsDirectionClear(self.Mob, direction, lookAhead) then
		self:_Wait(BLOCKED_WAIT)
	end
end

return Patrolling
