--[=[
	MobRaycast - shared RaycastParams for mob movement and navigation
	Obstacles = everything solid except mobs and player characters.
	Cached and rebuilt every REFRESH_INTERVAL (characters respawn), so movers and behaviors
	can raycast every frame without rebuilding the filter.
]=]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)

local MobRaycast = {}

local REFRESH_INTERVAL = 0.5

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true
local refreshedAt = -math.huge

function MobRaycast.GetParams(): RaycastParams
	local now = os.clock()
	if now - refreshedAt >= REFRESH_INTERVAL then
		refreshedAt = now
		local ignore = {}
		local mobsFolder = Workspace:FindFirstChild(MobConfig.MobsFolderName)
		if mobsFolder then
			table.insert(ignore, mobsFolder)
		end
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Character then
				table.insert(ignore, player.Character)
			end
		end
		params.FilterDescendantsInstances = ignore
	end
	return params
end

return MobRaycast
