--[=[
	Backpack Component
	Displays the player's backpack items in a scrolling grid
	Styled like BlueprintCard with StudBackground
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local BackpackSlot = require(script.Parent.BackpackSlot)
local SearchBar = require(script.Parent.SearchBar)

local Config = require(script.Config)

local function Backpack(props, hooks)
	local inventoryState = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer
	end)

	local backpackItems = inventoryState.Backpack or {}
	local isOpen = inventoryState.BackpackOpen
	local searchQuery = inventoryState.SearchQuery or ""

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

	local function handleSlotClick(index, item)
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController and InventoryController.OnSlotHighlighted then
			InventoryController.OnSlotHighlighted(index, item)
		end
	end

	local function handleDragStart(index, item)
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController and InventoryController.StartDrag then
			InventoryController:StartDrag("backpack", index, item)
		end
	end

	if not isOpen then
		return Roact.createElement("Frame", {
			Visible = false,
		})
	end

	local scrollChildren = {
		UIGridLayout = Roact.createElement("UIGridLayout", {
			CellSize = Config.CellSize,
			CellPadding = Config.CellPadding,
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}

	local totalSlots = math.max(Config.MaxSlots, #filteredItems)
	for i = 1, totalSlots do
		local item = filteredItems[i]
		scrollChildren["Slot" .. i] = Roact.createElement(BackpackSlot, {
			index = i,
			item = item,
			onSlotClick = item and handleSlotClick or nil,
			onDragStart = item and handleDragStart or nil,
		})
	end

	return Roact.createElement("Frame", {
		Name = "Backpack",
		AnchorPoint = Config.FrameAnchorPoint,
		Position = Config.FramePosition,
		Size = Config.FrameSize,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = Config.AspectRatio,
			AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}),

		SearchBar = Roact.createElement(SearchBar),

		BackpackCard = Roact.createElement("Frame", {
			Name = "BackpackCard",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.CornerRadius,
			}),

			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.StrokeColor,
				Thickness = Config.StrokeThickness,
				Transparency = Config.StrokeTransparency,
			}),

			CardBackground = Roact.createElement(StudBackground, {
				ZIndex = 1,
				BackgroundColor = Config.StudBackgroundColor,
				ImageTransparency = Config.StudImageTransparency,
				CornerRadius = Config.CornerRadius,
			}),

			SlotsContainer = Roact.createElement("Frame", {
				Name = "SlotsContainer",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				ZIndex = 2,
			}, {
				UIPadding = Roact.createElement("UIPadding", {
					PaddingLeft = Config.PaddingLeft,
					PaddingRight = Config.PaddingRight,
					PaddingTop = Config.PaddingTop,
					PaddingBottom = Config.PaddingBottom,
				}),

				ScrollingFrame = Roact.createElement("ScrollingFrame", {
					Name = "ScrollingFrame",
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					BorderSizePixel = 0,
					ScrollBarThickness = Config.ScrollBarThickness,
					ScrollBarImageColor3 = Config.ScrollBarColor,
					CanvasSize = UDim2.fromScale(0, 0),
					AutomaticCanvasSize = Enum.AutomaticSize.Y,
					ScrollingDirection = Enum.ScrollingDirection.Y,
					ZIndex = 2,
				}, scrollChildren),
			}),
		}),
	})
end

Backpack = RoactHooks.new(Roact)(Backpack)
return Backpack
