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

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local DarkOverlay = require(Components.Global.DarkOverlay)

local BackpackSlot = require(script.Components.BackpackSlot)

local Config = require(script.Config)

local function Backpack(props, hooks)
	local inventoryState = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer
	end)

	local backpackItems = inventoryState.Backpack or {}
	local hotbar = inventoryState.Hotbar or {}
	local equippedSlot = inventoryState.EquippedSlot
	local isOpen = inventoryState.BackpackOpen

	if not isOpen then
		return Roact.createElement("Frame", { Visible = false })
	end

	local function handleDragStart(gridIndex, item)
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
			ZIndex = 11,
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
		}),
	})
end

Backpack = RoactHooks.new(Roact)(Backpack)
return Backpack
