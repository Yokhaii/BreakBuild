--[[
	CutLogService.lua
	Handles cutting logs into planks at the CuttingLog station

	1 Log = 4 SprucePlank
]]

-- Knit Packages
local Knit = require(game:GetService("ReplicatedStorage").Packages.Knit)

-- Services (to be initialized)
local InventoryService

local CutLogService = Knit.CreateService({
	Name = "CutLogService",
	Client = {
		-- Signals for client feedback
		LogCut = Knit.CreateSignal(), -- (logsUsed, planksReceived)
		CutFailed = Knit.CreateSignal(), -- (reason)
	},
})

-- Constants
local LOG_ITEM_NAME = "Log"
local PLANK_ITEM_NAME = "SprucePlank"
local PLANKS_PER_LOG = 4

--|| Private Functions ||--

-- Find all logs in player's inventory and return total count
local function countLogs(inventory)
	local totalLogs = 0

	-- Check hotbar
	for slot = 1, 10 do
		local item = inventory.Hotbar[slot]
		if item and item.itemName == LOG_ITEM_NAME then
			totalLogs = totalLogs + item.quantity
		end
	end

	-- Check backpack
	for _, item in ipairs(inventory.Backpack) do
		if item.itemName == LOG_ITEM_NAME then
			totalLogs = totalLogs + item.quantity
		end
	end

	return totalLogs
end

-- Remove logs from inventory (removes from first stack found, then next, etc.)
local function removeLogs(player, inventory, amount)
	local remaining = amount

	-- Remove from hotbar first
	for slot = 1, 10 do
		if remaining <= 0 then break end

		local item = inventory.Hotbar[slot]
		if item and item.itemName == LOG_ITEM_NAME then
			local toRemove = math.min(item.quantity, remaining)
			InventoryService:RemoveItem(player, item.id, toRemove)
			remaining = remaining - toRemove
		end
	end

	-- Remove from backpack if needed
	for _, item in ipairs(inventory.Backpack) do
		if remaining <= 0 then break end

		if item.itemName == LOG_ITEM_NAME then
			local toRemove = math.min(item.quantity, remaining)
			InventoryService:RemoveItem(player, item.id, toRemove)
			remaining = remaining - toRemove
		end
	end

	return remaining <= 0
end

--|| Public Functions ||--

-- Cut a single log into planks
function CutLogService:CutLog(player: Player): (boolean, string?)
	local inventory = InventoryService:GetInventory(player)
	if not inventory then
		self.Client.CutFailed:Fire(player, "No inventory found")
		return false, "No inventory found"
	end

	local logCount = countLogs(inventory)
	if logCount < 1 then
		self.Client.CutFailed:Fire(player, "No logs in inventory")
		return false, "No logs in inventory"
	end

	-- Remove 1 log
	if not removeLogs(player, inventory, 1) then
		self.Client.CutFailed:Fire(player, "Failed to remove log")
		return false, "Failed to remove log"
	end

	-- Add planks
	InventoryService:AddItem(player, PLANK_ITEM_NAME, PLANKS_PER_LOG)

	-- Notify client
	self.Client.LogCut:Fire(player, 1, PLANKS_PER_LOG)

	print("[CutLogService] Player", player.Name, "cut 1 log into", PLANKS_PER_LOG, "planks")
	return true
end

-- Cut all logs into planks
function CutLogService:CutAllLogs(player: Player): (boolean, string?)
	local inventory = InventoryService:GetInventory(player)
	if not inventory then
		self.Client.CutFailed:Fire(player, "No inventory found")
		return false, "No inventory found"
	end

	local logCount = countLogs(inventory)
	if logCount < 1 then
		self.Client.CutFailed:Fire(player, "No logs in inventory")
		return false, "No logs in inventory"
	end

	-- Remove all logs
	if not removeLogs(player, inventory, logCount) then
		self.Client.CutFailed:Fire(player, "Failed to remove logs")
		return false, "Failed to remove logs"
	end

	-- Add planks
	local totalPlanks = logCount * PLANKS_PER_LOG
	InventoryService:AddItem(player, PLANK_ITEM_NAME, totalPlanks)

	-- Notify client
	self.Client.LogCut:Fire(player, logCount, totalPlanks)

	print("[CutLogService] Player", player.Name, "cut", logCount, "logs into", totalPlanks, "planks")
	return true
end

-- Get log count for a player (for UI feedback)
function CutLogService:GetLogCount(player: Player): number
	local inventory = InventoryService:GetInventory(player)
	if not inventory then return 0 end
	return countLogs(inventory)
end

--|| Client Functions ||--

function CutLogService.Client:CutLog(player: Player)
	return self.Server:CutLog(player)
end

function CutLogService.Client:CutAllLogs(player: Player)
	return self.Server:CutAllLogs(player)
end

function CutLogService.Client:GetLogCount(player: Player)
	return self.Server:GetLogCount(player)
end

--|| Knit Start ||--

function CutLogService:KnitStart()
	InventoryService = Knit.GetService("InventoryService")
	print("[CutLogService] Started")
end

return CutLogService
