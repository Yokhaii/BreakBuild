--[=[
	ItemCategorization Utility
	Determines which hotbar mode an item belongs to
]=]

local ItemCategorization = {}

--[=[
	Returns the category for an item based on its config properties
	@param itemConfig - The item configuration table from ItemData
	@return "break" | "build" | "backpack"
]=]
function ItemCategorization.getItemCategory(itemConfig)
	if not itemConfig then
		return "backpack"
	end

	-- Ores always go to backpack only
	if itemConfig.type == "Ore" then
		return "backpack"
	end

	-- Breaking tools go to Break hotbar
	if itemConfig.isBreakingTool then
		return "break"
	end

	-- Hammer (removal tool) goes to Build hotbar
	if itemConfig.isRemovalTool then
		return "build"
	end

	-- Blocks go to Build hotbar
	if itemConfig.type == "Block" then
		return "build"
	end

	-- Default to backpack for uncategorized items
	return "backpack"
end

--[=[
	Checks if an item can be placed in a specific hotbar mode
	@param itemConfig - The item configuration table
	@param mode - "Break" or "Build"
	@return boolean
]=]
function ItemCategorization.canPlaceInMode(itemConfig, mode)
	local category = ItemCategorization.getItemCategory(itemConfig)

	if mode == "Break" then
		return category == "break"
	elseif mode == "Build" then
		return category == "build"
	end

	return false
end

return ItemCategorization
