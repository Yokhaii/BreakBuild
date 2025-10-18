--[=[
	Owner: CategoryTheory
	Version: 0.0.1
	Contact owner if any question, concern or feedback
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Modules
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Code
return function ()
	Knit.OnStart():andThen(function()
		for _, module in script:GetChildren() do
			local synchronizationModule = require(module)
			synchronizationModule:Init()
		end
	end)
end