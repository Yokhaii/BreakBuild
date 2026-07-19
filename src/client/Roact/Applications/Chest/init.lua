local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Components = Client.Roact.Components
local PanelFrame = require(Components.Frames.PanelFrame)
local StudBackground = require(Components.Global.StudBackground)
local FancyText = require(Components.Global.FancyText)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local TOTAL_SLOTS = Config.GridColumns * Config.GridRows
-- Chest drop zone uses a sentinel gridIndex outside the inventory range.
local CHEST_DROP_ZONE_ID = "chest_deposit"

local function ChestApplication(props, hooks)
	local onHoverStart = props.OnHoverStart
	local onHoverEnd = props.OnHoverEnd

	local chestState = RoduxHooks.useSelector(hooks, function(state)
		return state.ChestReducer
	end)

	-- Tracks the tick() of the last click per slot index for double-click detection.
	local lastClickTime = hooks.useValue({})

	local items = chestState.Items or {}

	local slotItems = {}
	for i, item in ipairs(items) do
		slotItems[i] = item
	end

	-- The panel's Roact.Ref — used to register the whole panel as a drop zone.
	local panelRef = hooks.useValue(Roact.createRef())

	-- Register the chest panel as a drop zone. When an inventory item is dropped here
	-- the onDrop callback fires and we call ChestController:DepositItem.
	hooks.useEffect(function()
		local frame = panelRef.value:getValue()
		if not frame then return end

		local InventoryController = Knit.GetController("InventoryController")
		if not InventoryController then return end

		local cleanup = InventoryController:RegisterDropZone(
			CHEST_DROP_ZONE_ID,
			nil, -- no gridIndex needed; we use onDrop instead
			frame,
			function(item, _fromGridIndex)
				local ChestController = Knit.GetController("ChestController")
				if ChestController and item then
					ChestController:DepositItem(item.id, item.quantity)
				end
			end
		)

		return cleanup
	end, {})

	local DOUBLE_CLICK_THRESHOLD = 0.35

	local function onSlotClick(slotIndex)
		local item = slotItems[slotIndex]
		if not item then return end

		local now = tick()
		local last = lastClickTime.value[slotIndex] or 0
		lastClickTime.value[slotIndex] = now

		if now - last <= DOUBLE_CLICK_THRESHOLD then
			local ChestController = Knit.GetController("ChestController")
			if ChestController then
				ChestController:WithdrawItem(item.itemName, item.quantity)
			end
			lastClickTime.value[slotIndex] = 0
		end
	end

	-- Build slot grid
	local slotChildren = {
		UIGridLayout = Roact.createElement("UIGridLayout", {
			CellSize = Config.SlotSize,
			CellPadding = UDim2.fromScale(0.02, 0.02),
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Top,
		}),
		UIPadding = Roact.createElement("UIPadding", {
			PaddingLeft = UDim.new(0.02, 0),
			PaddingRight = UDim.new(0.02, 0),
			PaddingTop = UDim.new(0.02, 0),
		}),
	}

	for i = 1, TOTAL_SLOTS do
		local item = slotItems[i]
		local itemImage = item and Images[item.itemName] or nil
		local displayAmount = item and item.quantity and item.quantity > 1 and ("x" .. tostring(item.quantity)) or ""

		local slotIndex = i
		slotChildren["Slot" .. i] = Roact.createElement("Frame", {
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			LayoutOrder = i,
			ClipsDescendants = true,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.SlotCornerRadius,
			}),
			UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
				AspectRatio = 1,
			}),
			UIStroke = Roact.createElement("UIStroke", {
				Color = Config.SlotStrokeColor,
				Thickness = Config.SlotStrokeThickness,
				Transparency = Config.SlotStrokeTransparency,
			}),
			SlotBackground = Roact.createElement(StudBackground, {
				ZIndex = 12,
				BackgroundColor = Config.SlotBackgroundColor,
				ImageTransparency = Config.SlotStudImageTransparency,
				CornerRadius = Config.SlotCornerRadius,
			}),
			ItemDisplay = itemImage and Roact.createElement("ImageLabel", {
				Size = UDim2.fromScale(0.75, 0.75),
				Position = UDim2.fromScale(0.5, 0.5),
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundTransparency = 1,
				Image = itemImage,
				ScaleType = Enum.ScaleType.Fit,
				ZIndex = 14,
			}) or nil,
			Amount = displayAmount ~= "" and Roact.createElement(FancyText, {
				Text = displayAmount,
				Size = UDim2.fromScale(0.5, 0.3),
				Position = UDim2.fromScale(0.95, 0.95),
				AnchorPoint = Vector2.new(1, 1),
				TextColor3 = Config.AmountColor,
				StrokeColor = Config.AmountStrokeColor,
				StrokeThickness = Config.AmountStrokeThickness,
				TextXAlignment = Enum.TextXAlignment.Right,
				ZIndex = 15,
			}) or nil,
			Button = Roact.createElement("TextButton", {
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				Text = "",
				ZIndex = 16,
				[Roact.Event.MouseButton1Down] = item and function()
					if onHoverEnd then onHoverEnd() end
					local InventoryController = Knit.GetController("InventoryController")
					if InventoryController then
						InventoryController:StartDragFromChest(item)
					end
				end or nil,
				[Roact.Event.MouseButton1Click] = function()
					onSlotClick(slotIndex)
				end,
				[Roact.Event.MouseEnter] = item and function()
					if onHoverStart then onHoverStart(item.itemName) end
				end or nil,
				[Roact.Event.MouseLeave] = function()
					if onHoverEnd then onHoverEnd() end
				end,
			}),
		})
	end

	return Roact.createElement(PanelFrame, {
		Name = "ChestPanel",
		AnchorPoint = Config.PanelAnchorPoint,
		Position = Config.PanelPosition,
		Size = Config.PanelSize,
		AspectRatio = Config.PanelAspectRatio,
		Title = Config.TitleText,
		ZIndex = 11,
		[Roact.Ref] = panelRef.value,
	}, {
		SlotGrid = Roact.createElement("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			ZIndex = 12,
		}, slotChildren),
	})
end

ChestApplication = RoactHooks.new(Roact)(ChestApplication)
return ChestApplication
