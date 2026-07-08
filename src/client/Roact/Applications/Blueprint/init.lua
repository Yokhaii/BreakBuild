--[=[
	Blueprint Application
	Three-panel layout:
	  Left  — PanelFrame with scrollable blueprint list
	  Center — transparent viewport showing the selected blueprint model + TopPanelFrame title
	  Right — PanelFrame with material requirements for the selected blueprint
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
local PanelFrame = require(Components.Frames.PanelFrame)
local TopPanelFrame = require(Components.Frames.TopPanelFrame)
local FancyText = require(Components.Global.FancyText)
local CloseButton = require(Components.Global.CloseButton)
local DarkOverlay = require(Components.Global.DarkOverlay)

local BlueprintList = require(script.Components.BlueprintList)
local BlueprintViewport = require(script.Components.BlueprintViewport)
local BlueprintMaterialList = require(script.Components.BlueprintMaterialList)
local RecipeList = require(Client.Roact.Applications.Furnace.Components.RecipeList)

-- Data
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)

-- Actions
local UIActions = require(Client.Rodux.Actions.UIActions)

local Config = require(script.Config)

local function BlueprintApplication(_, hooks)
	local currentFrame = RoduxHooks.useSelector(hooks, function(state)
		return state.UIReducer.CurrentFrame
	end)

	local blueprints = RoduxHooks.useSelector(hooks, function(state)
		return state.BlueprintReducer.AvailableBlueprints
	end)

	local dispatch = RoduxHooks.useDispatch(hooks)

	local isVisible = currentFrame == "Blueprint"

	local selectedBlueprint, setSelectedBlueprint = hooks.useState(nil)
	local isDraggingViewport, setIsDraggingViewport = hooks.useState(false)

	local function onClose()
		setSelectedBlueprint(nil)
		dispatch(UIActions.setCurrentFrame("HUD"))
	end

	local function onBlueprintClick(blueprintData)
		-- First click selects; second click on the same blueprint grants it
		if selectedBlueprint and selectedBlueprint.Id == blueprintData.Id then
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
			setSelectedBlueprint(nil)
			dispatch(UIActions.setCurrentFrame("HUD"))
		else
			setSelectedBlueprint(blueprintData)
		end
	end

	-- Resolve the completed 3D model from ReplicatedStorage
	local completedModel = nil
	local stationRecipes = {}
	if selectedBlueprint then
		local completedFolder = ReplicatedStorage:FindFirstChild("Assets")
			and ReplicatedStorage.Assets:FindFirstChild("CompletedBlueprints")
		if completedFolder then
			completedModel = completedFolder:FindFirstChild(selectedBlueprint.Name)
		end
		stationRecipes = Recipes.GetRecipesForStation(selectedBlueprint.Name)
	end

	if not isVisible then
		return Roact.createElement("Frame", { Visible = false, Size = UDim2.fromScale(0, 0), BackgroundTransparency = 1 })
	end

	-- The three panels are positioned relative to the backpack frame (same parent coordinate space).
	-- We use the same anchor strategy as Furnace: positioned relative to the InventoryFrame.
	-- Wrap everything in a full-screen transparent frame so positions are screen-relative.
	return Roact.createElement(DarkOverlay, {
		Name = "BlueprintOverlay",
		ZIndex = 10,
		OnClose = not isDraggingViewport and onClose or nil,
	}, {
		-- Left panel: blueprint list
		LeftPanel = Roact.createElement(PanelFrame, {
			Name = "BlueprintListPanel",
			AnchorPoint = Config.LeftPanelAnchorPoint,
			Position = Config.LeftPanelPosition,
			Size = Config.LeftPanelSize,
			AspectRatio = Config.LeftPanelAspectRatio,
			Title = "Blueprints",
			ZIndex = 12,
		}, {
			BlueprintList = Roact.createElement(BlueprintList, {
				Size = UDim2.fromScale(1, 1),
				Blueprints = blueprints,
				SelectedBlueprintId = selectedBlueprint and selectedBlueprint.Id or nil,
				OnBlueprintClick = onBlueprintClick,
				ZIndex = 13,
			}),
		}),

		-- Center title panel — centered horizontally near the top
		TitlePanel = Roact.createElement(TopPanelFrame, {
			Name = "BlueprintTitlePanel",
			AnchorPoint = Config.TitlePanelAnchorPoint,
			Position = Config.TitlePanelPosition,
			Size = Config.TitlePanelSize,
			ZIndex = 12,
		}, {
			Title = Roact.createElement(FancyText, {
				Text = selectedBlueprint and selectedBlueprint.Name or "Select a Blueprint",
				Size = Config.TitleSize,
				Position = Config.TitlePosition,
				AnchorPoint = Config.TitleAnchorPoint,
				TextScaled = true,
				ZIndex = Config.TitleZIndex,
			}),

			CloseButton = Roact.createElement(CloseButton, {
				Position = Config.CloseBtnPosition,
				AnchorPoint = Config.CloseBtnAnchorPoint,
				Size = Config.CloseBtnSize,
				OnClick = onClose,
				ZIndex = Config.TitleZIndex,
			}),
		}),

		-- Center viewport — no background, just the 3D model
		Viewport = selectedBlueprint and Roact.createElement(BlueprintViewport, {
			Model = completedModel,
			Size = Config.ViewportSize,
			Position = Config.ViewportPosition,
			AnchorPoint = Config.ViewportAnchorPoint,
			ZIndex = 11,
			OnDragStart = function()
				setIsDraggingViewport(true)
			end,
			OnDragEnd = function()
				setIsDraggingViewport(false)
			end,
		}) or nil,

		-- Material strip — bare icon row below the viewport, no background
		MaterialStrip = selectedBlueprint and Roact.createElement(BlueprintMaterialList, {
			Materials = selectedBlueprint.Materials,
			Size = Config.MaterialStripSize,
			Position = Config.MaterialStripPosition,
			AnchorPoint = Config.MaterialStripAnchorPoint,
			ZIndex = 12,
		}) or nil,

		-- Right panel: craftable recipes for this station
		RightPanel = selectedBlueprint and Roact.createElement(PanelFrame, {
			Name = "BlueprintRecipePanel",
			AnchorPoint = Config.RightPanelAnchorPoint,
			Position = Config.RightPanelPosition,
			Size = Config.RightPanelSize,
			AspectRatio = Config.RightPanelAspectRatio,
			Title = "Recipes",
			ZIndex = 12,
		}, {
			RecipeList = Roact.createElement(RecipeList, {
				Size = UDim2.fromScale(1, 1),
				Recipes = stationRecipes,
				ZIndex = 13,
			}),
		}) or nil,
	})
end

BlueprintApplication = RoactHooks.new(Roact)(BlueprintApplication)
return BlueprintApplication
