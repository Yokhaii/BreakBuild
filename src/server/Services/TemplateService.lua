-- Knit Packages
local MarketplaceService = game:GetService("MarketplaceService")
local PathfindingService = game:GetService("PathfindingService")
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

-- Services
local Players = game:GetService("Players")
local DataService

local TemplateService = Knit.CreateService({
	Name = "TemplateService",
	Client = {},
})

--|| Client Functions ||--

function TemplateService.Client:TestEvent(player: Player): boolean
	local playerData = DataService:GetData(player)

	return false
end

-- KNIT START
function TemplateService:KnitStart()
	DataService = Knit.GetService("DataService")

	local function characterAdded(player: Player, character: Instance)
	end

	local function playerAdded(player: Player)
		player.CharacterAdded:Connect(function(character)
			characterAdded(player, character)
		end)

		-- code playeradded
	end

	Players.PlayerAdded:Connect(playerAdded)
	for _, player in pairs(Players:GetChildren()) do
		playerAdded(player)
	end
end

return TemplateService