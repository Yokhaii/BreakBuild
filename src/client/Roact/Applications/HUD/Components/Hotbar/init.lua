--[=[
	Hotbar Component
	Displays inventory slots at the bottom of the screen
	Click-to-equip only (no drag from HUD hotbar)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)

local HotbarSlot = require(script.Parent.HotbarSlot)
local HammerSlot = require(script.Parent.HammerSlot)
local InventoryButton = require(script.Parent.InventoryButton)

local Config = require(script.Config)

local function Hotbar(props, hooks)
	local inventoryState = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer
	end)

	local equippedSlot = inventoryState.EquippedSlot
	local hotbar = inventoryState.Hotbar or {}
	local hammerAvailable = inventoryState.HammerAvailable

	local function handleSlotClick(slotNumber)
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController then
			InventoryController:ToggleEquipSlot(slotNumber)
		end
	end

	local slotChildren = {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = Config.SlotPadding,
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
			VerticalAlignment = Enum.VerticalAlignment.Center,
		}),
	}

	for i = 1, Config.SlotCount do
		slotChildren["Slot" .. i] = Roact.createElement(HotbarSlot, {
			slotNumber = i,
			item = hotbar[i],
			isEquipped = equippedSlot == i,
			onSlotClick = handleSlotClick,
		})
	end

	return Roact.createElement("Frame", {
		Name = "Hotbar",
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

		InventoryButton = Roact.createElement(InventoryButton),

		HammerSlot = hammerAvailable and Roact.createElement(HammerSlot, {
			isEquipped = equippedSlot == 0,
			onSlotClick = function()
				handleSlotClick(0)
			end,
		}) or nil,

		HotbarCard = Roact.createElement("ImageButton", {
			Name = "HotbarCard",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = "",
			AutoButtonColor = false,
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

				Slots = Roact.createElement("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
				}, slotChildren),
			}),
		}),
	})
end

Hotbar = RoactHooks.new(Roact)(Hotbar)
return Hotbar
