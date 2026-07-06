local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local CraftingActions = require(Actions.CraftingActions)

local CraftingController = Knit.CreateController({
	Name = "CraftingController",
})

local CraftingService
local currentBlueprintId = nil

function CraftingController:StartSession(blueprintId: string)
	currentBlueprintId = blueprintId

	CraftingService:StartSession(blueprintId)
		:andThen(function(result)
			if result.success then
				Store:dispatch(CraftingActions.setSession({
					blueprintId = blueprintId,
					stationType = result.stationType,
					recipes = result.recipes,
				}))
			else
				warn("[CraftingController] StartSession failed:", result.reason)
				currentBlueprintId = nil
			end
		end)
		:catch(function(err)
			warn("[CraftingController] StartSession error:", err)
			currentBlueprintId = nil
		end)
end

function CraftingController:EndSession()
	if not currentBlueprintId then return end

	CraftingService:EndSession()
		:catch(function(err)
			warn("[CraftingController] EndSession error:", err)
		end)

	currentBlueprintId = nil
	Store:dispatch(CraftingActions.clearSession())
end

function CraftingController:CraftItem(recipeId: string, quantity: number?)
	if not currentBlueprintId then return end

	CraftingService:CraftItem(recipeId, quantity or 1)
		:andThen(function(result)
			if not result.success and not result.crafting then
				warn("[CraftingController] CraftItem failed:", result.reason)
			end
		end)
		:catch(function(err)
			warn("[CraftingController] CraftItem error:", err)
		end)
end

function CraftingController:HasActiveSession(): boolean
	return currentBlueprintId ~= nil
end

function CraftingController:KnitStart()
	CraftingService = Knit.GetService("CraftingService")
end

return CraftingController
