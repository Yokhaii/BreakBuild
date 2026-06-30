local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)

local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local CraftingActions = require(Actions.CraftingActions)

local Crafting = {}

function Crafting:Init()
	local CraftingService = Knit.GetService("CraftingService")

	CraftingService.SessionEnded:Connect(function()
		Store:dispatch(CraftingActions.clearSession())
	end)

	CraftingService.CraftStarted:Connect(function(recipeId, craftTime)
		Store:dispatch(CraftingActions.setCraftInProgress({
			recipeId = recipeId,
			startedAt = os.clock(),
			craftTime = craftTime,
		}))
	end)

	CraftingService.CraftCompleted:Connect(function(recipeId)
		Store:dispatch(CraftingActions.clearCraft())
	end)

	CraftingService.CraftFailed:Connect(function(reason)
		Store:dispatch(CraftingActions.clearCraft())
	end)
end

return Crafting
