--[=[
	Water - where the water is, for mob habitats
	Water parts are tagged MobConfig.WaterTag in the place (Workspace.GeneratedFloor "Water Block").
	They are non-collidable and CanQuery false, so raycasts go through them: water is found by
	testing whether a point is inside a tagged part's box instead.

	  IsInWater(position)            point inside any water part
	  IsAllowed(habitat, position)   "Ground" = not in water, "Water" = in water, "Any" = always
	  Init()                         adds a PathfindingModifier (Label = WaterTag) to every water
	                                 part, so paths can be given a cost for water (PathFollower)
]=]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)

local Water = {}

local function addPathfindingModifier(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("WaterPathfindingModifier") then return end
	local modifier = Instance.new("PathfindingModifier")
	modifier.Name = "WaterPathfindingModifier"
	modifier.Label = MobConfig.WaterTag
	modifier.PassThrough = false
	modifier.Parent = part
end

function Water.Init()
	for _, part in ipairs(CollectionService:GetTagged(MobConfig.WaterTag)) do
		addPathfindingModifier(part)
	end
	CollectionService:GetInstanceAddedSignal(MobConfig.WaterTag):Connect(addPathfindingModifier)
end

function Water.IsInWater(position: Vector3): boolean
	for _, part in ipairs(CollectionService:GetTagged(MobConfig.WaterTag)) do
		if part:IsA("BasePart") then
			local localPosition = part.CFrame:PointToObjectSpace(position)
			local half = part.Size / 2
			if math.abs(localPosition.X) <= half.X and math.abs(localPosition.Y) <= half.Y and math.abs(localPosition.Z) <= half.Z then
				return true
			end
		end
	end
	return false
end

-- Can a mob of this habitat stand at this position (a point just above the ground)?
function Water.IsAllowed(habitat: string?, position: Vector3): boolean
	if habitat == "Any" then
		return true
	elseif habitat == "Water" then
		return Water.IsInWater(position)
	end
	return not Water.IsInWater(position) -- "Ground" (default)
end

return Water
