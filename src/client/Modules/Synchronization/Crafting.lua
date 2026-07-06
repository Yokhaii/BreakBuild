local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)

local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local CraftingActions = require(Actions.CraftingActions)

local Crafting = {}

local function getBlueprint(blueprintId)
	local ctrl = Knit.GetController("BlueprintPlacementController")
	return ctrl and ctrl:GetActiveBlueprint(blueprintId)
end

function Crafting:Init()
	local CraftingService = Knit.GetService("CraftingService")
	local BlueprintService = Knit.GetService("BlueprintService")

	CraftingService.SessionEnded:Connect(function()
		Store:dispatch(CraftingActions.clearSession())
	end)

	-- (recipeId, totalDuration, elapsed): reconstruct startedAt so bar shows correct position
	CraftingService.CraftStarted:Connect(function(recipeId, totalDuration, elapsed)
		Store:dispatch(CraftingActions.setCraftInProgress({
			recipeId = recipeId,
			startedAt = os.clock() - (elapsed or 0),
			craftTime = totalDuration,
		}))
	end)

	-- (recipeId, blueprintId): craft was delivered because the station was open
	CraftingService.CraftCompleted:Connect(function(recipeId, blueprintId)
		Store:dispatch(CraftingActions.clearCraft())
		if blueprintId then
			local blueprint = getBlueprint(blueprintId)
			if blueprint then
				blueprint:OnCraftReceived()
			end
		end
	end)

	CraftingService.CraftFailed:Connect(function(_reason)
		Store:dispatch(CraftingActions.clearCraft())
	end)

	-- Timer finished while UI was closed — freeze billboard at 100% and show "Ready!"
	-- Delivery happens when the player opens the station (in StartSession server-side).
	CraftingService.CraftReady:Connect(function(blueprintId, _recipeId)
		local blueprint = getBlueprint(blueprintId)
		if blueprint then
			blueprint:ShowCraftingProgress(1, 0)
		end
	end)

	-- Drive the in-world billboard on the blueprint model.
	BlueprintService.CraftingProgressUpdated:Connect(function(blueprintId, progress, secsRemaining)
		local blueprint = getBlueprint(blueprintId)
		if blueprint then
			blueprint:ShowCraftingProgress(progress, secsRemaining)
		end
	end)

	BlueprintService.CraftingProgressCleared:Connect(function(blueprintId)
		local blueprint = getBlueprint(blueprintId)
		if blueprint then
			blueprint:HideCraftingProgress()
		end
	end)
end

return Crafting
