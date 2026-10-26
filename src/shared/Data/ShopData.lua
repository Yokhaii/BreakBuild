local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local ShopData = {}

ShopData.Prices = {
	-- Blocks
	Dirt = { buyPrice = 10 },
	Grass = { buyPrice = 10 },
	Stone = { buyPrice = 20 },
	Sand = { buyPrice = 10 },
	Log = { buyPrice = 16 },
	SprucePlank = { buyPrice = 24 },
	HalfStone = { buyPrice = 12 },

	-- Ores
	StoneShard = { buyPrice = 30 },
	IronOre = { buyPrice = 60 },
	Coal = { buyPrice = 40 },
	Charcoal = { buyPrice = 36 },
	IronIngot = { buyPrice = 100 },
	RawGold = { buyPrice = 160 },
	RawDiamond = { buyPrice = 300 },

	-- Tools
	WoodenPickaxe = { buyPrice = 80 },
	StonePickaxe = { buyPrice = 160 },
	IronPickaxe = { buyPrice = 320 },
	SteelPickaxe = { buyPrice = 600 },
	WoodenAxe = { buyPrice = 80 },
	StoneAxe = { buyPrice = 160 },
	IronAxe = { buyPrice = 320 },
	SteelAxe = { buyPrice = 600 },
	WoodenShovel = { buyPrice = 80 },
	StoneShovel = { buyPrice = 160 },
	IronShovel = { buyPrice = 320 },
	SteelShovel = { buyPrice = 600 },
	WoodenSword = { buyPrice = 100 },
	StoneSword = { buyPrice = 200 },
	IronSword = { buyPrice = 400 },
	SteelSword = { buyPrice = 800 },

	-- Blueprints
	WorkbenchBlueprint = { buyPrice = 200 },
	FurnaceBlueprint = { buyPrice = 400 },
	ChestBlueprint = { buyPrice = 240 },

	-- Structures
	CompletedWorkbench = { buyPrice = 1000 },
	CompletedFurnace = { buyPrice = 1600 },
	CompletedChest = { buyPrice = 1000 },
}

function ShopData.GetBuyPrice(itemName: string): number?
	local entry = ShopData.Prices[itemName]
	if entry then
		return entry.buyPrice
	end
	return nil
end

function ShopData.GetSellPrice(itemName: string): number?
	local entry = ShopData.Prices[itemName]
	if entry then
		return math.max(1, math.floor(entry.buyPrice / 10))
	end
	return nil
end

function ShopData.GetShopItems(): { any }
	local items = {}
	for itemName, _ in pairs(ShopData.Prices) do
		local itemConfig = ItemData.GetItem(itemName)
		if itemConfig then
			table.insert(items, itemConfig)
		end
	end
	table.sort(items, function(a, b)
		if a.type ~= b.type then
			return a.type < b.type
		end
		return a.displayName < b.displayName
	end)
	return items
end

function ShopData.GetItemsByCategory(category: string?): { any }
	if not category then
		return ShopData.GetShopItems()
	end

	local items = {}
	for itemName, _ in pairs(ShopData.Prices) do
		local itemConfig = ItemData.GetItem(itemName)
		if itemConfig and itemConfig.type == category then
			table.insert(items, itemConfig)
		end
	end
	table.sort(items, function(a, b)
		return a.displayName < b.displayName
	end)
	return items
end

return ShopData
