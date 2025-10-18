--[=[
 	Owner: rompionyoann
 	Version: 0.0.1
 	Contact owner if any question, concern or feedback
 ]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Rodux = require(ReplicatedStorage.Packages.Rodux)

-- Reducer
local TemplateReducer = Rodux.createReducer({
	someData = {},
    someType = 0,
}, {
	setSomeData = function(state, action)
        local newState = table.clone(state)
        newState.someData = action.someData
        return newState
    end,
    setSomeType = function(state, action)
        local newState = table.clone(state)
        newState.someType = action.someType
        return newState
    end,
})

return TemplateReducer