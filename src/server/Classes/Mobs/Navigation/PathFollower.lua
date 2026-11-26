--[=[
	PathFollower - PathfindingService for one mob, used when the straight line is blocked
	SetGoal(position) computes a path in the background (never yields the caller);
	GetNextWaypoint() gives the next point to walk to, or nil while there is no path.
	Path costs come from the mob's habitat (MobConfig.HabitatPathCosts): ground mobs never
	path through water (PathfindingModifier "Water" added by Navigation/Water).
]=]

local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)

local PathFollower = {}
PathFollower.__index = PathFollower

local GOAL_MOVED_DISTANCE = 4 -- studs the goal must move before a new path is computed

function PathFollower.new(mob)
	local self = setmetatable({}, PathFollower)
	self.Mob = mob
	local radius = mob.CollidePart and mob.CollidePart.Size.X / 2 or 2
	self.Path = PathfindingService:CreatePath({
		AgentRadius = radius,
		AgentHeight = radius * 2,
		AgentCanJump = false,
		WaypointSpacing = 4,
		Costs = MobConfig.HabitatPathCosts[mob.Habitat] or {},
	})
	self.Waypoints = nil
	self.Index = 0
	self.Goal = nil
	self.LastComputeAt = 0
	self.Computing = false
	self.Destroyed = false
	return self
end

function PathFollower:SetGoal(goal: Vector3)
	if self.Computing then return end
	-- Recompute when there is no path or the goal moved, at most once per interval
	local now = os.clock()
	if now - self.LastComputeAt < MobConfig.PathRecomputeInterval then return end
	if self.Waypoints and self.Goal and (goal - self.Goal).Magnitude <= GOAL_MOVED_DISTANCE then return end

	self.Goal = goal
	self.LastComputeAt = now
	self.Computing = true
	task.spawn(function()
		local ok = pcall(function()
			self.Path:ComputeAsync(self.Mob.Root.Position, goal)
		end)
		self.Computing = false
		if self.Destroyed then return end
		if ok and self.Path.Status == Enum.PathStatus.Success then
			self.Waypoints = self.Path:GetWaypoints()
			self.Index = 2 -- waypoint 1 is the start position
		else
			self.Waypoints = nil
		end
	end)
end

function PathFollower:GetNextWaypoint(): Vector3?
	if not self.Waypoints then return nil end
	local position = self.Mob.Root.Position
	while self.Index <= #self.Waypoints do
		local waypoint = self.Waypoints[self.Index].Position
		local offset = Vector3.new(waypoint.X - position.X, 0, waypoint.Z - position.Z)
		if offset.Magnitude > MobConfig.WaypointReachedDistance then
			return waypoint
		end
		self.Index += 1
	end
	return nil
end

function PathFollower:HasPath(): boolean
	return self.Waypoints ~= nil
end

function PathFollower:Destroy()
	self.Destroyed = true
	self.Waypoints = nil
end

return PathFollower
