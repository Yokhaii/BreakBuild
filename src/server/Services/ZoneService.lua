local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local ZoneService = Knit.CreateService({
	Name = "ZoneService",
	Client = {
		ZoneAssigned = Knit.CreateSignal(),
		PlayerTeleported = Knit.CreateSignal(),
	},
})

local ZONE_COUNT = 8

-- { [Player]: { zone: Model, area: BasePart, grass: BasePart, zoneName: string } }
local zoneAssignments = {}
-- { [zoneName]: Player? }
local zoneOccupancy = {}

local function getZoneData(zoneName)
	local zone = Workspace:FindFirstChild(zoneName)
	if not zone then return nil end

	local area = zone:FindFirstChild("BuildingArea")
	local grass = zone:FindFirstChild("Grass")
	if not area or not grass then return nil end

	return {
		zone = zone,
		area = area,
		grass = grass,
		zoneName = zoneName,
	}
end

function ZoneService:AssignZone(player)
	if zoneAssignments[player] then
		return zoneAssignments[player]
	end

	for i = 1, ZONE_COUNT do
		local zoneName = "BuildingZone_" .. i
		if not zoneOccupancy[zoneName] then
			local zoneData = getZoneData(zoneName)
			if zoneData then
				zoneOccupancy[zoneName] = player
				zoneAssignments[player] = zoneData
				self.Client.ZoneAssigned:Fire(player, zoneName)
				print("[ZoneService] Assigned", zoneName, "to", player.Name)
				return zoneData
			end
		end
	end

	warn("[ZoneService] No available zone for", player.Name)
	return nil
end

function ZoneService:ReleaseZone(player)
	local zoneData = zoneAssignments[player]
	if not zoneData then return end

	-- Clean up all player-spawned children (blocks, blueprints, structures)
	-- before freeing the slot. This avoids ordering issues with other services'
	-- PlayerRemoving handlers that depend on the zone assignment.
	local zone = zoneData.zone
	for _, child in ipairs(zone:GetChildren()) do
		local playerIdValue = child:FindFirstChild("PlayerId")
		local ownerIdValue = child:FindFirstChild("OwnerId")
		if (playerIdValue and playerIdValue.Value == player.UserId)
			or (ownerIdValue and ownerIdValue.Value == player.UserId) then
			child:Destroy()
		end
	end

	zoneOccupancy[zoneData.zoneName] = nil
	zoneAssignments[player] = nil
	print("[ZoneService] Released", zoneData.zoneName, "from", player.Name)
end

function ZoneService:GetPlayerZone(player)
	return zoneAssignments[player]
end

function ZoneService:GetPlayerBuildingAreaOrigin(player)
	local zoneData = zoneAssignments[player]
	if not zoneData then return nil end

	local pos = zoneData.area.Position
	return Vector3.new(pos.X, pos.Y - 32, pos.Z)
end

function ZoneService:TeleportToZone(player)
	local zoneData = zoneAssignments[player]
	if not zoneData then return end

	local character = player.Character
	if not character then return end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart then return end

	local grass = zoneData.grass
	local spawnPosition = grass.Position + Vector3.new(0, grass.Size.Y / 2 + 3, 0)
	humanoidRootPart.CFrame = CFrame.new(spawnPosition) * CFrame.Angles(0, math.rad(180), 0)

	-- Fire signal to client to adjust camera
	self.Client.PlayerTeleported:Fire(player)
end

function ZoneService.Client:GetAssignedZone(player)
	local zoneData = zoneAssignments[player]
	if not zoneData then return nil end
	return zoneData.zoneName
end

function ZoneService.Client:TeleportToZone(player)
	return self.Server:TeleportToZone(player)
end

function ZoneService:KnitStart()
	for i = 1, ZONE_COUNT do
		local zoneName = "BuildingZone_" .. i
		zoneOccupancy[zoneName] = nil
		local zone = Workspace:FindFirstChild(zoneName)
		if not zone then
			warn("[ZoneService]", zoneName, "not found in Workspace!")
		end
	end

	local function onPlayerAdded(player)
		self:AssignZone(player)

		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			self:TeleportToZone(player)
		end)

		if player.Character then
			task.wait(0.5)
			self:TeleportToZone(player)
		end
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in pairs(Players:GetPlayers()) do
		onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		self:ReleaseZone(player)
	end)
end

return ZoneService
