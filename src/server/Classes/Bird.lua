--[=[
	Bird - the bird living in a BirdNest (server)
	Sits in the nest playing Bird_Idle, flies its trips playing Bird_Fly.
	Animations go through the Animation package (Shared.AnimationDataFolder.Bird_*).
	The flight follows a smooth path on Heartbeat by moving the anchored Bird_Body.

	Trip: take off -> one loop around the nest -> fly away (hidden while away)
	Back: appear far away -> one loop around the nest -> land
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Animation = require(ReplicatedStorage.Packages.Animation)

local Bird = {}
Bird.__index = Bird

local MODEL_NAME = "Bird" -- ReplicatedStorage.Assets.Bird
local IDLE_ANIMATION = "Bird_Idle"
local FLY_ANIMATION = "Bird_Fly"

local FLIGHT_SPEED = 24 -- studs per second
local TAKEOFF_OFFSET = Vector3.new(0, 3, 0)
local TAKEOFF_DISTANCE = 3
local CIRCLE_RADIUS = 14
local CIRCLE_HEIGHT = 10
local CIRCLE_POINTS = 8
local AWAY_DISTANCE = 160
local AWAY_HEIGHT = 60
local SAMPLES_PER_SEGMENT = 8
local MAX_PITCH = math.rad(25)

--|| Path helpers ||--

-- Catmull-Rom through the points, sampled into a polyline so the bird flies at constant speed
local function buildPath(points)
	local samples = { points[1] }
	for i = 1, #points - 1 do
		local p0 = points[math.max(i - 1, 1)]
		local p1, p2 = points[i], points[i + 1]
		local p3 = points[math.min(i + 2, #points)]
		for step = 1, SAMPLES_PER_SEGMENT do
			local t = step / SAMPLES_PER_SEGMENT
			local t2, t3 = t * t, t * t * t
			table.insert(samples, 0.5 * (2 * p1 + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3))
		end
	end

	local lengths = { 0 }
	for i = 2, #samples do
		lengths[i] = lengths[i - 1] + (samples[i] - samples[i - 1]).Magnitude
	end

	return { samples = samples, lengths = lengths, length = lengths[#lengths] }
end

-- Position and flight direction after `distance` studs along the path
local function samplePath(path, distance: number): (Vector3, Vector3)
	local index = 2
	while index < #path.samples and path.lengths[index] < distance do
		index = index + 1
	end

	local from, to = path.samples[index - 1], path.samples[index]
	local segmentLength = path.lengths[index] - path.lengths[index - 1]
	local alpha = segmentLength > 0 and (distance - path.lengths[index - 1]) / segmentLength or 1
	return from:Lerp(to, alpha), to - from
end

-- One loop around the nest, starting at `angle`
local function circlePoints(center: Vector3, angle: number): { Vector3 }
	local points = {}
	for k = 0, CIRCLE_POINTS do
		local a = angle + k * 2 * math.pi / CIRCLE_POINTS
		table.insert(points, center + Vector3.new(math.cos(a), 0, math.sin(a)) * CIRCLE_RADIUS)
	end
	return points
end

local function awayPoint(center: Vector3, angle: number): Vector3
	return center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * AWAY_DISTANCE + Vector3.new(0, AWAY_HEIGHT, 0)
end

--|| Constructor ||--

-- nestCFrame: where the bird stands in the nest (feet position, facing its LookVector)
function Bird.new(nestCFrame: CFrame, parent: Instance)
	local template = ReplicatedStorage.Assets:FindFirstChild(MODEL_NAME)
	if not template then
		warn("[Bird] Model not found at ReplicatedStorage.Assets." .. MODEL_NAME)
		return nil
	end

	local self = setmetatable({}, Bird)
	self.NestCFrame = nestCFrame
	self.Parent = parent
	self.IsHome = true
	self.Destroyed = false

	self.Model = template:Clone()
	self.Model:PivotTo(nestCFrame)
	self.Model.Parent = parent

	-- Every trip has the same length, so the return flight always takes the same time
	self.DepartureDuration = buildPath(self:_DeparturePoints(0)).length / FLIGHT_SPEED
	self.ReturnDuration = buildPath(self:_ReturnPoints(0)).length / FLIGHT_SPEED

	Animation:PreloadAnimOnServer(self.Model, IDLE_ANIMATION)
	Animation:PreloadAnimOnServer(self.Model, FLY_ANIMATION)
	Animation:PlayAnimOnServer(self.Model, IDLE_ANIMATION)

	return self
end

--|| Private ||--

function Bird:_DeparturePoints(angle: number): { Vector3 }
	local nest = self.NestCFrame.Position
	local center = nest + Vector3.new(0, CIRCLE_HEIGHT, 0)
	local points = { nest, nest + TAKEOFF_OFFSET + self.NestCFrame.LookVector * TAKEOFF_DISTANCE }
	for _, point in ipairs(circlePoints(center, angle)) do
		table.insert(points, point)
	end
	table.insert(points, awayPoint(center, angle))
	return points
end

function Bird:_ReturnPoints(angle: number): { Vector3 }
	local nest = self.NestCFrame.Position
	local center = nest + Vector3.new(0, CIRCLE_HEIGHT, 0)
	local points = { awayPoint(center, angle) }
	for _, point in ipairs(circlePoints(center, angle)) do
		table.insert(points, point)
	end
	-- Come down from behind so the bird lands facing the nest's direction
	table.insert(points, nest + TAKEOFF_OFFSET - self.NestCFrame.LookVector * TAKEOFF_DISTANCE)
	table.insert(points, nest)
	return points
end

-- Facing the flight direction, nose tilted up/down a little
function Bird:_FlightCFrame(position: Vector3, direction: Vector3, previous: CFrame): CFrame
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 1e-3 then
		return previous.Rotation + position
	end

	local pitch = math.clamp(math.atan2(direction.Y, flat.Magnitude), -MAX_PITCH, MAX_PITCH)
	return CFrame.lookAt(position, position + flat) * CFrame.Angles(pitch, 0, 0)
end

function Bird:_Fly(points: { Vector3 })
	local path = buildPath(points)
	local travelled = 0
	local cframe = self.Model:GetPivot()

	while travelled < path.length and not self.Destroyed do
		local dt = RunService.Heartbeat:Wait()
		travelled = math.min(travelled + FLIGHT_SPEED * dt, path.length)
		local position, direction = samplePath(path, travelled)
		cframe = self:_FlightCFrame(position, direction, cframe)
		self.Model:PivotTo(cframe)
	end
end

--|| Public ||--

-- Yields until the bird is gone (DepartureDuration)
function Bird:FlyAway()
	if self.Destroyed or not self.IsHome then return end
	self.IsHome = false

	Animation:StopAnimOnServer(self.Model, IDLE_ANIMATION, 0.2)
	Animation:PlayAnimOnServer(self.Model, FLY_ANIMATION)
	self:_Fly(self:_DeparturePoints(math.random() * 2 * math.pi))

	if self.Destroyed then return end
	Animation:StopAnimOnServer(self.Model, FLY_ANIMATION)
	self.Model.Parent = nil
end

-- Yields until the bird has landed in the nest (ReturnDuration)
function Bird:FlyBack()
	if self.Destroyed or self.IsHome then return end

	local points = self:_ReturnPoints(math.random() * 2 * math.pi)
	self.Model:PivotTo(CFrame.new(points[1]))
	self.Model.Parent = self.Parent
	Animation:PlayAnimOnServer(self.Model, FLY_ANIMATION)
	self:_Fly(points)

	if self.Destroyed then return end
	self.Model:PivotTo(self.NestCFrame)
	self.IsHome = true
	Animation:StopAnimOnServer(self.Model, FLY_ANIMATION, 0.2)
	Animation:PlayAnimOnServer(self.Model, IDLE_ANIMATION)
end

function Bird:Destroy()
	self.Destroyed = true
	self.Model:Destroy()
end

return Bird
