--[=[
 	Owner: CategoryTheory
 	Version: 0.0.1
 	Contact owner if any question, concern or feedback
 ]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Rodux = require(ReplicatedStorage.Packages.Rodux)

local TemplateActions = {
	setSomeData = Rodux.makeActionCreator("setSomeData", function(someData)
        return {
            someData = someData,
        }
    end),
    setSomeType = Rodux.makeActionCreator("setSomeType", function(someType)
        return {
            someType = someType,
        }
    end),
}

return TemplateActions
