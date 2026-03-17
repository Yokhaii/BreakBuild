--[=[
	Blueprint Application
	Main blueprint selection menu
]=]

-- Services
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

-- Modules
local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

-- Directories
local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components

-- Components
local BaseFrame = require(Components.Frames.BaseFrame)
local BlueprintList = require(Components.Blueprint.BlueprintList)

-- Actions
local UIActions = require(Client.Rodux.Actions.UIActions)

-- Sample blueprint data (replace with actual data from your system)
local SAMPLE_BLUEPRINTS = {
	{
		Id = "workbench",
		Name = "Workbench",
		Description = "A sturdy workbench for crafting tools and items.",
		Image = "rbxassetid://0", -- Replace with actual image
		Materials = {
			{ Type = "Wood", Amount = 20 },
			{ Type = "Stone", Amount = 10 },
		},
		IsUnlocked = true,
		RequiredRebirth = 0,
		MaxQuantity = 1,
	},
	{
		Id = "furnace",
		Name = "Furnace",
		Description = "Smelt ores and cook food with this blazing furnace.",
		Image = "rbxassetid://0", -- Replace with actual image
		Materials = {
			{ Type = "Stone", Amount = 30 },
			{ Type = "Metal", Amount = 5 },
		},
		IsUnlocked = true,
		RequiredRebirth = 0,
		MaxQuantity = 1,
	},
	{
		Id = "storage_chest",
		Name = "Storage Chest",
		Description = "Store your valuable items safely in this wooden chest.",
		Image = "rbxassetid://0", -- Replace with actual image
		Materials = {
			{ Type = "Wood", Amount = 15 },
			{ Type = "Metal", Amount = 2 },
		},
		IsUnlocked = true,
		RequiredRebirth = 0,
		MaxQuantity = 3,
	},
	{
		Id = "anvil",
		Name = "Anvil",
		Description = "Forge powerful weapons and armor at the anvil.",
		Image = "rbxassetid://0", -- Replace with actual image
		Materials = {
			{ Type = "Metal", Amount = 25 },
			{ Type = "Stone", Amount = 10 },
		},
		IsUnlocked = false,
		RequiredRebirth = 2,
		MaxQuantity = 1,
	},
	{
		Id = "research_table",
		Name = "Research Table",
		Description = "Unlock new technologies and blueprints through research.",
		Image = "rbxassetid://0", -- Replace with actual image
		Materials = {
			{ Type = "Wood", Amount = 25 },
			{ Type = "Fiber", Amount = 15 },
			{ Type = "Metal", Amount = 5 },
		},
		IsUnlocked = false,
		RequiredRebirth = 3,
		MaxQuantity = 1,
	},
}

local function BlueprintApplication(_, hooks)
	-- Get state from Rodux
	local currentFrame = RoduxHooks.useSelector(hooks, function(state)
		return state.UIReducer.CurrentFrame
	end)

	local dispatch = RoduxHooks.useDispatch(hooks)

	local isVisible = currentFrame == "Blueprint"

	local function onClose()
		dispatch(UIActions.setCurrentFrame("HUD"))
	end

	local function onBlueprintClick(blueprintData)
		print("Blueprint selected:", blueprintData.Name)

		-- TODO: Connect to your inventory/blueprint system
		-- This should:
		-- 1. Add the blueprint to player's inventory
		-- 2. Equip the Blueprint Tool
		-- Example:
		-- local BlueprintController = Knit.GetController("BlueprintController")
		-- BlueprintController:EquipBlueprint(blueprintData.Id)

		-- Close the menu after selection
		dispatch(UIActions.setCurrentFrame("HUD"))
	end

	return Roact.createElement(BaseFrame, {
		Name = "BlueprintFrame",
		Visible = isVisible,
		Title = "Blueprints",
		Position = UDim2.fromScale(0.5, 0.47),
		AspectRatio = 1.36,
		OnClose = onClose,
		ZIndex = 10,
	}, {
		BlueprintList = Roact.createElement(BlueprintList, {
			Size = UDim2.fromScale(1, 1),
			Blueprints = SAMPLE_BLUEPRINTS, -- Replace with state.BlueprintReducer.blueprints when available
			OnBlueprintClick = onBlueprintClick,
			ZIndex = 15, -- Above BaseFrame content (ZIndex 10 + offsets)
		}),
	})
end

BlueprintApplication = RoactHooks.new(Roact)(BlueprintApplication)
return BlueprintApplication
