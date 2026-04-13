--[=[
	Blueprint Reducer
	Manages blueprint UI state in Rodux store

	Used for displaying placed blueprints info in UI panels
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Rodux = require(ReplicatedStorage.Packages.Rodux)

-- Data
local BlueprintDefinitions = require(ReplicatedStorage.Shared.Data.Blueprints)

-- Build available blueprints list from definitions
local function buildAvailableBlueprints()
	local blueprints = {}
	local definitions = BlueprintDefinitions.GetAllDefinitions()

	for _, definition in pairs(definitions) do
		-- Convert block requirements to materials for display
		local materials = {}
		local materialCounts = {}

		for _, blockReq in ipairs(definition.blocks) do
			local blockType = blockReq.blockType
			if materialCounts[blockType] then
				materialCounts[blockType] = materialCounts[blockType] + 1
			else
				materialCounts[blockType] = 1
			end
		end

		for materialType, amount in pairs(materialCounts) do
			table.insert(materials, {
				Type = materialType,
				Amount = amount,
			})
		end

		table.insert(blueprints, {
			Id = definition.id,
			Name = definition.displayName or definition.name,
			Description = definition.description or "",
			Image = "rbxassetid://0", -- Replace with actual image when available
			Materials = materials,
			IsUnlocked = definition.requiredRebirth == 0, -- Unlock logic can be expanded
			RequiredRebirth = definition.requiredRebirth or 0,
			MaxQuantity = definition.maxQuantity or 1,
		})
	end

	return blueprints
end

-- Default state
local defaultState = {
	-- Available blueprints from config
	AvailableBlueprints = buildAvailableBlueprints(),
	-- Placed blueprints for UI display: { [blueprintId]: { id, blueprintType, completedAt } }
	PlacedBlueprints = {},
}

local BlueprintReducer = Rodux.createReducer(defaultState, {
	-- Add a blueprint to UI state
	addBlueprint = function(state, action)
		-- Validate blueprintData
		if type(action.blueprintData) ~= "table" or not action.blueprintData.id then
			warn("[BlueprintReducer] Invalid blueprintData in addBlueprint action")
			return state
		end

		local newPlacedBlueprints = {}
		for k, v in pairs(state.PlacedBlueprints) do
			newPlacedBlueprints[k] = v
		end

		newPlacedBlueprints[action.blueprintData.id] = {
			id = action.blueprintData.id,
			blueprintType = action.blueprintData.blueprintType,
			completedAt = action.blueprintData.completedAt or 0,
		}

		return {
			AvailableBlueprints = state.AvailableBlueprints,
			PlacedBlueprints = newPlacedBlueprints,
		}
	end,

	-- Remove a blueprint from UI state
	removeBlueprint = function(state, action)
		local newPlacedBlueprints = {}
		for k, v in pairs(state.PlacedBlueprints) do
			if k ~= action.blueprintId then
				newPlacedBlueprints[k] = v
			end
		end

		return {
			AvailableBlueprints = state.AvailableBlueprints,
			PlacedBlueprints = newPlacedBlueprints,
		}
	end,

	-- Mark a blueprint as completed
	completeBlueprint = function(state, action)
		local blueprint = state.PlacedBlueprints[action.blueprintId]
		if not blueprint then
			return state
		end

		local newPlacedBlueprints = {}
		for k, v in pairs(state.PlacedBlueprints) do
			newPlacedBlueprints[k] = v
		end

		newPlacedBlueprints[action.blueprintId] = {
			id = blueprint.id,
			blueprintType = blueprint.blueprintType,
			completedAt = os.time(),
		}

		return {
			AvailableBlueprints = state.AvailableBlueprints,
			PlacedBlueprints = newPlacedBlueprints,
		}
	end,
})

return BlueprintReducer
