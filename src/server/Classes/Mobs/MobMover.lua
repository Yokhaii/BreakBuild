--[=[
	MobMover - moves one mob with physics, nothing else (no decisions, no pathfinding)
	Behaviors tell it where to go and how fast; it drives the mob every Heartbeat:
	  - LinearVelocity (plane mode, X/Z only) pushes the assembly, gravity keeps working on Y
	  - AlignOrientation keeps the mob upright and turned toward where it walks
	  - Step-up: a frictionless ball can't roll over an edge, so while moving it compares the
	    ground just ahead with the ground under it. When the ground ahead is higher (up to
	    jumpHeight), a vertical LinearVelocity lifts the ball onto it BEFORE the ball touches
	    the edge, and holds it there until the ball is over the top. Off the rest of the time,
	    so on flat ground the ball just rests on the ground.
	The round CollidePart has no friction, so the speed is the same on every ground.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)
local MobRaycast = require(script.Parent.Navigation.MobRaycast)

local WALKABLE_NORMAL_Y = 0.7
local STEP_FORCE_GRAVITIES = 3 -- step-up force = this many times the mob's weight

local MobMover = {}
MobMover.__index = MobMover

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

function MobMover.new(root: BasePart, collidePart: BasePart?, jumpHeight: number?)
	local self = setmetatable({}, MobMover)
	self.Root = root
	self.CollidePart = collidePart or root
	self.JumpHeight = jumpHeight or MobConfig.DefaultJumpHeight

	self.Mode = "Stop" -- "Stop" | "Position" | "Direction"
	self.TargetPosition = nil
	self.ArriveRadius = MobConfig.ArriveRadius
	self.Direction = nil
	self.Speed = 0
	self.FaceTarget = nil -- optional position to look at instead of the walk direction
	self.Yaw = select(2, root.CFrame:ToOrientation())
	self.Arrived = false
	self.StuckTime = 0
	self.StepTargetY = nil -- feet height the step-up is lifting the mob to (nil = off)
	self.StepHoldUntil = 0

	local attachment = Instance.new("Attachment")
	attachment.Name = "MoverAttachment"
	attachment.Parent = root

	local mass = root.AssemblyMass

	local linearVelocity = Instance.new("LinearVelocity")
	linearVelocity.Name = "MoverVelocity"
	linearVelocity.Attachment0 = attachment
	linearVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	linearVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	linearVelocity.PrimaryTangentAxis = Vector3.xAxis
	linearVelocity.SecondaryTangentAxis = Vector3.zAxis
	linearVelocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	linearVelocity.MaxForce = mass * MobConfig.MaxAcceleration
	linearVelocity.PlaneVelocity = Vector2.zero
	linearVelocity.Parent = root
	self.LinearVelocity = linearVelocity

	local stepVelocity = Instance.new("LinearVelocity")
	stepVelocity.Name = "MoverStepVelocity"
	stepVelocity.Attachment0 = attachment
	stepVelocity.RelativeTo = Enum.ActuatorRelativeTo.World
	stepVelocity.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	stepVelocity.LineDirection = Vector3.yAxis
	stepVelocity.ForceLimitMode = Enum.ForceLimitMode.Magnitude
	stepVelocity.MaxForce = mass * Workspace.Gravity * STEP_FORCE_GRAVITIES
	stepVelocity.LineVelocity = 0
	stepVelocity.Enabled = false
	stepVelocity.Parent = root
	self.StepVelocity = stepVelocity

	local alignOrientation = Instance.new("AlignOrientation")
	alignOrientation.Name = "MoverOrientation"
	alignOrientation.Mode = Enum.OrientationAlignmentMode.OneAttachment
	alignOrientation.Attachment0 = attachment
	alignOrientation.RigidityEnabled = false
	alignOrientation.MaxTorque = math.huge
	alignOrientation.Responsiveness = MobConfig.TurnResponsiveness
	alignOrientation.CFrame = CFrame.Angles(0, self.Yaw, 0)
	alignOrientation.Parent = root
	self.AlignOrientation = alignOrientation

	return self
end

--|| Commands (called by behaviors) ||--

-- Walk to a world position at `speed` studs/s (slows down near it, then stops
-- `arriveRadius` studs from it, default MobConfig.ArriveRadius)
function MobMover:MoveTo(position: Vector3, speed: number, arriveRadius: number?)
	self.Mode = "Position"
	self.TargetPosition = position
	self.ArriveRadius = arriveRadius or MobConfig.ArriveRadius
	self.Speed = speed
	self.Arrived = false
end

-- Keep walking along a direction at `speed` studs/s
function MobMover:MoveInDirection(direction: Vector3, speed: number)
	local planar = flat(direction)
	if planar.Magnitude < 1e-3 then
		self:Stop()
		return
	end
	self.Mode = "Direction"
	self.Direction = planar.Unit
	self.Speed = speed
	self.Arrived = false
end

function MobMover:Stop()
	self.Mode = "Stop"
	self.TargetPosition = nil
	self.Direction = nil
	self.Speed = 0
	self.StuckTime = 0
end

-- Look at a position (nil = look where the mob walks)
function MobMover:FaceTowards(position: Vector3?)
	self.FaceTarget = position
end

--|| State ||--

function MobMover:GetPosition(): Vector3
	return self.Root.Position
end

function MobMover:GetPlanarSpeed(): number
	return flat(self.Root.AssemblyLinearVelocity).Magnitude
end

-- Speed currently asked by the behavior (0 when stopped or arrived)
function MobMover:GetCommandedSpeed(): number
	if self.Mode == "Stop" or self.Arrived then
		return 0
	end
	return self.Speed
end

function MobMover:HasArrived(): boolean
	return self.Arrived
end

-- True after StuckTime seconds of moving much slower than asked (wall, other mob...)
function MobMover:IsStuck(): boolean
	return self.StuckTime >= MobConfig.StuckTime
end

--|| Heartbeat ||--

function MobMover:Step(dt: number)
	local position = self.Root.Position
	local velocity = Vector3.zero

	if self.Mode == "Position" and not self.Arrived then
		local offset = flat(self.TargetPosition - position)
		local distance = offset.Magnitude
		if distance <= self.ArriveRadius then
			self.Arrived = true
		else
			local slowDown = math.clamp((distance - self.ArriveRadius) / MobConfig.SlowDownRadius, 0.35, 1)
			velocity = offset.Unit * self.Speed * slowDown
		end
	elseif self.Mode == "Direction" then
		velocity = self.Direction * self.Speed
	end

	self.LinearVelocity.PlaneVelocity = Vector2.new(velocity.X, velocity.Z)
	self:_UpdateStepUp(velocity)

	-- Stuck detection
	if velocity.Magnitude > 0.1 and self:GetPlanarSpeed() < velocity.Magnitude * MobConfig.StuckSpeedRatio then
		self.StuckTime += dt
	else
		self.StuckTime = 0
	end

	-- Facing: the look target, else the walk direction, else keep the current yaw
	local facing = nil
	if self.FaceTarget then
		facing = flat(self.FaceTarget - position)
	elseif velocity.Magnitude > 0.1 then
		facing = velocity
	end
	if facing and facing.Magnitude > 1e-3 then
		self.Yaw = math.atan2(-facing.X, -facing.Z)
		self.AlignOrientation.CFrame = CFrame.Angles(0, self.Yaw, 0)
	end
end

-- Lift the mob onto a higher ground just ahead (up to JumpHeight), see the header
function MobMover:_UpdateStepUp(velocity: Vector3)
	local now = os.clock()
	local center = self.CollidePart.Position
	local radius = self.CollidePart.Size.Y / 2
	local feetY = center.Y - radius
	local speed = velocity.Magnitude

	if speed > 0.1 then
		local params = MobRaycast.GetParams()
		local under = Workspace:Raycast(center, Vector3.new(0, -(radius + self.JumpHeight + 1), 0), params)
		local grounded = under ~= nil and feetY - under.Position.Y <= MobConfig.GroundedDistance

		if under and under.Position.Y >= (self.StepTargetY or math.huge) - MobConfig.StepClearance - MobConfig.MinLedgeHeight then
			self.StepTargetY = nil -- over the top of the ledge
		end

		if under and (grounded or self.StepTargetY) then
			-- Ground just past the ball's front, probed from above the highest climbable ledge.
			-- A wall taller than that has the probe start inside it, so it is never climbed.
			local groundY = under.Position.Y
			local reach = radius + MobConfig.StepLookAhead + speed * MobConfig.StepLookAheadPerSpeed
			local probeTop = groundY + self.JumpHeight + MobConfig.StepClearance
			local origin = Vector3.new(center.X, probeTop, center.Z) + velocity.Unit * reach
			local hit = Workspace:Raycast(origin, Vector3.new(0, -(probeTop - groundY - MobConfig.MinLedgeHeight), 0), params)
			if hit and hit.Normal.Y >= WALKABLE_NORMAL_Y and hit.Position.Y - groundY <= self.JumpHeight then
				self.StepTargetY = math.max(self.StepTargetY or -math.huge, hit.Position.Y + MobConfig.StepClearance)
				-- Hold long enough for the whole ball to pass the edge (thin ledges)
				self.StepHoldUntil = now + (2 * radius + reach) / speed
			end
		end
	else
		self.StepTargetY = nil
	end

	if self.StepTargetY and now > self.StepHoldUntil then
		self.StepTargetY = nil
	end

	if self.StepTargetY then
		local rise = math.clamp((self.StepTargetY - feetY) * MobConfig.StepGain, -MobConfig.StepSpeed, MobConfig.StepSpeed)
		self.StepVelocity.LineVelocity = rise
		self.StepVelocity.Enabled = true
	else
		self.StepVelocity.Enabled = false
	end
end

function MobMover:Destroy()
	self.LinearVelocity:Destroy()
	self.StepVelocity:Destroy()
	self.AlignOrientation:Destroy()
end

return MobMover
