local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local InventoryActions = {}

InventoryActions.setInventory = Rodux.makeActionCreator("setInventory", function(inventory)
	return {
		inventory = inventory,
	}
end)

InventoryActions.setHotbar = Rodux.makeActionCreator("setHotbar", function(hotbar)
	return {
		hotbar = hotbar,
	}
end)

InventoryActions.setHammerAvailable = Rodux.makeActionCreator("setHammerAvailable", function(available)
	return {
		available = available,
	}
end)

InventoryActions.setBackpack = Rodux.makeActionCreator("setBackpack", function(backpack)
	return {
		backpack = backpack,
	}
end)

InventoryActions.setEquippedSlot = Rodux.makeActionCreator("setEquippedSlot", function(slot)
	return {
		slot = slot,
	}
end)

InventoryActions.setBackpackOpen = Rodux.makeActionCreator("setBackpackOpen", function(isOpen)
	return {
		isOpen = isOpen,
	}
end)

InventoryActions.swapGridSlots = Rodux.makeActionCreator("swapGridSlots", function(fromGridIndex, toGridIndex)
	return {
		fromGridIndex = fromGridIndex,
		toGridIndex = toGridIndex,
	}
end)

InventoryActions.removeGridSlot = Rodux.makeActionCreator("removeGridSlot", function(gridIndex)
	return {
		gridIndex = gridIndex,
	}
end)

return InventoryActions
