--[=[
	RecipeMatcher
	Utility to match crafting pool items against available recipes.
	Returns matching recipe if pool items exactly match recipe inputs.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local CraftingUtils = {}

-- Aggregate pool items by name
local function aggregatePool(pool)
	local aggregated = {}
	for _, entry in ipairs(pool) do
		if aggregated[entry.itemName] then
			aggregated[entry.itemName] = aggregated[entry.itemName] + entry.quantity
		else
			aggregated[entry.itemName] = entry.quantity
		end
	end
	return aggregated
end

-- Check if pool matches a recipe's inputs
local function doesPoolMatchRecipe(poolAggregated, recipe)
	if not recipe.inputs or #recipe.inputs == 0 then
		return false
	end

	-- Count how many different input types the recipe needs
	local recipeInputCount = #recipe.inputs
	local poolItemCount = 0
	for _ in pairs(poolAggregated) do
		poolItemCount = poolItemCount + 1
	end

	-- Must have same number of unique items
	if poolItemCount ~= recipeInputCount then
		return false
	end

	-- Check each recipe input matches pool
	for _, input in ipairs(recipe.inputs) do
		local poolQuantity = poolAggregated[input.itemName] or 0
		if poolQuantity == 0 then
			return false -- Missing required item
		end
		-- Pool quantity must be exact multiple of recipe requirement
		if poolQuantity % input.quantity ~= 0 then
			return false
		end
	end

	-- All inputs match!
	return true
end

-- Calculate max craft count based on pool quantities
local function calculateMaxCraftCount(poolAggregated, recipe)
	local maxCount = 99
	for _, input in ipairs(recipe.inputs) do
		local poolQuantity = poolAggregated[input.itemName] or 0
		local possibleCount = math.floor(poolQuantity / input.quantity)
		maxCount = math.min(maxCount, possibleCount)
	end
	return math.max(1, maxCount)
end

-- Find matching recipe from available recipes
-- preferredRecipeId: optional, checked first to disambiguate recipes with identical inputs
-- Returns: matchedRecipe, maxCraftCount
function CraftingUtils.MatchRecipe(pool, availableRecipes, preferredRecipeId)
	if not pool or #pool == 0 then
		return nil, 1
	end

	local poolAggregated = aggregatePool(pool)

	-- Check preferred recipe first
	if preferredRecipeId and availableRecipes[preferredRecipeId] then
		local recipe = availableRecipes[preferredRecipeId]
		if doesPoolMatchRecipe(poolAggregated, recipe) then
			local maxCount = calculateMaxCraftCount(poolAggregated, recipe)
			return recipe, maxCount
		end
	end

	-- Fallback: try all recipes
	for _, recipe in pairs(availableRecipes) do
		if doesPoolMatchRecipe(poolAggregated, recipe) then
			local maxCount = calculateMaxCraftCount(poolAggregated, recipe)
			return recipe, maxCount
		end
	end

	return nil, 1
end

-- Check if pool matches a furnace recipe (handles fuelTier inputs)
local function doesPoolMatchFurnaceRecipe(poolAggregated, recipe)
	if not recipe.inputs or #recipe.inputs == 0 then
		return false
	end

	local standardInputs = {}
	local fuelInput = nil
	for _, input in ipairs(recipe.inputs) do
		if input.fuelTier then
			fuelInput = input
		else
			table.insert(standardInputs, input)
		end
	end

	if not fuelInput then
		return false
	end

	-- Every pool item must either match a standard input or be valid fuel
	local standardItemNames = {}
	for _, input in ipairs(standardInputs) do
		standardItemNames[input.itemName] = true
	end

	for itemName, _ in pairs(poolAggregated) do
		local isStandardInput = standardItemNames[itemName]
		local itemConfig = ItemData.GetItem(itemName)
		local isValidFuel = itemConfig and itemConfig.fuelValue and itemConfig.fuelValue >= fuelInput.fuelTier
		if not isStandardInput and not isValidFuel then
			return false
		end
	end

	-- Standard inputs: pool quantity must be exact multiple of recipe quantity
	for _, input in ipairs(standardInputs) do
		local poolQuantity = poolAggregated[input.itemName] or 0
		if poolQuantity == 0 then
			return false
		end
		if poolQuantity % input.quantity ~= 0 then
			return false
		end
	end

	-- Fuel: compute total fuel units (subtract standard input consumption)
	-- Use craft count of 1 for the "does it match" check
	local totalFuelUnits = 0
	for itemName, poolQuantity in pairs(poolAggregated) do
		local itemConfig = ItemData.GetItem(itemName)
		if itemConfig and itemConfig.fuelValue and itemConfig.fuelValue >= fuelInput.fuelTier then
			local multiplier = math.floor(itemConfig.fuelValue / fuelInput.fuelTier)
			local availableForFuel = poolQuantity
			-- Subtract what's consumed by standard inputs
			for _, input in ipairs(standardInputs) do
				if input.itemName == itemName then
					availableForFuel = availableForFuel - input.quantity
				end
			end
			if availableForFuel > 0 then
				totalFuelUnits = totalFuelUnits + (availableForFuel * multiplier)
			end
		end
	end

	if totalFuelUnits < fuelInput.quantity then
		return false
	end
	if totalFuelUnits % fuelInput.quantity ~= 0 then
		return false
	end

	return true
end

-- Calculate max craft count for furnace recipes (handles overlap between standard and fuel)
local function calculateMaxFurnaceCraftCount(poolAggregated, recipe)
	local standardInputs = {}
	local fuelInput = nil
	for _, input in ipairs(recipe.inputs) do
		if input.fuelTier then
			fuelInput = input
		else
			table.insert(standardInputs, input)
		end
	end

	-- Max from standard inputs
	local maxFromStandard = 99
	for _, input in ipairs(standardInputs) do
		local poolQuantity = poolAggregated[input.itemName] or 0
		local possibleCount = math.floor(poolQuantity / input.quantity)
		maxFromStandard = math.min(maxFromStandard, possibleCount)
	end

	if not fuelInput then
		return math.max(1, maxFromStandard)
	end

	-- Find the max N where fuel is sufficient (iterate downward from maxFromStandard)
	for n = maxFromStandard, 1, -1 do
		local totalFuelUnits = 0
		for itemName, poolQuantity in pairs(poolAggregated) do
			local itemConfig = ItemData.GetItem(itemName)
			if itemConfig and itemConfig.fuelValue and itemConfig.fuelValue >= fuelInput.fuelTier then
				local multiplier = math.floor(itemConfig.fuelValue / fuelInput.fuelTier)
				local availableForFuel = poolQuantity
				for _, input in ipairs(standardInputs) do
					if input.itemName == itemName then
						availableForFuel = availableForFuel - (input.quantity * n)
					end
				end
				if availableForFuel > 0 then
					totalFuelUnits = totalFuelUnits + (availableForFuel * multiplier)
				end
			end
		end
		if totalFuelUnits >= fuelInput.quantity * n then
			return n
		end
	end

	return 1
end

function CraftingUtils.MatchFurnaceRecipe(pool, availableRecipes, preferredRecipeId)
	if not pool or #pool == 0 then
		return nil, 1
	end

	local poolAggregated = aggregatePool(pool)

	-- Check preferred recipe first
	if preferredRecipeId and availableRecipes[preferredRecipeId] then
		local recipe = availableRecipes[preferredRecipeId]
		if doesPoolMatchFurnaceRecipe(poolAggregated, recipe) then
			local maxCount = calculateMaxFurnaceCraftCount(poolAggregated, recipe)
			return recipe, maxCount
		end
	end

	-- Fallback: try all recipes
	for _, recipe in pairs(availableRecipes) do
		if doesPoolMatchFurnaceRecipe(poolAggregated, recipe) then
			local maxCount = calculateMaxFurnaceCraftCount(poolAggregated, recipe)
			return recipe, maxCount
		end
	end

	return nil, 1
end

return CraftingUtils
