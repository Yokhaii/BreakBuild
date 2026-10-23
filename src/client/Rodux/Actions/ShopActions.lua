local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local ShopActions = {}

ShopActions.openShop = Rodux.makeActionCreator("openShop", function(balance)
	return { balance = balance }
end)

ShopActions.closeShop = Rodux.makeActionCreator("closeShop", function()
	return {}
end)

ShopActions.setBalance = Rodux.makeActionCreator("setBalance", function(balance)
	return { balance = balance }
end)

ShopActions.setMode = Rodux.makeActionCreator("setMode", function(mode)
	return { mode = mode }
end)

ShopActions.addToBasket = Rodux.makeActionCreator("addToBasket", function(itemName, quantity)
	return { itemName = itemName, quantity = quantity }
end)

ShopActions.removeFromBasket = Rodux.makeActionCreator("removeFromBasket", function(itemName)
	return { itemName = itemName }
end)

ShopActions.clearBasket = Rodux.makeActionCreator("clearBasket", function()
	return {}
end)

ShopActions.addToSellPool = Rodux.makeActionCreator("addToSellPool", function(itemName, quantity, itemId, gridIndex)
	return { itemName = itemName, quantity = quantity, itemId = itemId, gridIndex = gridIndex }
end)

ShopActions.removeFromSellPool = Rodux.makeActionCreator("removeFromSellPool", function(itemName)
	return { itemName = itemName }
end)

ShopActions.clearSellPool = Rodux.makeActionCreator("clearSellPool", function()
	return {}
end)

ShopActions.setCategoryFilter = Rodux.makeActionCreator("setCategoryFilter", function(category)
	return { category = category }
end)

return ShopActions
