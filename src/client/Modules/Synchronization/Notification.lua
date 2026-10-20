local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)

local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local NotificationActions = require(Actions.NotificationActions)

local Notification = {}

function Notification:Init()
	local InventoryService = Knit.GetService("InventoryService")

	InventoryService.ItemGained:Connect(function(itemName, quantity)
		Store:dispatch(NotificationActions.addNotification(itemName, quantity))
	end)
end

return Notification
