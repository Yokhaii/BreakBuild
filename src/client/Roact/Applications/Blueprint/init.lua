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
local BlueprintList = require(script.Components.BlueprintList)

-- Actions
local UIActions = require(Client.Rodux.Actions.UIActions)

local function BlueprintApplication(_, hooks)
	local currentFrame = RoduxHooks.useSelector(hooks, function(state)
		return state.UIReducer.CurrentFrame
	end)

	local blueprints = RoduxHooks.useSelector(hooks, function(state)
		return state.BlueprintReducer.AvailableBlueprints
	end)

	local dispatch = RoduxHooks.useDispatch(hooks)

	local isVisible = currentFrame == "Blueprint"

	local function onClose()
		dispatch(UIActions.setCurrentFrame("HUD"))
	end

	local function onBlueprintClick(blueprintData)
		print("Blueprint selected:", blueprintData.Name)

		local itemName = blueprintData.Name .. "Blueprint"

		local InventoryService = Knit.GetService("InventoryService")
		InventoryService:AddItem(itemName, 1)
			:andThen(function(success)
				if success then
					print("Blueprint item added to inventory:", itemName)
				else
					warn("Failed to add blueprint item to inventory")
				end
			end)
			:catch(function(err)
				warn("Error adding blueprint item:", err)
			end)

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
			Blueprints = blueprints,
			OnBlueprintClick = onBlueprintClick,
			ZIndex = 15,
		}),
	})
end

BlueprintApplication = RoactHooks.new(Roact)(BlueprintApplication)
return BlueprintApplication
