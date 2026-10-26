local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Knit = require(ReplicatedStorage.Packages.Knit)

local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local CraftingActions = require(Actions.CraftingActions)

local CraftingController = Knit.CreateController({
	Name = "CraftingController",
})

local CraftingService
local currentBlueprintId = nil

function CraftingController:StartSession(blueprintId: string)
	currentBlueprintId = blueprintId

	-- Clear crafting pool when starting a new session (switching between crafting systems)
	local CraftingPoolActions = require(Actions.CraftingPoolActions)
	local InventoryActions = require(Actions.InventoryActions)
	local poolState = Store:getState().CraftingPoolReducer

	if poolState and poolState.Pool and #poolState.Pool > 0 then
		-- Restore all pool items to inventory first
		local inventoryState = Store:getState().InventoryReducer
		local slotTotals = {}

		for _, entry in ipairs(poolState.Pool) do
			if entry.gridIndex and entry.itemId then
				if not slotTotals[entry.gridIndex] then
					slotTotals[entry.gridIndex] = { itemId = entry.itemId, itemName = entry.itemName, totalQuantity = 0 }
				end
				slotTotals[entry.gridIndex].totalQuantity = slotTotals[entry.gridIndex].totalQuantity + entry.quantity
			end
		end

		for gridIndex, data in pairs(slotTotals) do
			local currentSlot = nil
			if gridIndex <= 21 then
				currentSlot = inventoryState.Backpack[gridIndex]
			else
				currentSlot = inventoryState.Hotbar[gridIndex - 21]
			end

			if currentSlot and currentSlot.itemName == data.itemName then
				Store:dispatch(InventoryActions.restoreGridSlot(gridIndex, {
					id = currentSlot.id,
					itemName = data.itemName,
					quantity = currentSlot.quantity + data.totalQuantity,
				}))
			else
				Store:dispatch(InventoryActions.restoreGridSlot(gridIndex, {
					id = data.itemId,
					itemName = data.itemName,
					quantity = data.totalQuantity,
				}))
			end
		end

		Store:dispatch(CraftingPoolActions.clearCraftingPool())
	end

	CraftingService:StartSession(blueprintId)
		:andThen(function(result)
			if result.success then
				Store:dispatch(CraftingActions.setSession({
					blueprintId = blueprintId,
					stationType = result.stationType,
					recipes = result.recipes,
				}))
			else
				warn("[CraftingController] StartSession failed:", result.reason)
				currentBlueprintId = nil
			end
		end)
		:catch(function(err)
			warn("[CraftingController] StartSession error:", err)
			currentBlueprintId = nil
		end)
end

function CraftingController:EndSession()
	if not currentBlueprintId then return end

	-- Clear crafting pool when ending session (restore items to inventory)
	local CraftingPoolActions = require(Actions.CraftingPoolActions)
	local InventoryActions = require(Actions.InventoryActions)
	local poolState = Store:getState().CraftingPoolReducer

	if poolState and poolState.Pool and #poolState.Pool > 0 then
		-- Restore all pool items to inventory
		local inventoryState = Store:getState().InventoryReducer
		local slotTotals = {}

		for _, entry in ipairs(poolState.Pool) do
			if entry.gridIndex and entry.itemId then
				if not slotTotals[entry.gridIndex] then
					slotTotals[entry.gridIndex] = { itemId = entry.itemId, itemName = entry.itemName, totalQuantity = 0 }
				end
				slotTotals[entry.gridIndex].totalQuantity = slotTotals[entry.gridIndex].totalQuantity + entry.quantity
			end
		end

		for gridIndex, data in pairs(slotTotals) do
			local currentSlot = nil
			if gridIndex <= 21 then
				currentSlot = inventoryState.Backpack[gridIndex]
			else
				currentSlot = inventoryState.Hotbar[gridIndex - 21]
			end

			if currentSlot and currentSlot.itemName == data.itemName then
				Store:dispatch(InventoryActions.restoreGridSlot(gridIndex, {
					id = currentSlot.id,
					itemName = data.itemName,
					quantity = currentSlot.quantity + data.totalQuantity,
				}))
			else
				Store:dispatch(InventoryActions.restoreGridSlot(gridIndex, {
					id = data.itemId,
					itemName = data.itemName,
					quantity = data.totalQuantity,
				}))
			end
		end

		Store:dispatch(CraftingPoolActions.clearCraftingPool())
	end

	CraftingService:EndSession()
		:catch(function(err)
			warn("[CraftingController] EndSession error:", err)
		end)

	currentBlueprintId = nil
	Store:dispatch(CraftingActions.clearSession())
end

function CraftingController:CraftItem(recipeId: string, quantity: number?)
	if not currentBlueprintId then return end

	CraftingService:CraftItem(recipeId, quantity or 1)
		:andThen(function(result)
			if not result.success and not result.crafting then
				warn("[CraftingController] CraftItem failed:", result.reason)
			end
		end)
		:catch(function(err)
			warn("[CraftingController] CraftItem error:", err)
		end)
end

-- Craft directly from inventory (no session required)
function CraftingController:CraftInventoryItem(recipeId: string, quantity: number?)
	CraftingService:CraftInventoryItem(recipeId, quantity or 1)
		:andThen(function(result)
			if not result.success and not result.crafting then
				warn("[CraftingController] CraftInventoryItem failed:", result.reason)
			end
		end)
		:catch(function(err)
			warn("[CraftingController] CraftInventoryItem error:", err)
		end)
end

function CraftingController:HasActiveSession(): boolean
	return currentBlueprintId ~= nil
end

function CraftingController:KnitStart()
	CraftingService = Knit.GetService("CraftingService")
end

return CraftingController
