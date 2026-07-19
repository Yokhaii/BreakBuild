local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local ChestActions = require(Actions.ChestActions)

local ChestController = Knit.CreateController({
	Name = "ChestController",
})

local ChestService
local isOpen = false

function ChestController:OpenChest(blueprintId: string)
	isOpen = true

	ChestService:OpenChest(blueprintId)
		:andThen(function(result)
			if result.success then
				Store:dispatch(ChestActions.setChest(blueprintId, result.items))
			else
				warn("[ChestController] OpenChest failed:", result.reason)
				isOpen = false
			end
		end)
		:catch(function(err)
			warn("[ChestController] OpenChest error:", err)
			isOpen = false
		end)
end

function ChestController:CloseChest()
	if not isOpen then return end

	ChestService:CloseChest()
		:catch(function(err)
			warn("[ChestController] CloseChest error:", err)
		end)

	isOpen = false
	Store:dispatch(ChestActions.clearChest())
end

function ChestController:DepositItem(itemId: string, quantity: number)
	if not isOpen then return end

	ChestService:DepositItem(itemId, quantity)
		:andThen(function(result)
			if result.success then
				Store:dispatch(ChestActions.updateChestItems(result.items))
			else
				warn("[ChestController] DepositItem failed:", result.reason)
			end
		end)
		:catch(function(err)
			warn("[ChestController] DepositItem error:", err)
		end)
end

function ChestController:WithdrawItem(itemName: string, quantity: number)
	if not isOpen then return end

	ChestService:WithdrawItem(itemName, quantity)
		:andThen(function(result)
			if result.success then
				Store:dispatch(ChestActions.updateChestItems(result.items))
			else
				warn("[ChestController] WithdrawItem failed:", result.reason)
			end
		end)
		:catch(function(err)
			warn("[ChestController] WithdrawItem error:", err)
		end)
end

function ChestController:GetCurrentChestId(): boolean
	return isOpen
end

function ChestController:KnitStart()
	ChestService = Knit.GetService("ChestService")

	-- Server pushes updates whenever chest contents change
	ChestService.ChestUpdated:Connect(function(items)
		if isOpen then
			Store:dispatch(ChestActions.updateChestItems(items))
		end
	end)
end

return ChestController
