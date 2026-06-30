-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Directories
local Reducers = StarterPlayer.StarterPlayerScripts.Client.Rodux.Reducers
local TemplateReducer = require(Reducers.TemplateReducer)
local InventoryReducer = require(Reducers.InventoryReducer)
local UIReducer = require(Reducers.UIReducer)
local BlueprintReducer = require(Reducers.BlueprintReducer)
local CraftingReducer = require(Reducers.CraftingReducer)

-- Modules
local Rodux = require(ReplicatedStorage.Packages.Rodux)

-- Store
local StoreReducer = Rodux.combineReducers({
	TemplateReducer = TemplateReducer,
	InventoryReducer = InventoryReducer,
	UIReducer = UIReducer,
	BlueprintReducer = BlueprintReducer,
	CraftingReducer = CraftingReducer,
})

local Store = Rodux.Store.new(StoreReducer, nil, {
})

return Store
