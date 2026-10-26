local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local CraftingPoolActions = {}

-- Add item to crafting pool (from drag-and-drop)
-- Tracks itemId and gridIndex so we can restore the item to inventory later
CraftingPoolActions.addToCraftingPool = Rodux.makeActionCreator("addToCraftingPool", function(itemName, quantity, itemId, gridIndex)
	return { itemName = itemName, quantity = quantity, itemId = itemId, gridIndex = gridIndex }
end)

-- Remove all items of a specific type from crafting pool (close button)
CraftingPoolActions.removeFromCraftingPool = Rodux.makeActionCreator("removeFromCraftingPool", function(itemName)
	return { itemName = itemName }
end)

-- Clear entire crafting pool (on craft or UI close)
CraftingPoolActions.clearCraftingPool = Rodux.makeActionCreator("clearCraftingPool", function()
	return {}
end)

return CraftingPoolActions
