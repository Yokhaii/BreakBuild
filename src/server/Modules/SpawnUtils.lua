--[[
	SpawnUtils.lua
	Reusable utilities for picking valid world spawn positions.
	Used by TreeService, and future mob/prop spawners.

	findGroundPosition(boundaryPart, groundTag, existingPositions, minSeparation)
		Picks a random XZ point inside boundaryPart's bounding box, then
		raycasts downward to find the first Ground-tagged surface.
		Returns the surface position (sitting on top of the part) or nil.

	pickWeightedRandom(weightTable)
		Given {key = weight, ...} returns a randomly weighted key.
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local SpawnUtils = {}

-- How far above the boundary part we start the downward ray
local RAY_START_OFFSET = 500

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function buildGroundInstances(groundTag: string): {Instance}
	return CollectionService:GetTagged(groundTag)
end

function SpawnUtils.findGroundPosition(
	boundaryPart: BasePart,
	groundTag: string,
	existingPositions: {Vector3},
	minSeparation: number
): Vector3?
	local size = boundaryPart.Size
	local cframe = boundaryPart.CFrame

	-- Rebuild ground filter each call so newly tagged parts are included
	local groundInstances = buildGroundInstances(groundTag)
	if #groundInstances == 0 then
		warn("[SpawnUtils] No parts tagged as '" .. groundTag .. "' found")
		return nil
	end
	rayParams.FilterDescendantsInstances = groundInstances

	-- Try up to 20 times to find a valid non-overlapping spot
	for _ = 1, 20 do
		-- Random XZ inside the boundary part's local space
		local localX = (math.random() - 0.5) * size.X
		local localZ = (math.random() - 0.5) * size.Z

		-- Convert to world position at the top of the boundary part
		local worldXZ = cframe:PointToWorldSpace(Vector3.new(localX, size.Y / 2, localZ))
		local rayOrigin = Vector3.new(worldXZ.X, worldXZ.Y + RAY_START_OFFSET, worldXZ.Z)
		local rayDirection = Vector3.new(0, -(RAY_START_OFFSET + size.Y + 100), 0)

		local result = Workspace:Raycast(rayOrigin, rayDirection, rayParams)
		if not result then continue end

		local spawnPosition = result.Position

		-- Check separation from existing positions
		local tooClose = false
		for _, existing in ipairs(existingPositions) do
			if (spawnPosition - existing).Magnitude < minSeparation then
				tooClose = true
				break
			end
		end

		if not tooClose then
			return spawnPosition
		end
	end

	return nil
end

-- Returns a key from weightTable chosen by weighted random
function SpawnUtils.pickWeightedRandom(weightTable: {[string]: number}): string?
	local total = 0
	for _, weight in pairs(weightTable) do
		total = total + weight
	end
	if total <= 0 then return nil end

	local roll = math.random() * total
	local cumulative = 0
	for key, weight in pairs(weightTable) do
		cumulative = cumulative + weight
		if roll <= cumulative then
			return key
		end
	end

	-- Fallback (floating point edge case)
	for key, _ in pairs(weightTable) do
		return key
	end
	return nil
end

return SpawnUtils
