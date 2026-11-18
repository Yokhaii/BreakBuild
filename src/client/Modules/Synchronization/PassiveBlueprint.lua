local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local PassiveBlueprint = {}

local RETURN_COLOR = Color3.fromRGB(140, 220, 120)

local function getBlueprint(blueprintId)
	local ctrl = Knit.GetController("BlueprintPlacementController")
	return ctrl and ctrl:GetActiveBlueprint(blueprintId)
end

function PassiveBlueprint:Init()
	local PassiveBlueprintService = Knit.GetService("PassiveBlueprintService")
	local TextNotificationController = Knit.GetController("TextNotificationController")

	-- Drive the in-world billboard (timer + loot waiting in the nest)
	PassiveBlueprintService.StateUpdated:Connect(function(blueprintId, state)
		local blueprint = getBlueprint(blueprintId)
		if blueprint and blueprint.SetPassiveState then
			blueprint:SetPassiveState(state)
		end
	end)

	-- (blueprintId, items, wasOffline): the bird came back
	PassiveBlueprintService.ItemsReturned:Connect(function(_blueprintId, items, wasOffline)
		local text
		if wasOffline then
			text = string.format("While you were away, your bird brought back %d item%s!", #items, #items > 1 and "s" or "")
		elseif #items == 1 then
			local itemConfig = ItemData.GetItem(items[1].itemName)
			local displayName = itemConfig and itemConfig.displayName or items[1].itemName
			text = string.format("Your bird brought back %d %s!", items[1].quantity, displayName)
		else
			text = string.format("Your bird brought back %d items!", #items)
		end
		TextNotificationController:Show(text, RETURN_COLOR)
	end)
end

return PassiveBlueprint
