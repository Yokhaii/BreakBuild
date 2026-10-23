local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local defaultState = {
	IsOpen = false,
	Balance = 0,
	Mode = "Buy",
	Basket = {},
	SellPool = {},
	CategoryFilter = nil,
}

local ShopReducer = Rodux.createReducer(defaultState, {
	openShop = function(_state, action)
		return {
			IsOpen = true,
			Balance = action.balance or 0,
			Mode = "Buy",
			Basket = {},
			SellPool = {},
			CategoryFilter = nil,
		}
	end,

	closeShop = function()
		return {
			IsOpen = false,
			Balance = 0,
			Mode = "Buy",
			Basket = {},
			SellPool = {},
			CategoryFilter = nil,
		}
	end,

	setBalance = function(state, action)
		return {
			IsOpen = state.IsOpen,
			Balance = action.balance or state.Balance,
			Mode = state.Mode,
			Basket = state.Basket,
			SellPool = state.SellPool,
			CategoryFilter = state.CategoryFilter,
		}
	end,

	setMode = function(state, action)
		return {
			IsOpen = state.IsOpen,
			Balance = state.Balance,
			Mode = action.mode or state.Mode,
			Basket = {},
			SellPool = {},
			CategoryFilter = state.CategoryFilter,
		}
	end,

	addToBasket = function(state, action)
		local newBasket = {}
		for k, v in pairs(state.Basket) do
			newBasket[k] = v
		end
		newBasket[action.itemName] = (newBasket[action.itemName] or 0) + (action.quantity or 1)

		return {
			IsOpen = state.IsOpen,
			Balance = state.Balance,
			Mode = state.Mode,
			Basket = newBasket,
			SellPool = state.SellPool,
			CategoryFilter = state.CategoryFilter,
		}
	end,

	removeFromBasket = function(state, action)
		local newBasket = {}
		for k, v in pairs(state.Basket) do
			if k ~= action.itemName then
				newBasket[k] = v
			end
		end

		return {
			IsOpen = state.IsOpen,
			Balance = state.Balance,
			Mode = state.Mode,
			Basket = newBasket,
			SellPool = state.SellPool,
			CategoryFilter = state.CategoryFilter,
		}
	end,

	clearBasket = function(state)
		return {
			IsOpen = state.IsOpen,
			Balance = state.Balance,
			Mode = state.Mode,
			Basket = {},
			SellPool = state.SellPool,
			CategoryFilter = state.CategoryFilter,
		}
	end,

	addToSellPool = function(state, action)
		local newPool = {}
		for i, entry in ipairs(state.SellPool) do
			newPool[i] = entry
		end
		table.insert(newPool, {
			itemName = action.itemName,
			quantity = action.quantity or 1,
			itemId = action.itemId,
			gridIndex = action.gridIndex,
		})

		return {
			IsOpen = state.IsOpen,
			Balance = state.Balance,
			Mode = state.Mode,
			Basket = state.Basket,
			SellPool = newPool,
			CategoryFilter = state.CategoryFilter,
		}
	end,

	removeFromSellPool = function(state, action)
		local newPool = {}
		for _, entry in ipairs(state.SellPool) do
			if entry.itemName ~= action.itemName then
				table.insert(newPool, entry)
			end
		end

		return {
			IsOpen = state.IsOpen,
			Balance = state.Balance,
			Mode = state.Mode,
			Basket = state.Basket,
			SellPool = newPool,
			CategoryFilter = state.CategoryFilter,
		}
	end,

	clearSellPool = function(state)
		return {
			IsOpen = state.IsOpen,
			Balance = state.Balance,
			Mode = state.Mode,
			Basket = state.Basket,
			SellPool = {},
			CategoryFilter = state.CategoryFilter,
		}
	end,

	setCategoryFilter = function(state, action)
		return {
			IsOpen = state.IsOpen,
			Balance = state.Balance,
			Mode = state.Mode,
			Basket = state.Basket,
			SellPool = state.SellPool,
			CategoryFilter = action.category,
		}
	end,
})

return ShopReducer
