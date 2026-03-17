--[=[
	Backpack Component
	Displays the player's backpack items in a scrolling grid
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local BackpackSlot = require(script.Parent.BackpackSlot)
local SearchBar = require(script.Parent.SearchBar)

local function Backpack(props, hooks)
	-- Get inventory state from Rodux
	local inventoryState = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer
	end)

	local backpackItems = inventoryState.Backpack or {}
	local isOpen = inventoryState.BackpackOpen
	local searchQuery = inventoryState.SearchQuery or ""

	-- Filter items by search query
	local filteredItems = hooks.useMemo(function()
		if searchQuery == "" then
			return backpackItems
		end

		local filtered = {}
		local queryLower = string.lower(searchQuery)

		for _, item in ipairs(backpackItems) do
			local itemName = string.lower(item.itemName or "")
			if string.find(itemName, queryLower, 1, true) then
				table.insert(filtered, item)
			end
		end

		return filtered
	end, { backpackItems, searchQuery })

	-- Handle slot click
	local function handleSlotClick(index, item)
		-- Can be used for item preview or other actions
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController and InventoryController.OnSlotHighlighted then
			InventoryController.OnSlotHighlighted(index, item)
		end
	end

	-- Handle drag start
	local function handleDragStart(index, item)
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController and InventoryController.StartDrag then
			InventoryController:StartDrag("backpack", index, item)
		end
	end

	-- Don't render if not open
	if not isOpen then
		return Roact.createElement("Frame", {
			Visible = false,
		})
	end

	-- Create scrolling frame children
	local scrollChildren = {
		UIGridLayout = Roact.createElement("UIGridLayout", {
			CellSize = UDim2.fromOffset(66, 68),
			CellPadding = UDim2.fromOffset(5, 5),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	-- Add slots to scrollChildren
	for i, item in ipairs(filteredItems) do
		scrollChildren["Slot" .. i] = Roact.createElement(BackpackSlot, {
			index = i,
			item = item,
			onSlotClick = handleSlotClick,
			onDragStart = handleDragStart,
		})
	end

	return Roact.createElement("Frame", {
		Name = "Backpack",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.695),
		Size = UDim2.fromOffset(706, 298),
		BackgroundColor3 = Color3.fromRGB(91, 91, 91),
		BackgroundTransparency = 0.7,
		BorderSizePixel = 0,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = UDim.new(0, 8),
		}),

		UIStroke = Roact.createElement("UIStroke", {
			Thickness = 1,
			Color = Color3.fromRGB(0, 0, 0),
			ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
		}),

		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 2.4,
			AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}),

		ScrollingFrame = Roact.createElement("ScrollingFrame", {
			Name = "ScrollingFrame",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromScale(0.99, 0.98),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 12,
			ScrollBarImageColor3 = Color3.fromRGB(0, 0, 0),
			CanvasSize = UDim2.fromScale(0, 0),
			AutomaticCanvasSize = Enum.AutomaticSize.Y,
			ScrollingDirection = Enum.ScrollingDirection.Y,
		}, scrollChildren),

		SearchBar = Roact.createElement(SearchBar),
	})
end

Backpack = RoactHooks.new(Roact)(Backpack)
return Backpack
