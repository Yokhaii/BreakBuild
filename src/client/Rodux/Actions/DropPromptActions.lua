local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local DropPromptActions = {}

-- prompt: nil (closed) or { id, itemId, itemName, gridIndex, maxQuantity }
DropPromptActions.setDropPrompt = Rodux.makeActionCreator("setDropPrompt", function(prompt)
	return {
		prompt = prompt,
	}
end)

return DropPromptActions
