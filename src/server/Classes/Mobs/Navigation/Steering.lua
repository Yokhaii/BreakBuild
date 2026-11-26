--[=[
	Steering - cheap navigation checks for behaviors (raycasts only, no pathfinding)
	Ledges up to the mob's jump height are passable (MobMover steps up onto them).
	Habitat (mob.Habitat, see Water): ground outside the mob's habitat counts as blocked,
	unless the mob already stands outside it (then it may always walk back).
	  IsDirectionClear   no wall taller than the jump height, ground in front (no cliff / void),
	                     ground in the mob's habitat
	  FindClearDirection closest clear direction to the wanted one
	  HasLineOfSight     straight line to a position is free (above jumpable ledges) and stays
	                     in the mob's habitat
	  IsOnGroundTag      the surface under a position is Ground-tagged (Outside world)
	  RandomGroundPoint  random free point in the mob's habitat, on Ground-tagged parts (or any
	                     walkable surface)
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)
local MobRaycast = require(script.Parent.MobRaycast)
local Water = require(script.Parent.Water)

local Steering = {}

-- Directions tried by FindClearDirection, in order (degrees from the wanted direction)
local TRY_ANGLES = { 0, 30, -30, 60, -60, 90, -90, 135, -135, 180 }
local WALKABLE_NORMAL_Y = 0.7 -- slopes steeper than ~45° block the way
local NEAR_RAY_HEIGHT = 40 -- studs above/below a position checked for its own ground
local FAR_RAY_HEIGHT = 120 -- studs above/below for far patrol points (hills, valleys)
local STANDING_OFFSET = Vector3.new(0, 0.5, 0) -- habitat is tested just above the ground
local MAX_LINE_SAMPLES = 30

local function flat(vector: Vector3): Vector3
	return Vector3.new(vector.X, 0, vector.Z)
end

local function getObstacleParams(): RaycastParams
	return MobRaycast.GetParams()
end

-- Point above the mob's center at the height of the highest ledge it can hop onto:
-- anything hit at this height is too tall to jump
local function getJumpProbeOrigin(mob): (Vector3, number)
	local collide = mob.CollidePart or mob.Root
	local feetY = collide.Position.Y - collide.Size.Y / 2
	local jumpTop = feetY + mob.Mover.JumpHeight + MobConfig.StepClearance
	return Vector3.new(collide.Position.X, jumpTop, collide.Position.Z), feetY
end

-- First surface under `position` within ±rayHeight (nothing on top of it), or nil
local function raycastDown(position: Vector3, params: RaycastParams, rayHeight: number?): RaycastResult?
	rayHeight = rayHeight or NEAR_RAY_HEIGHT
	return Workspace:Raycast(position + Vector3.new(0, rayHeight, 0), Vector3.new(0, -2 * rayHeight, 0), params)
end

-- Does the mob currently stand in its habitat? (a ground mob already in water may walk anywhere)
local function isInHabitat(mob): boolean
	local _, feetY = getJumpProbeOrigin(mob)
	local position = (mob.CollidePart or mob.Root).Position
	return Water.IsAllowed(mob.Habitat, Vector3.new(position.X, feetY, position.Z) + STANDING_OFFSET)
end

function Steering.IsDirectionClear(mob, direction: Vector3, distance: number?): boolean
	local planar = flat(direction)
	if planar.Magnitude < 1e-3 then return false end
	distance = distance or MobConfig.LookAheadDistance

	local params = getObstacleParams()
	local origin, feetY = getJumpProbeOrigin(mob)
	local ahead = planar.Unit * distance

	-- Wall taller than the jump height
	local hit = Workspace:Raycast(origin, ahead, params)
	if hit and hit.Normal.Y < WALKABLE_NORMAL_Y then
		return false
	end

	-- Ground under the point in front, not too far down
	local depth = origin.Y - feetY + MobConfig.MaxDropHeight
	local ground = Workspace:Raycast(origin + ahead, Vector3.new(0, -depth, 0), params)
	if not ground then
		return false
	end

	-- Ground in the mob's habitat
	return Water.IsAllowed(mob.Habitat, ground.Position + STANDING_OFFSET) or not isInHabitat(mob)
end

-- Closest clear direction to `desired` (nil when boxed in)
function Steering.FindClearDirection(mob, desired: Vector3, distance: number?): Vector3?
	local planar = flat(desired)
	if planar.Magnitude < 1e-3 then return nil end
	planar = planar.Unit
	for _, angle in ipairs(TRY_ANGLES) do
		local direction = CFrame.Angles(0, math.rad(angle), 0):VectorToWorldSpace(planar)
		if Steering.IsDirectionClear(mob, direction, distance) then
			return direction
		end
	end
	return nil
end

function Steering.HasLineOfSight(mob, position: Vector3): boolean
	local origin = getJumpProbeOrigin(mob)
	local target = Vector3.new(position.X, origin.Y, position.Z)
	local params = getObstacleParams()
	local hit = Workspace:Raycast(origin, target - origin, params)
	if hit and hit.Normal.Y < WALKABLE_NORMAL_Y then
		return false
	end

	-- Ground along the line stays in the habitat
	if not isInHabitat(mob) then return true end
	local length = flat(target - origin).Magnitude
	local samples = math.min(math.floor(length / MobConfig.HabitatCheckSpacing), MAX_LINE_SAMPLES)
	for i = 1, samples do
		local point = origin:Lerp(target, i / samples)
		local ground = raycastDown(point, params)
		if ground and not Water.IsAllowed(mob.Habitat, ground.Position + STANDING_OFFSET) then
			return false
		end
	end
	return true
end

-- Is the surface under `position` a Ground-tagged part (the Outside world)?
function Steering.IsOnGroundTag(position: Vector3): boolean
	local hit = raycastDown(position, getObstacleParams())
	return hit ~= nil and CollectionService:HasTag(hit.Instance, MobConfig.GroundTag)
end

-- Random point within `radius` of `center` with nothing on top of it (no tree, no wall),
-- in `habitat` (default Ground: no water).
-- The distance is uniform between 0 and radius, so short and long walks are equally likely.
-- Only on Ground-tagged parts, unless anySurface (then any walkable surface).
-- nil after a few failed tries.
function Steering.RandomGroundPoint(center: Vector3, radius: number, anySurface: boolean?, habitat: string?, tries: number?): Vector3?
	local params = getObstacleParams()
	for _ = 1, tries or 6 do
		local angle = math.random() * 2 * math.pi
		local distance = math.random() * radius
		local point = Vector3.new(center.X + math.cos(angle) * distance, center.Y, center.Z + math.sin(angle) * distance)
		local hit = raycastDown(point, params, FAR_RAY_HEIGHT)
		if hit then
			local valid = if anySurface
				then hit.Normal.Y >= WALKABLE_NORMAL_Y
				else CollectionService:HasTag(hit.Instance, MobConfig.GroundTag)
			if valid and Water.IsAllowed(habitat, hit.Position + STANDING_OFFSET) then
				return hit.Position
			end
		end
	end
	return nil
end

return Steering
