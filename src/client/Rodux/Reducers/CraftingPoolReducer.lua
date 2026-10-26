local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local initialState = {
	-- Array of { itemName, quantity, itemId, gridIndex }
	-- Each entry represents items dragged into the crafting pool
	Pool = {},
}

local function craftingPoolReducer(state, action)
	state = state or initialState

	if action.type == "addToCraftingPool" then
		local newPool = {}
		for _, entry in ipairs(state.Pool) do
			table.insert(newPool, entry)
		end
		table.insert(newPool, {
			itemName = action.itemName,
			quantity = action.quantity,
			itemId = action.itemId,
			gridIndex = action.gridIndex,
		})
		return {
			Pool = newPool,
		}
	elseif action.type == "removeFromCraftingPool" then
		local newPool = {}
		for _, entry in ipairs(state.Pool) do
			if entry.itemName ~= action.itemName then
				table.insert(newPool, entry)
			end
		end
		return {
			Pool = newPool,
		}
	elseif action.type == "clearCraftingPool" then
		return {
			Pool = {},
		}
	end

	return state
end

return craftingPoolReducer
