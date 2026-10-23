local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local ShopActions = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions.ShopActions)

local Shop = {}

function Shop:Init()
	local ShopService = Knit.GetService("ShopService")

	ShopService.BalanceUpdated:Connect(function(newBalance)
		Store:dispatch(ShopActions.setBalance(newBalance))
	end)

	ShopService:GetBalance()
		:andThen(function(balance)
			Store:dispatch(ShopActions.setBalance(balance))
		end)
		:catch(function(err)
			warn("[ShopSync] Failed to get initial balance:", err)
		end)
end

return Shop
