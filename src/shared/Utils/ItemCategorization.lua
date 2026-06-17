--[=[
	ItemCategorization Utility
	Determines whether an item goes to the Hotbar or Backpack
]=]

local ItemCategorization = {}

function ItemCategorization.getItemCategory(itemConfig)
	if not itemConfig then
		return "backpack"
	end

	if itemConfig.type == "Ore" then
		return "backpack"
	end

	if itemConfig.isRemovalTool then
		return "backpack"
	end

	return "hotbar"
end

function ItemCategorization.isBlueprintTool(itemConfig)
	return itemConfig and itemConfig.isBlueprintTool == true
end

return ItemCategorization
