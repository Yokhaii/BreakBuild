local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)

local TextNotificationController = Knit.CreateController({
	Name = "TextNotificationController",
})

local Store
local TextNotificationActions

function TextNotificationController:Show(text: string, color: Color3?)
	local id = HttpService:GenerateGUID(false)
	Store:dispatch(TextNotificationActions.showTextNotification(id, text, color or Color3.fromRGB(255, 255, 255), false))
	return id
end

function TextNotificationController:ShowPersistent(text: string, color: Color3?): string
	local id = HttpService:GenerateGUID(false)
	Store:dispatch(TextNotificationActions.showTextNotification(id, text, color or Color3.fromRGB(255, 255, 255), true))
	return id
end

function TextNotificationController:Release(id: string)
	Store:dispatch(TextNotificationActions.releaseTextNotification(id))
end

function TextNotificationController:KnitInit()
end

function TextNotificationController:KnitStart()
	Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
	TextNotificationActions = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions.TextNotificationActions)
end

return TextNotificationController
