local Workbench = require(script.Workbench)
local StoneCutter = require(script.StoneCutter)
local Furnace = require(script.Furnace)

local Recipes = {}
Recipes.All = {}

for id, recipe in pairs(Workbench) do
	Recipes.All[id] = recipe
end

for id, recipe in pairs(StoneCutter) do
	Recipes.All[id] = recipe
end

for id, recipe in pairs(Furnace) do
	Recipes.All[id] = recipe
end

function Recipes.GetRecipe(recipeId: string)
	return Recipes.All[recipeId]
end

function Recipes.GetRecipesForStation(stationType: string)
	local results = {}
	for id, recipe in pairs(Recipes.All) do
		if recipe.stationType == stationType then
			results[id] = recipe
		end
	end
	return results
end

return Recipes
