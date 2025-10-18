local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Packages
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Services
for _, file in pairs(script.Services:GetChildren()) do
	require(file)
end


Knit.Start()
    :andThen(function()

        print("[SERVER] Server started successfully")
    end)
    :catch(warn)
    :await()
