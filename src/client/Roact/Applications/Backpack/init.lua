--[=[
	Backpack Application
	Full-screen inventory overlay with 7x4 grid (21 backpack + 7 hotbar slots)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local DarkOverlay = require(Components.Global.DarkOverlay)
local ItemTooltip = require(Components.Global.ItemTooltip)

local BackpackSlot = require(script.Components.BackpackSlot)
local DevItemPicker = require(Components.Global.DevItemPicker)
local LeftPanel = require(Components.Inventory.LeftPanel)
local TopPanel = require(Components.Inventory.TopPanel)
local WorkbenchApplication = require(Client.Roact.Applications.Workbench)
local FurnaceApplication = require(Client.Roact.Applications.Furnace)
local ChestApplication = require(Client.Roact.Applications.Chest)
local ShopApplication = require(Client.Roact.Applications.Shop)

local Config = require(script.Config)

local function Backpack(props, hooks)
	local inventoryState = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer
	end)

	local backpackItems = inventoryState.Backpack or {}
	local hotbar = inventoryState.Hotbar or {}
	local equippedSlot = inventoryState.EquippedSlot
	local isOpen = inventoryState.BackpackOpen
	local isDevPickerOpen = inventoryState.DevPickerOpen

	local currentFrame = RoduxHooks.useSelector(hooks, function(state)
		return state.UIReducer.CurrentFrame
	end)
	local isWorkbenchOpen = currentFrame == "Workbench"
	local isFurnaceOpen = currentFrame == "Furnace"
	local isChestOpen = currentFrame == "Chest"
	local isShopOpen = currentFrame == "Shop"

	local hoveredItemName, setHoveredItemName = hooks.useState(nil)
	local selectedInventoryRecipe, setSelectedInventoryRecipe = hooks.useState(nil)
	local inventoryCraftCount, setInventoryCraftCount = hooks.useState(1)
	local inventoryCraftProgress, setInventoryCraftProgress = hooks.useState(0)
	local isInventoryCrafting, setIsInventoryCrafting = hooks.useState(false)

	-- Clear pool when inventory closes/opens
	hooks.useEffect(function()
		if not isOpen then
			-- Inventory just closed, pool cleanup already handled in InventoryController
			return
		end
	end, { isOpen })

	local function countItem(itemName)
		local total = 0
		for _, item in pairs(backpackItems) do
			if item and item.itemName == itemName then
				total = total + (item.quantity or 1)
			end
		end
		for _, item in pairs(hotbar) do
			if item and item.itemName == itemName then
				total = total + (item.quantity or 1)
			end
		end
		return total
	end

	local function handleInventoryRecipeSelect(recipeId)
		local Recipes = require(ReplicatedStorage.Shared.Data.Recipes)
		local recipe = Recipes.GetRecipe(recipeId)
		if not recipe then return end

		local Store = require(Client.Rodux.Store)
		local CraftingPoolActions = require(Client.Rodux.Actions.CraftingPoolActions)
		local InventoryActions = require(Client.Rodux.Actions.InventoryActions)

		-- ALWAYS clear the pool first before adding new recipe items
		local poolState = Store:getState().CraftingPoolReducer
		if poolState and poolState.Pool and #poolState.Pool > 0 then
			-- Restore all pool items back to inventory first
			local poolSnapshot = {}
			for _, entry in ipairs(poolState.Pool) do
				table.insert(poolSnapshot, entry)
			end

			Store:dispatch(CraftingPoolActions.clearCraftingPool())

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
		end

		-- Now add new recipe items to pool
		-- Re-read fresh inventory state after pool restoration
		local freshInventoryState = Store:getState().InventoryReducer
		local freshBackpack = freshInventoryState.Backpack or {}
		local freshHotbar = freshInventoryState.Hotbar or {}

		-- Check if player has the required items
		for _, input in ipairs(recipe.inputs) do
			local foundQuantity = 0
			local foundItems = {}

			-- Search inventory for items (using fresh state)
			for slot = 1, 21 do
				local item = freshBackpack[slot]
				if item and item.itemName == input.itemName then
					table.insert(foundItems, { gridIndex = slot, item = item })
					foundQuantity = foundQuantity + item.quantity
				end
			end
			for slot = 1, 7 do
				local item = freshHotbar[slot]
				if item and item.itemName == input.itemName then
					table.insert(foundItems, { gridIndex = 21 + slot, item = item })
					foundQuantity = foundQuantity + item.quantity
				end
			end

			-- If we have enough, add to pool and remove from inventory
			if foundQuantity >= input.quantity then
				local remaining = input.quantity
				for _, found in ipairs(foundItems) do
					if remaining <= 0 then break end
					local takeAmount = math.min(remaining, found.item.quantity)

					-- Add to crafting pool
					Store:dispatch(CraftingPoolActions.addToCraftingPool(
						found.item.itemName,
						takeAmount,
						found.item.id,
						found.gridIndex
					))

					-- Only remove from inventory if we're taking the entire stack
					if takeAmount >= found.item.quantity then
						Store:dispatch(InventoryActions.removeGridSlot(found.gridIndex))
					else
						-- Keep the remainder in inventory (update quantity)
						local remainingItem = {
							id = found.item.id,
							itemName = found.item.itemName,
							quantity = found.item.quantity - takeAmount,
						}
						Store:dispatch(InventoryActions.restoreGridSlot(found.gridIndex, remainingItem))
					end

					remaining = remaining - takeAmount
				end
			end
		end

		if selectedInventoryRecipe and selectedInventoryRecipe.id == recipeId then
			setInventoryCraftCount(math.min(inventoryCraftCount + 1, 99))
		else
			setSelectedInventoryRecipe(recipe)
			setInventoryCraftCount(1)
		end
	end

	local function handleInventoryRecipeRemove()
		if not selectedInventoryRecipe then return end
		if inventoryCraftCount <= 1 then
			setSelectedInventoryRecipe(nil)
			setInventoryCraftCount(1)
		else
			setInventoryCraftCount(inventoryCraftCount - 1)
		end
	end

	local function handleInventoryCraft(recipe, craftCount)
		-- NEW: Craft from pool (recipe auto-matched from pool contents)
		local CraftingController = Knit.GetController("CraftingController")
		local Store = require(Client.Rodux.Store)
		local CraftingPoolActions = require(Client.Rodux.Actions.CraftingPoolActions)

		if CraftingController then
			-- Inventory crafting is instant (no timer needed)
			-- Recipe is passed from TopPanel (auto-matched)
			CraftingController:CraftInventoryItem(recipe.id, craftCount)
			-- Clear crafting pool after successful craft
			Store:dispatch(CraftingPoolActions.clearCraftingPool())
			-- Clear selected recipe and reset count
			setSelectedInventoryRecipe(nil)
			setInventoryCraftCount(1)
		end
	end

	if not isOpen then
		return Roact.createElement("Frame", { Visible = false })
	end

	local function handleHoverStart(itemName)
		setHoveredItemName(itemName)
	end

	local function handleHoverEnd()
		setHoveredItemName(nil)
	end

	local function handleDragStart(gridIndex, item)
		setHoveredItemName(nil)
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController then
			InventoryController:StartDrag(gridIndex, item)
		end
	end

	local function handleBackgroundClick()
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController then
			InventoryController:CloseBackpack()
		end
	end

	-- Build backpack grid slots (rows 1-3, grid indices 1-21)
	local backpackGridChildren = {
		UIGridLayout = Roact.createElement("UIGridLayout", {
			CellSize = UDim2.fromScale(1 / Config.GridColumns - 0.015, 1 / 3 - 0.03),
			CellPadding = Config.CellPadding,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}

	for i = 1, Config.BackpackSlotCount do
		local item = backpackItems[i]
		backpackGridChildren["Slot" .. i] = Roact.createElement(BackpackSlot, {
			index = i,
			gridIndex = i,
			item = item,
			isHotbarSlot = false,
			isEquipped = false,
			onDragStart = item and handleDragStart or nil,
			onHoverStart = item and handleHoverStart or nil,
			onHoverEnd = handleHoverEnd,
			LayoutOrder = i,
		})
	end

	-- Build hotbar grid slots (grid indices 22-28)
	local hotbarGridChildren = {
		UIGridLayout = Roact.createElement("UIGridLayout", {
			CellSize = UDim2.fromScale(1 / Config.HotbarSlotCount - 0.015, 1),
			CellPadding = Config.CellPadding,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
	}

	for i = 1, Config.HotbarSlotCount do
		local gridIndex = Config.BackpackSlotCount + i
		local item = hotbar[i]
		hotbarGridChildren["HotbarSlot" .. i] = Roact.createElement(BackpackSlot, {
			index = i,
			gridIndex = gridIndex,
			item = item,
			isHotbarSlot = true,
			isEquipped = equippedSlot == i,
			onDragStart = item and handleDragStart or nil,
			onHoverStart = item and handleHoverStart or nil,
			onHoverEnd = handleHoverEnd,
			LayoutOrder = gridIndex,
		})
	end

	return Roact.createElement(DarkOverlay, {
		Name = "InventoryOverlay",
		ZIndex = 10,
		OnClose = handleBackgroundClick,
	}, {
		InventoryFrame = Roact.createElement("ImageButton", {
			Name = "InventoryFrame",
			AnchorPoint = Config.FrameAnchorPoint,
			Position = Config.FramePosition,
			Size = Config.FrameSize,
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = "",
			AutoButtonColor = false,
			Active = true,
			ZIndex = 11,
			ClipsDescendants = false,
			[Roact.Event.MouseButton1Click] = function() end,
		}, {
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = Config.AspectRatio,
			}),

			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.CornerRadius,
			}),

			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.StrokeColor,
				Thickness = Config.StrokeThickness,
				Transparency = Config.StrokeTransparency,
			}),

			CardBackground = Roact.createElement(StudBackground, {
				ZIndex = 11,
				BackgroundColor = Config.StudBackgroundColor,
				ImageTransparency = Config.StudImageTransparency,
				CornerRadius = Config.CornerRadius,
			}),

			SlotsContainer = Roact.createElement("Frame", {
				Name = "SlotsContainer",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 12,
			}, {
				UIPadding = Roact.createElement("UIPadding", {
					PaddingLeft = Config.PaddingLeft,
					PaddingRight = Config.PaddingRight,
					PaddingTop = Config.PaddingTop,
					PaddingBottom = Config.PaddingBottom,
				}),

				UIListLayout = Roact.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = Config.SectionPadding,
				}),

				BackpackGrid = Roact.createElement("Frame", {
					Name = "BackpackGrid",
					Size = UDim2.fromScale(1, 0.72),
					BackgroundTransparency = 1,
					LayoutOrder = 1,
				}, backpackGridChildren),

				HotbarGrid = Roact.createElement("Frame", {
					Name = "HotbarGrid",
					Size = UDim2.fromScale(1, 0.22),
					BackgroundTransparency = 1,
					LayoutOrder = 2,
				}, hotbarGridChildren),
			}),

			DevItemPicker = isDevPickerOpen and Roact.createElement(DevItemPicker) or nil,

			LeftPanel = (not isWorkbenchOpen and not isFurnaceOpen and not isChestOpen and not isShopOpen) and Roact.createElement(LeftPanel, {
				SelectedRecipeId = nil, -- Don't show selected state (pool shows what's selected)
				OnRecipeSelect = handleInventoryRecipeSelect,
				OnRemove = handleInventoryRecipeRemove,
				CountItem = countItem,
				ZIndex = 11,
			}) or nil,

			TopPanel = (not isWorkbenchOpen and not isFurnaceOpen and not isChestOpen and not isShopOpen) and Roact.createElement(TopPanel, {
				CraftCount = inventoryCraftCount,
				OnCraft = handleInventoryCraft,
				OnHoverStart = handleHoverStart,
				OnHoverEnd = handleHoverEnd,
				ZIndex = 11,
			}) or nil,

			Workbench = isWorkbenchOpen and Roact.createElement(WorkbenchApplication, {
				OnHoverStart = handleHoverStart,
				OnHoverEnd = handleHoverEnd,
			}) or nil,

			Furnace = isFurnaceOpen and Roact.createElement(FurnaceApplication, {
				OnHoverStart = handleHoverStart,
				OnHoverEnd = handleHoverEnd,
			}) or nil,

			Chest = isChestOpen and Roact.createElement(ChestApplication, {
				OnHoverStart = handleHoverStart,
				OnHoverEnd = handleHoverEnd,
			}) or nil,

			Shop = isShopOpen and Roact.createElement(ShopApplication, {
				OnHoverStart = handleHoverStart,
				OnHoverEnd = handleHoverEnd,
			}) or nil,
		}),

		ItemTooltip = Roact.createElement(ItemTooltip, {
			ItemName = hoveredItemName,
			Visible = hoveredItemName ~= nil,
		}),
	})
end

Backpack = RoactHooks.new(Roact)(Backpack)
return Backpack
