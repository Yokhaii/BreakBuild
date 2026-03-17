local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local InventoryActions = {}

-- Set the entire inventory
InventoryActions.setInventory = Rodux.makeActionCreator("setInventory", function(inventory)
	return {
		inventory = inventory,
	}
end)

-- Set Break hotbar data
InventoryActions.setBreakHotbar = Rodux.makeActionCreator("setBreakHotbar", function(hotbar)
	return {
		hotbar = hotbar,
	}
end)

-- Set Build hotbar data
InventoryActions.setBuildHotbar = Rodux.makeActionCreator("setBuildHotbar", function(hotbar)
	return {
		hotbar = hotbar,
	}
end)

-- Set current mode
InventoryActions.setCurrentMode = Rodux.makeActionCreator("setCurrentMode", function(mode)
	return {
		mode = mode,
	}
end)

-- Set backpack data
InventoryActions.setBackpack = Rodux.makeActionCreator("setBackpack", function(backpack)
	return {
		backpack = backpack,
	}
end)

-- Set equipped slot
InventoryActions.setEquippedSlot = Rodux.makeActionCreator("setEquippedSlot", function(slot)
	return {
		slot = slot,
	}
end)

-- Set backpack open state
InventoryActions.setBackpackOpen = Rodux.makeActionCreator("setBackpackOpen", function(isOpen)
	return {
		isOpen = isOpen,
	}
end)

-- Set search query
InventoryActions.setSearchQuery = Rodux.makeActionCreator("setSearchQuery", function(query)
	return {
		query = query,
	}
end)

return InventoryActions
