--[=[
	LogCutter Application
	Mounted as a child of the Backpack's InventoryFrame when CurrentFrame == "LogCutter".
	Positions are relative to the InventoryFrame.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local RunService = game:GetService("RunService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components
local PanelFrame = require(Components.Frames.PanelFrame)
local TopPanelFrame = require(Components.Frames.TopPanelFrame)
local FancyText = require(Components.Global.FancyText)
local ItemSlot = require(Components.Global.ItemSlot)
local StudBackground = require(Components.Global.StudBackground)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local RecipeList = require(script.Components.RecipeList)

local Config = require(script.Config)

local function LogCutterApplication(props, hooks)
	local onHoverStart = props.OnHoverStart
	local onHoverEnd = props.OnHoverEnd
	local craftingState = RoduxHooks.useSelector(hooks, function(state)
		return state.CraftingReducer
	end)

	local inventoryState = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer
	end)

	local function countItem(itemName)
		local total = 0
		for _, item in pairs(inventoryState.Backpack or {}) do
			if item and item.itemName == itemName then
				total = total + (item.quantity or 1)
			end
		end
		for _, item in pairs(inventoryState.Hotbar or {}) do
			if item and item.itemName == itemName then
				total = total + (item.quantity or 1)
			end
		end
		return total
	end

	local selectedRecipe, setSelectedRecipe = hooks.useState(nil)
	local craftCount, setCraftCount = hooks.useState(1)
	local craftProgress, setCraftProgress = hooks.useState(0)

	local activeSession = craftingState.ActiveSession
	local currentCraft = craftingState.CurrentCraft
	local recipes = activeSession and activeSession.recipes or {}

	hooks.useEffect(function()
		if not currentCraft then
			setCraftProgress(0)
			return
		end

		local connection = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - currentCraft.startedAt
			local progress = math.clamp(elapsed / currentCraft.craftTime, 0, 1)
			setCraftProgress(progress)
		end)

		return function()
			connection:Disconnect()
		end
	end, { currentCraft })

	local function onRecipeSelect(recipeId)
		local recipe = recipes[recipeId]
		if recipe then
			if selectedRecipe and selectedRecipe.id == recipeId then
				setCraftCount(math.min(craftCount + 1, 99))
			else
				setSelectedRecipe(recipe)
				setCraftCount(1)
			end
		end
	end

	local function onCraft()
		if not selectedRecipe then return end
		local CraftingController = Knit.GetController("CraftingController")
		if CraftingController then
			CraftingController:CraftItem(selectedRecipe.id, craftCount)
			setCraftCount(1)
		end
	end

	local function onRemove()
		if not selectedRecipe then return end
		if craftCount <= 1 then
			setSelectedRecipe(nil)
			setCraftCount(1)
		else
			setCraftCount(craftCount - 1)
		end
	end

	-- Build top panel content
	local topPanelChildren = {}

	topPanelChildren.Title = Roact.createElement(FancyText, {
		Text = Config.TitleText,
		AnchorPoint = Config.TitleAnchorPoint,
		Position = Config.TitlePosition,
		Size = Config.TitleSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = Config.TitleZIndex,
	})

	local input1Image = nil
	local input2Image = nil
	local outputImage = nil
	local hasInput1 = false
	local hasInput2 = false
	local canCraft = false

	if selectedRecipe then
		if selectedRecipe.inputs[1] then
			input1Image = Images[selectedRecipe.inputs[1].itemName]
			hasInput1 = countItem(selectedRecipe.inputs[1].itemName) >= selectedRecipe.inputs[1].quantity * craftCount
		end
		if selectedRecipe.inputs[2] then
			input2Image = Images[selectedRecipe.inputs[2].itemName]
			hasInput2 = countItem(selectedRecipe.inputs[2].itemName) >= selectedRecipe.inputs[2].quantity * craftCount
		else
			hasInput2 = true
		end
		if selectedRecipe.outputs[1] then
			outputImage = Images[selectedRecipe.outputs[1].itemName]
		end
		canCraft = hasInput1 and hasInput2
	end

	topPanelChildren.CraftingArea = Roact.createElement("Frame", {
		Size = Config.CraftingAreaSize,
		Position = Config.CraftingAreaPosition,
		AnchorPoint = Config.CraftingAreaAnchorPoint,
		BackgroundTransparency = 1,
		ZIndex = 12,
	}, {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = Config.CraftingAreaPadding,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),

		InputSlot1 = Roact.createElement(ItemSlot, {
			Name = "InputSlot1",
			Size = Config.SlotSize,
			Image = input1Image,
			ImageTransparency = (not hasInput1 and input1Image) and Config.MissingImageTransparency or nil,
			BackgroundColor = (not hasInput1 and input1Image) and Config.MissingSlotBackgroundColor or nil,
			ItemName = selectedRecipe and selectedRecipe.inputs[1] and selectedRecipe.inputs[1].itemName or nil,
			Quantity = selectedRecipe and selectedRecipe.inputs[1] and (selectedRecipe.inputs[1].quantity * craftCount) or nil,
			OnHoverStart = onHoverStart,
			OnHoverEnd = onHoverEnd,
			ZIndex = 12,
			LayoutOrder = 1,
		}),

		InputSlot2 = Roact.createElement(ItemSlot, {
			Name = "InputSlot2",
			Size = Config.SlotSize,
			Image = input2Image,
			ImageTransparency = (not hasInput2 and input2Image) and Config.MissingImageTransparency or nil,
			BackgroundColor = (not hasInput2 and input2Image) and Config.MissingSlotBackgroundColor or nil,
			ItemName = selectedRecipe and selectedRecipe.inputs[2] and selectedRecipe.inputs[2].itemName or nil,
			Quantity = selectedRecipe and selectedRecipe.inputs[2] and (selectedRecipe.inputs[2].quantity * craftCount) or nil,
			OnHoverStart = onHoverStart,
			OnHoverEnd = onHoverEnd,
			ZIndex = 12,
			LayoutOrder = 2,
		}),

		Arrow = Roact.createElement("TextLabel", {
			Size = Config.ArrowSize,
			BackgroundTransparency = 1,
			Text = Config.ArrowText,
			TextColor3 = Config.ArrowColor,
			TextScaled = true,
			FontFace = Config.ArrowFont,
			LayoutOrder = 3,
			ZIndex = 12,
		}),

		OutputSlot = Roact.createElement(ItemSlot, {
			Name = "OutputSlot",
			Size = Config.SlotSize,
			Image = outputImage,
			ImageTransparency = (not canCraft and outputImage) and Config.MissingImageTransparency or nil,
			BackgroundColor = (not canCraft and outputImage) and Config.MissingSlotBackgroundColor or nil,
			ItemName = selectedRecipe and selectedRecipe.outputs[1] and selectedRecipe.outputs[1].itemName or nil,
			Quantity = selectedRecipe and selectedRecipe.outputs[1] and (selectedRecipe.outputs[1].quantity * craftCount) or nil,
			OnHoverStart = onHoverStart,
			OnHoverEnd = onHoverEnd,
			ZIndex = 12,
			LayoutOrder = 4,
		}),
	})

	topPanelChildren.CraftButton = selectedRecipe and Roact.createElement("TextButton", {
		Size = Config.CraftButtonSize,
		Position = Config.CraftButtonPosition,
		AnchorPoint = Config.CraftButtonAnchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = Config.CraftButtonText,
		TextColor3 = Config.CraftButtonTextColor,
		TextScaled = true,
		FontFace = Config.CraftButtonFont,
		ZIndex = 14,
		AutoButtonColor = false,
		[Roact.Event.MouseButton1Click] = onCraft,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CraftButtonCornerRadius,
		}),
		StudBackground = Roact.createElement(StudBackground, {
			ZIndex = 12,
			BackgroundColor = Config.CraftButtonColor,
			ImageTransparency = Config.CraftButtonStudImageTransparency,
			CornerRadius = Config.CraftButtonCornerRadius,
		}),
		UIPadding = Roact.createElement("UIPadding", {
			PaddingLeft = Config.CraftButtonPaddingH,
			PaddingRight = Config.CraftButtonPaddingH,
			PaddingTop = Config.CraftButtonPaddingV,
			PaddingBottom = Config.CraftButtonPaddingV,
		}),
	}) or nil

	if currentCraft then
		topPanelChildren.ProgressBar = Roact.createElement("Frame", {
			Size = Config.ProgressBarSize,
			Position = Config.ProgressBarPosition,
			AnchorPoint = Config.ProgressBarAnchorPoint,
			BackgroundColor3 = Config.ProgressBarBackgroundColor,
			BorderSizePixel = 0,
			ZIndex = 13,
			ClipsDescendants = true,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.ProgressBarCornerRadius,
			}),
			Fill = Roact.createElement("Frame", {
				Size = UDim2.fromScale(craftProgress, 1),
				BackgroundColor3 = Config.ProgressBarFillColor,
				BorderSizePixel = 0,
				ZIndex = 14,
			}, {
				UICorner = Roact.createElement("UICorner", {
					CornerRadius = Config.ProgressBarCornerRadius,
				}),
			}),
		})
	end

	return Roact.createFragment({
		LogCutterPanel = Roact.createElement(PanelFrame, {
			Name = "LogCutterPanel",
			AnchorPoint = Config.PanelAnchorPoint,
			Position = Config.PanelPosition,
			Size = Config.PanelSize,
			AspectRatio = Config.PanelAspectRatio,
			Title = "Recipes",
			ZIndex = 11,
		}, {
			RecipeList = Roact.createElement(RecipeList, {
				Size = UDim2.fromScale(1, 1),
				Recipes = recipes,
				OnRecipeSelect = onRecipeSelect,
				OnRemove = onRemove,
				SelectedRecipeId = selectedRecipe and selectedRecipe.id or nil,
				CountItem = countItem,
				ZIndex = 12,
			}),
		}),

		LogCutterTopPanel = Roact.createElement(TopPanelFrame, {
			Name = "LogCutterTopPanel",
			AnchorPoint = Config.TopPanelAnchorPoint,
			Position = Config.TopPanelPosition,
			Size = Config.TopPanelSize,
			ZIndex = 11,
		}, topPanelChildren),
	})
end

LogCutterApplication = RoactHooks.new(Roact)(LogCutterApplication)
return LogCutterApplication
