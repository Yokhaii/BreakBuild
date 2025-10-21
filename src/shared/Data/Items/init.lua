-- ItemData.lua
-- Central item data module

local Blocks = require(script.Blocks)
local Ores = require(script.Ores)
local Tools = require(script.Tools)

local ItemData = {}

-- Combine all item categories into one table
ItemData.Items = {}

-- Add all blocks
for itemName, itemConfig in pairs(Blocks) do
	ItemData.Items[itemName] = itemConfig
end

-- Add all ores
for itemName, itemConfig in pairs(Ores) do
	ItemData.Items[itemName] = itemConfig
end

-- Add all tools
for itemName, itemConfig in pairs(Tools) do
	ItemData.Items[itemName] = itemConfig
end

--|| Helper Functions ||--

-- Get item configuration by name
function ItemData.GetItem(itemName: string)
	return ItemData.Items[itemName]
end

-- Check if an item is valid
function ItemData.IsValidItem(itemName: string): boolean
	return ItemData.Items[itemName] ~= nil
end

-- Get all items of a specific type
function ItemData.GetItemsByType(itemType: string): {any}
	local items = {}
	for itemName, itemConfig in pairs(ItemData.Items) do
		if itemConfig.type == itemType then
			items[itemName] = itemConfig
		end
	end
	return items
end

-- Search items by name (case insensitive)
function ItemData.SearchItems(query: string): {any}
	local results = {}
	local lowerQuery = string.lower(query)

	for itemName, itemConfig in pairs(ItemData.Items) do
		local displayName = string.lower(itemConfig.displayName or itemConfig.name)
		if string.find(displayName, lowerQuery, 1, true) then
			table.insert(results, itemConfig)
		end
	end

	return results
end

return ItemData
