--[=[
	TopPanel Component for Inventory Crafting
	NEW SYSTEM: Uses drag-and-drop with CraftingPool
	- Players drag items into the pool
	- System auto-matches recipes based on pool contents
	- Recipe cards can still be clicked to auto-fill the pool
	Positioned above the backpack grid.
	Always visible when inventory is open.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components
local TopPanelFrame = require(Components.Frames.TopPanelFrame)
local CraftingPool = require(Components.Crafting.CraftingPool)
local ItemSlot = require(Components.Global.ItemSlot)
local StudBackground = require(Components.Global.StudBackground)
local FancyText = require(Components.Global.FancyText)
local CloseButton = require(Components.Global.CloseButton)
local TutorialTargets = require(Client.Modules.TutorialTargets)

local RecipeMatcher = require(Client.Modules.CraftingUtils.RecipeMatcher)
local Images = require(ReplicatedStorage.Shared.Data.Images)
local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)

local Config = require(script.Config)

local function TopPanel(props, hooks)
	local craftCount = props.CraftCount or 1
	local onCraft = props.OnCraft
	local onHoverStart = props.OnHoverStart
	local onHoverEnd = props.OnHoverEnd
	local baseZIndex = props.ZIndex or 11
	local poolRef = hooks.useValue(Roact.createRef())

	-- Get crafting pool state
	local craftingPoolState = RoduxHooks.useSelector(hooks, function(state)
		return state.CraftingPoolReducer
	end)

	local pool = craftingPoolState.Pool or {}

	-- Get all inventory recipes
	local inventoryRecipes = Recipes.GetRecipesForStation("Inventory")

	-- Auto-match recipe based on pool contents
	local matchedRecipe, maxCraftCount = RecipeMatcher.MatchRecipe(pool, inventoryRecipes)

	-- Use the max count from pool (how many crafts we can do with what's in the pool)
	local actualCraftCount = matchedRecipe and maxCraftCount or 1

	-- Register drop zone (stable, always points to same frame)
	hooks.useEffect(function()
		local frame = poolRef.value:getValue()
		if not frame then return end

		local InventoryController = Knit.GetController("InventoryController")
		if not InventoryController then return end

		local cleanup = InventoryController:RegisterDropZone("inventory_craft_pool", "craft_pool", frame)
		return cleanup
	end, {}) -- Empty deps = only register once

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

	-- Aggregate pool items
	local aggregated = {}
	for _, entry in ipairs(pool) do
		if aggregated[entry.itemName] then
			aggregated[entry.itemName] = aggregated[entry.itemName] + entry.quantity
		else
			aggregated[entry.itemName] = entry.quantity
		end
	end

	local hasPoolItems = next(aggregated) ~= nil

	-- Input slot (same level as OutputSlot)
	local Store = require(Client.Rodux.Store)
	local CraftingPoolActions = require(Client.Rodux.Actions.CraftingPoolActions)

	local inputSlotChildren = {}

	-- Invisible drop zone overlay (full size, always present for drop detection)
	inputSlotChildren.DropZoneOverlay = Roact.createElement("Frame", {
		Name = "DropZoneOverlay",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 15,
		[Roact.Ref] = poolRef.value,
	})

	if hasPoolItems then
		-- Show filled slot content
		local firstItemName, firstQuantity = next(aggregated)
		local ItemData = require(ReplicatedStorage.Shared.Data.Items)
		local itemConfig = ItemData.GetItem(firstItemName)
		local image = Images[firstItemName] or ""
		local displayName = itemConfig and (itemConfig.displayName or itemConfig.name) or firstItemName

		inputSlotChildren.Slot = Roact.createElement(ItemSlot, {
			Name = "PoolSlot",
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Image = image,
			ItemName = displayName,
			Quantity = firstQuantity,
			OnHoverStart = onHoverStart,
			OnHoverEnd = onHoverEnd,
			ZIndex = 12,
		})

		inputSlotChildren.RemoveButton = Roact.createElement(CloseButton, {
			Position = UDim2.fromScale(0.95, 0.05),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromScale(0.3, 0.3),
			ZIndex = 17,
			OnClick = function()
				local InventoryActions = require(Client.Rodux.Actions.InventoryActions)
				local inventoryState = Store:getState().InventoryReducer

				-- Aggregate all pool entries by gridIndex first
				local slotTotals = {} -- [gridIndex] = { itemId, totalQuantity }
				for _, entry in ipairs(pool) do
					if entry.itemName == firstItemName and entry.gridIndex and entry.itemId then
						if not slotTotals[entry.gridIndex] then
							slotTotals[entry.gridIndex] = { itemId = entry.itemId, totalQuantity = 0 }
						end
						slotTotals[entry.gridIndex].totalQuantity = slotTotals[entry.gridIndex].totalQuantity + entry.quantity
					end
				end

				-- Restore to each slot once (combining with remainder)
				for gridIndex, data in pairs(slotTotals) do
					local currentSlot = nil
					if gridIndex <= 21 then
						currentSlot = inventoryState.Backpack[gridIndex]
					else
						currentSlot = inventoryState.Hotbar[gridIndex - 21]
					end

					-- If slot has items of same type, combine quantities
					if currentSlot and currentSlot.itemName == firstItemName then
						Store:dispatch(InventoryActions.restoreGridSlot(gridIndex, {
							id = currentSlot.id,
							itemName = firstItemName,
							quantity = currentSlot.quantity + data.totalQuantity,
						}))
					else
						-- Slot is empty or different item, just restore the pool items
						Store:dispatch(InventoryActions.restoreGridSlot(gridIndex, {
							id = data.itemId,
							itemName = firstItemName,
							quantity = data.totalQuantity,
						}))
					end
				end

				-- Remove from pool
				Store:dispatch(CraftingPoolActions.removeFromCraftingPool(firstItemName))
			end,
		})
	else
		-- Show empty slot (centered)
		inputSlotChildren.Slot = Roact.createElement(ItemSlot, {
			Name = "InputSlot",
			Size = UDim2.fromScale(1, 1),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Image = nil,
			ItemName = nil,
			Quantity = nil,
			ZIndex = 12,
		})
	end

	-- Add aspect ratio constraint to input slot children
	inputSlotChildren.UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
		AspectRatio = 1,
	})

	craftingAreaChildren.InputSlot = Roact.createElement("Frame", {
		Name = "InputSlotContainer",
		Size = Config.SlotSize,
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 12,
		LayoutOrder = 1,
	}, inputSlotChildren)

	craftingAreaChildren.Arrow = Roact.createElement("TextLabel", {
		Size = Config.ArrowSize,
		BackgroundTransparency = 1,
		Text = Config.ArrowText,
		TextColor3 = Config.ArrowColor,
		TextScaled = true,
		FontFace = Config.ArrowFont,
		LayoutOrder = 10,
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
		LayoutOrder = 11,
	})

	topPanelChildren.CraftingArea = Roact.createElement("Frame", {
		Size = Config.CraftingAreaSize,
		Position = Config.CraftingAreaPosition,
		AnchorPoint = Config.CraftingAreaAnchorPoint,
		BackgroundTransparency = 1,
		Active = true,
		ZIndex = 12,
	}, craftingAreaChildren)

	-- Craft button (only shows when recipe matched)
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
		[Roact.Ref] = TutorialTargets.Ref("InventoryCraftButton_" .. matchedRecipe.id),
		[Roact.Event.MouseButton1Click] = function()
			if onCraft and matchedRecipe then
				onCraft(matchedRecipe, actualCraftCount)
			end
		end,
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

	return Roact.createElement(TopPanelFrame, {
		Name = "InventoryCraftingPanel",
		AnchorPoint = Config.TopPanelAnchorPoint,
		Position = Config.TopPanelPosition,
		Size = Config.TopPanelSize,
		ZIndex = baseZIndex,
	}, topPanelChildren)
end

TopPanel = RoactHooks.new(Roact)(TopPanel)
return TopPanel
