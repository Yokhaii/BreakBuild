local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

-- "How many to drop?" prompt, opened on touch when a stack is dragged out of the inventory
local defaultState = {
	Prompt = nil, -- { id, itemId, itemName, gridIndex, maxQuantity }
}

local DropPromptReducer = Rodux.createReducer(defaultState, {
	setDropPrompt = function(_, action)
		return {
			Prompt = action.prompt,
		}
	end,
})

return DropPromptReducer
