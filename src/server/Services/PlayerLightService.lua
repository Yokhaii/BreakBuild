local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)
local PlayerLightConfig = require(game:GetService("ReplicatedStorage").Shared.Config.PlayerLightConfig)

local PlayerLightService = Knit.CreateService({
	Name = "PlayerLightService",
	Client = {},
})

-- Stores references to player lights for cleanup
local playerLights = {} -- { [player] = { light: PointLight, attachment: Attachment } }

function PlayerLightService:KnitStart()
	-- Listen for player character spawns
	game.Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			self:_addLightToCharacter(player, character)
		end)
	end)

	-- Handle players already in game
	for _, player in pairs(game.Players:GetPlayers()) do
		if player.Character then
			self:_addLightToCharacter(player, player.Character)
		end
		player.CharacterAdded:Connect(function(character)
			self:_addLightToCharacter(player, character)
		end)
	end

	-- Cleanup on player leave
	game.Players.PlayerRemoving:Connect(function(player)
		self:_removePlayerLight(player)
	end)
end

function PlayerLightService:_addLightToCharacter(player, character)
	if not PlayerLightConfig.LightEnabled then
		return
	end

	-- Wait for HumanoidRootPart
	local rootPart = character:WaitForChild("HumanoidRootPart", 5)
	if not rootPart then
		warn("PlayerLightService: Could not find HumanoidRootPart for", player.Name)
		return
	end

	-- Clean up any existing light
	self:_removePlayerLight(player)

	-- Create attachment for light positioning
	local attachment = Instance.new("Attachment")
	attachment.Name = "LightAttachment"
	attachment.Position = PlayerLightConfig.AttachmentOffset
	attachment.Parent = rootPart

	-- Create PointLight
	local light = Instance.new("PointLight")
	light.Name = "PlayerLight"
	light.Brightness = PlayerLightConfig.Brightness
	light.Color = PlayerLightConfig.Color
	light.Range = PlayerLightConfig.Range
	light.Shadows = PlayerLightConfig.Shadows
	light.Parent = attachment

	-- Store references
	playerLights[player] = {
		light = light,
		attachment = attachment,
	}
end

function PlayerLightService:_removePlayerLight(player)
	local lightData = playerLights[player]
	if lightData then
		if lightData.attachment then
			lightData.attachment:Destroy()
		end
		if lightData.light then
			lightData.light:Destroy()
		end
		playerLights[player] = nil
	end
end

-- Public method to update light settings dynamically (optional)
function PlayerLightService:UpdatePlayerLight(player, properties)
	local lightData = playerLights[player]
	if not lightData or not lightData.light then
		return
	end

	for property, value in pairs(properties) do
		if property == "AttachmentOffset" and lightData.attachment then
			lightData.attachment.Position = value
		elseif lightData.light[property] ~= nil then
			lightData.light[property] = value
		end
	end
end

return PlayerLightService
