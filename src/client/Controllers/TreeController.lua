local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local TreeController = Knit.CreateController({ Name = "TreeController" })

function TreeController:KnitInit() end
function TreeController:KnitStart() end

return TreeController
