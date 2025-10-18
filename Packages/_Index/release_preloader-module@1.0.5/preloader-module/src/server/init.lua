--[=[
	Owner: JustStop__
	Version: v0.0.1
	Contact owner if any question, concern or feedback
]=]

-- Set random seed as server start timestamp
math.randomseed(tick())

-- Game Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Knit = require(ReplicatedStorage.Packages.knit)

-- Services
for _, file in pairs(script.Services:GetChildren()) do
	require(file)
end

--|| Knit Lifecycle ||--
Knit.Start()
	:andThen(function()
		print("[SERVER] Server started successfully")
	end)
	:catch(warn)
	:await()

return Knit
