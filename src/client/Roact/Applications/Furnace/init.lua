--[=[
	Furnace Application
	Pool-based drag-and-drop crafting system with fuel-tier support.
	Players drag items into 2 pool slots, recipe auto-matches.
	Recipe cards can be clicked to auto-fill the pool (cheapest fuel first).
	Mounted as a child of the Backpack's InventoryFrame when CurrentFrame == "Furnace".
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
local CloseButton = require(Components.Global.CloseButton)

local RecipeMatcher = require(Client.Modules.CraftingUtils.RecipeMatcher)
local Images = require(ReplicatedStorage.Shared.Data.Images)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local Store = require(Client.Rodux.Store)
local CraftingPoolActions = require(Client.Rodux.Actions.CraftingPoolActions)
local InventoryActions = require(Client.Rodux.Actions.InventoryActions)

local RecipeList = require(script.Components.RecipeList)

local Config = require(script.Config)

local function restorePoolToInventory()
	-- Get fresh pool state from store (not from component state)
	local poolState = Store:getState().CraftingPoolReducer
	if not poolState or not poolState.Pool or #poolState.Pool == 0 then
		return false
	end

	-- Save pool snapshot before clearing (prevent race conditions)
	local poolSnapshot = {}
	for _, entry in ipairs(poolState.Pool) do
		table.insert(poolSnapshot, entry)
	end

	-- Clear pool FIRST to prevent double-restoration
	Store:dispatch(CraftingPoolActions.clearCraftingPool())

	-- Get fresh inventory state after pool clear
	local inventoryState = Store:getState().InventoryReducer

	local slotTotals = {}
	for _, entry in ipairs(poolSnapshot) do
		if entry.gridIndex and entry.itemId then
			if not slotTotals[entry.gridIndex] then
				slotTotals[entry.gridIndex] = { itemId = entry.itemId, itemName = entry.itemName, totalQuantity = 0 }
			end
			slotTotals[entry.gridIndex].totalQuantity = slotTotals[entry.gridIndex].totalQuantity + entry.quantity
		end
	end

	for gridIndex, data in pairs(slotTotals) do
		local currentSlot = nil
		if gridIndex <= 21 then
			currentSlot = inventoryState.Backpack[gridIndex]
		else
			currentSlot = inventoryState.Hotbar[gridIndex - 21]
		end

		if currentSlot and currentSlot.itemName == data.itemName then
			Store:dispatch(InventoryActions.restoreGridSlot(gridIndex, {
				id = currentSlot.id,
				itemName = data.itemName,
				quantity = currentSlot.quantity + data.totalQuantity,
			}))
		else
			Store:dispatch(InventoryActions.restoreGridSlot(gridIndex, {
				id = data.itemId,
				itemName = data.itemName,
				quantity = data.totalQuantity,
			}))
		end
	end

	return true
end

local function takeItemsFromInventory(itemName, quantity)
	local currentInvState = Store:getState().InventoryReducer
	local sources = {}
	for slot = 1, 21 do
		local item = currentInvState.Backpack[slot]
		if item and item.itemName == itemName then
			table.insert(sources, { gridIndex = slot, item = item })
		end
	end
	for slot = 1, 7 do
		local item = currentInvState.Hotbar[slot]
		if item and item.itemName == itemName then
			table.insert(sources, { gridIndex = 21 + slot, item = item })
		end
	end

	local remaining = quantity
	for _, source in ipairs(sources) do
		if remaining <= 0 then break end
		local takeAmount = math.min(remaining, source.item.quantity)

		Store:dispatch(CraftingPoolActions.addToCraftingPool(
			source.item.itemName, takeAmount, source.item.id, source.gridIndex
		))

		if takeAmount >= source.item.quantity then
			Store:dispatch(InventoryActions.removeGridSlot(source.gridIndex))
		else
			Store:dispatch(InventoryActions.restoreGridSlot(source.gridIndex, {
				id = source.item.id,
				itemName = source.item.itemName,
				quantity = source.item.quantity - takeAmount,
			}))
		end

		remaining = remaining - takeAmount
	end

	return remaining <= 0
end

local function FurnaceApplication(props, hooks)
	local onHoverStart = props.OnHoverStart
	local onHoverEnd = props.OnHoverEnd

	local craftingState = RoduxHooks.useSelector(hooks, function(state)
		return state.CraftingReducer
	end)

	local inventoryState = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer
	end)

	local craftingPoolState = RoduxHooks.useSelector(hooks, function(state)
		return state.CraftingPoolReducer
	end)

	local pool = craftingPoolState.Pool or {}

	local selectedRecipeId, setSelectedRecipeId = hooks.useState(nil)
	local craftProgress, setCraftProgress = hooks.useState(0)

	local activeSession = craftingState.ActiveSession
	local currentCraft = craftingState.CurrentCraft
	local recipes = activeSession and activeSession.recipes or {}

	local slot1Ref = hooks.useValue(Roact.createRef())
	local slot2Ref = hooks.useValue(Roact.createRef())

	-- Register drop zones
	hooks.useEffect(function()
		local frame1 = slot1Ref.value:getValue()
		local frame2 = slot2Ref.value:getValue()
		local InventoryController = Knit.GetController("InventoryController")
		if not InventoryController then return end

		local cleanup1 = frame1 and InventoryController:RegisterDropZone("furnace_slot1", "craft_pool", frame1) or nil
		local cleanup2 = frame2 and InventoryController:RegisterDropZone("furnace_slot2", "craft_pool", frame2) or nil

		return function()
			if cleanup1 then cleanup1() end
			if cleanup2 then cleanup2() end
		end
	end, {})

	-- NOTE: Pool restoration on unmount is handled by InventoryController:CloseBackpack()
	-- We don't restore here to avoid double-restoration race condition

	-- Progress bar
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

	-- Auto-match recipe from pool (furnace-aware, prefer clicked recipe)
	local matchedRecipe, maxCraftCount = RecipeMatcher.MatchFurnaceRecipe(pool, recipes, selectedRecipeId)
	local actualCraftCount = matchedRecipe and maxCraftCount or 1

	-- Aggregate pool items for display (maintain insertion order)
	local aggregated = {}
	local aggregatedOrder = {}
	for _, entry in ipairs(pool) do
		if aggregated[entry.itemName] then
			aggregated[entry.itemName] = aggregated[entry.itemName] + entry.quantity
		else
			aggregated[entry.itemName] = entry.quantity
			table.insert(aggregatedOrder, entry.itemName)
		end
	end

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

	local function onRecipeSelect(recipeId)
		local recipe = recipes[recipeId]
		if not recipe then return end

		-- ALWAYS clear the pool first, regardless of recipe match
		local freshPoolState = Store:getState().CraftingPoolReducer
		local freshPool = freshPoolState and freshPoolState.Pool or {}

		if #freshPool > 0 then
			restorePoolToInventory()
		end

		setSelectedRecipeId(recipeId)

		-- Process standard inputs first, then fuel inputs
		for _, input in ipairs(recipe.inputs) do
			if not input.fuelTier then
				takeItemsFromInventory(input.itemName, input.quantity)
			end
		end

		-- Process fuel inputs (cheapest fuel first)
		for _, input in ipairs(recipe.inputs) do
			if input.fuelTier then
				local fuels = ItemData.GetFuelsByTier(input.fuelTier)
				local remainingFuelUnits = input.quantity

				for _, fuel in ipairs(fuels) do
					if remainingFuelUnits <= 0 then break end
					local multiplier = math.floor(fuel.fuelValue / input.fuelTier)
					local neededItems = math.ceil(remainingFuelUnits / multiplier)

					local currentInvState = Store:getState().InventoryReducer
					local sources = {}
					local foundQuantity = 0
					for slot = 1, 21 do
						local item = currentInvState.Backpack[slot]
						if item and item.itemName == fuel.name then
							table.insert(sources, { gridIndex = slot, item = item })
							foundQuantity = foundQuantity + item.quantity
						end
					end
					for slot = 1, 7 do
						local item = currentInvState.Hotbar[slot]
						if item and item.itemName == fuel.name then
							table.insert(sources, { gridIndex = 21 + slot, item = item })
							foundQuantity = foundQuantity + item.quantity
						end
					end

					local takeTotal = math.min(foundQuantity, neededItems)
					if takeTotal > 0 then
						local remaining = takeTotal
						for _, source in ipairs(sources) do
							if remaining <= 0 then break end
							local takeAmount = math.min(remaining, source.item.quantity)

							Store:dispatch(CraftingPoolActions.addToCraftingPool(
								source.item.itemName, takeAmount, source.item.id, source.gridIndex
							))

							if takeAmount >= source.item.quantity then
								Store:dispatch(InventoryActions.removeGridSlot(source.gridIndex))
							else
								Store:dispatch(InventoryActions.restoreGridSlot(source.gridIndex, {
									id = source.item.id,
									itemName = source.item.itemName,
									quantity = source.item.quantity - takeAmount,
								}))
							end

							remaining = remaining - takeAmount
						end
						remainingFuelUnits = remainingFuelUnits - (takeTotal * multiplier)
					end
				end
			end
		end
	end

	local function onCraft()
		if not matchedRecipe then return end
		local CraftingController = Knit.GetController("CraftingController")
		if CraftingController then
			CraftingController:CraftItem(matchedRecipe.id, actualCraftCount)
			Store:dispatch(CraftingPoolActions.clearCraftingPool())
			setSelectedRecipeId(nil)
		end
	end

	local function makeCloseHandler(itemName)
		return function()
			local currentInvState = Store:getState().InventoryReducer

			local slotTotals = {}
			for _, entry in ipairs(pool) do
				if entry.itemName == itemName and entry.gridIndex and entry.itemId then
					if not slotTotals[entry.gridIndex] then
						slotTotals[entry.gridIndex] = { itemId = entry.itemId, totalQuantity = 0 }
					end
					slotTotals[entry.gridIndex].totalQuantity = slotTotals[entry.gridIndex].totalQuantity + entry.quantity
				end
			end

			for gridIndex, data in pairs(slotTotals) do
				local currentSlot = nil
				if gridIndex <= 21 then
					currentSlot = currentInvState.Backpack[gridIndex]
				else
					currentSlot = currentInvState.Hotbar[gridIndex - 21]
				end

				if currentSlot and currentSlot.itemName == itemName then
					Store:dispatch(InventoryActions.restoreGridSlot(gridIndex, {
						id = currentSlot.id,
						itemName = itemName,
						quantity = currentSlot.quantity + data.totalQuantity,
					}))
				else
					Store:dispatch(InventoryActions.restoreGridSlot(gridIndex, {
						id = data.itemId,
						itemName = itemName,
						quantity = data.totalQuantity,
					}))
				end
			end

			Store:dispatch(CraftingPoolActions.removeFromCraftingPool(itemName))
		end
	end

	-- Build top panel children
	local topPanelChildren = {}

	topPanelChildren.Title = Roact.createElement(FancyText, {
		Text = Config.TitleText,
		AnchorPoint = Config.TitleAnchorPoint,
		Position = Config.TitlePosition,
		Size = Config.TitleSize,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = Config.TitleZIndex,
	})

	-- Build crafting area
	local craftingAreaChildren = {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = Config.CraftingAreaPadding,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}

	-- Build input slot 1
	local slot1Children = {}
	slot1Children.DropZoneOverlay = Roact.createElement("Frame", {
		Name = "DropZoneOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 15,
		[Roact.Ref] = slot1Ref.value,
	})
	slot1Children.UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
		AspectRatio = 1,
	})

	local slot1ItemName = aggregatedOrder[1]
	if slot1ItemName then
		local itemConfig = ItemData.GetItem(slot1ItemName)
		local image = Images[slot1ItemName] or ""
		local displayName = itemConfig and (itemConfig.displayName or itemConfig.name) or slot1ItemName

		slot1Children.Slot = Roact.createElement(ItemSlot, {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Image = image,
			ItemName = displayName,
			Quantity = aggregated[slot1ItemName],
			OnHoverStart = onHoverStart,
			OnHoverEnd = onHoverEnd,
			ZIndex = 12,
		})
		slot1Children.RemoveButton = Roact.createElement(CloseButton, {
			Position = UDim2.fromScale(0.95, 0.05),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromScale(0.3, 0.3),
			ZIndex = 17,
			OnClick = makeCloseHandler(slot1ItemName),
		})
	else
		slot1Children.Slot = Roact.createElement(ItemSlot, {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Image = nil,
			ItemName = nil,
			Quantity = nil,
			ZIndex = 12,
		})
	end

	craftingAreaChildren.InputSlot1 = Roact.createElement("Frame", {
		Name = "InputSlotContainer1",
		Size = Config.SlotSize,
		BackgroundTransparency = 1,
		ZIndex = 12,
		LayoutOrder = 1,
	}, slot1Children)

	-- Build input slot 2
	local slot2Children = {}
	slot2Children.DropZoneOverlay = Roact.createElement("Frame", {
		Name = "DropZoneOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 15,
		[Roact.Ref] = slot2Ref.value,
	})
	slot2Children.UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
		AspectRatio = 1,
	})

	local slot2ItemName = aggregatedOrder[2]
	if slot2ItemName then
		local itemConfig = ItemData.GetItem(slot2ItemName)
		local image = Images[slot2ItemName] or ""
		local displayName = itemConfig and (itemConfig.displayName or itemConfig.name) or slot2ItemName

		slot2Children.Slot = Roact.createElement(ItemSlot, {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Image = image,
			ItemName = displayName,
			Quantity = aggregated[slot2ItemName],
			OnHoverStart = onHoverStart,
			OnHoverEnd = onHoverEnd,
			ZIndex = 12,
		})
		slot2Children.RemoveButton = Roact.createElement(CloseButton, {
			Position = UDim2.fromScale(0.95, 0.05),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromScale(0.3, 0.3),
			ZIndex = 17,
			OnClick = makeCloseHandler(slot2ItemName),
		})
	else
		slot2Children.Slot = Roact.createElement(ItemSlot, {
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Image = nil,
			ItemName = nil,
			Quantity = nil,
			ZIndex = 12,
		})
	end

	craftingAreaChildren.InputSlot2 = Roact.createElement("Frame", {
		Name = "InputSlotContainer2",
		Size = Config.SlotSize,
		BackgroundTransparency = 1,
		ZIndex = 12,
		LayoutOrder = 2,
	}, slot2Children)

	craftingAreaChildren.Arrow = Roact.createElement("TextLabel", {
		Size = Config.ArrowSize,
		BackgroundTransparency = 1,
		Text = Config.ArrowText,
		TextColor3 = Config.ArrowColor,
		TextScaled = true,
		FontFace = Config.ArrowFont,
		LayoutOrder = 3,
		ZIndex = 12,
	})

	craftingAreaChildren.OutputSlot = Roact.createElement(ItemSlot, {
		Name = "OutputSlot",
		Size = Config.SlotSize,
		Image = matchedRecipe and matchedRecipe.outputs[1] and Images[matchedRecipe.outputs[1].itemName] or nil,
		ItemName = matchedRecipe and matchedRecipe.outputs[1] and matchedRecipe.outputs[1].itemName or nil,
		Quantity = matchedRecipe and matchedRecipe.outputs[1] and (matchedRecipe.outputs[1].quantity * actualCraftCount) or nil,
		OnHoverStart = onHoverStart,
		OnHoverEnd = onHoverEnd,
		ZIndex = 12,
		LayoutOrder = 4,
	})

	topPanelChildren.CraftingArea = Roact.createElement("Frame", {
		Size = Config.CraftingAreaSize,
		Position = Config.CraftingAreaPosition,
		AnchorPoint = Config.CraftingAreaAnchorPoint,
		BackgroundTransparency = 1,
		ZIndex = 12,
	}, craftingAreaChildren)

	-- Craft button
	local canCraft = matchedRecipe and #pool > 0
	topPanelChildren.CraftButton = canCraft and Roact.createElement("TextButton", {
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

	-- Progress bar
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
		FurnacePanel = Roact.createElement(PanelFrame, {
			Name = "FurnacePanel",
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
				OnRemove = nil,
				SelectedRecipeId = matchedRecipe and matchedRecipe.id or nil,
				CountItem = countItem,
				ZIndex = 12,
			}),
		}),

		FurnaceTopPanel = Roact.createElement(TopPanelFrame, {
			Name = "FurnaceTopPanel",
			AnchorPoint = Config.TopPanelAnchorPoint,
			Position = Config.TopPanelPosition,
			Size = Config.TopPanelSize,
			ZIndex = 11,
		}, topPanelChildren),
	})
end

FurnaceApplication = RoactHooks.new(Roact)(FurnaceApplication)
return FurnaceApplication
