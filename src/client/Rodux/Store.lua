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
local CraftingPoolReducer = require(Reducers.CraftingPoolReducer)
local ChestReducer = require(Reducers.ChestReducer)
local ShopReducer = require(Reducers.ShopReducer)
local NotificationReducer = require(Reducers.NotificationReducer)
local TextNotificationReducer = require(Reducers.TextNotificationReducer)
local BiomeTransitionReducer = require(Reducers.BiomeTransitionReducer)

-- Modules
local Rodux = require(ReplicatedStorage.Packages.Rodux)

-- Store
local StoreReducer = Rodux.combineReducers({
	TemplateReducer = TemplateReducer,
	InventoryReducer = InventoryReducer,
	UIReducer = UIReducer,
	BlueprintReducer = BlueprintReducer,
	CraftingReducer = CraftingReducer,
	CraftingPoolReducer = CraftingPoolReducer,
	ChestReducer = ChestReducer,
	ShopReducer = ShopReducer,
	NotificationReducer = NotificationReducer,
	TextNotificationReducer = TextNotificationReducer,
	BiomeTransitionReducer = BiomeTransitionReducer,
})

local Store = Rodux.Store.new(StoreReducer, nil, {
})

return Store
