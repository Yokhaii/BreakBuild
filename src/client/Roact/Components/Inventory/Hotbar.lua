--[=[
	Hotbar Component
	Displays 6 inventory slots at the bottom of the screen
	Mode-aware: shows BreakHotbar or BuildHotbar based on CurrentMode
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local HotbarSlot = require(script.Parent.HotbarSlot)
local ModeToggle = require(script.Parent.ModeToggle)

local HOTBAR_SIZE = 6 -- Per mode

local function Hotbar(props, hooks)
	-- Get inventory state from Rodux
	local inventoryState = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer
	end)

	local currentMode = inventoryState.CurrentMode or "Build"
	local equippedSlot = inventoryState.EquippedSlot

	-- Select the correct hotbar based on mode
	local hotbar = currentMode == "Break"
		and inventoryState.BreakHotbar
		or inventoryState.BuildHotbar
	hotbar = hotbar or {}

	-- Handle slot click (equip/unequip)
	local function handleSlotClick(slotNumber)
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController then
			InventoryController:ToggleEquipSlot(slotNumber)
		end
	end

	-- Handle drag start
	local function handleDragStart(slotNumber, item)
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController and InventoryController.StartDrag then
			InventoryController:StartDrag("hotbar", slotNumber, item)
		end
	end

	-- Create children table with layout and slots
	local children = {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			Padding = UDim.new(0, 3),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),

		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 6, -- Changed from 10 to 6
			AspectType = Enum.AspectType.FitWithinMaxSize,
			DominantAxis = Enum.DominantAxis.Width,
		}),
	}

	-- Add slots to children
	for i = 1, HOTBAR_SIZE do
		-- Build slot 1 is locked (Hammer)
		local isLocked = (currentMode == "Build" and i == 1)

		children["Slot" .. i] = Roact.createElement(HotbarSlot, {
			slotNumber = i,
			item = hotbar[i],
			isEquipped = equippedSlot == i,
			isLocked = isLocked,
			onSlotClick = handleSlotClick,
			onDragStart = not isLocked and handleDragStart or nil, -- Disable drag for locked slots
		})
	end

	return Roact.createElement("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.95),
		Size = UDim2.fromOffset(420, 69), -- Adjusted for 6 slots
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, {
		-- Mode toggle button above hotbar
		ModeToggle = Roact.createElement(ModeToggle),

		-- Slots container
		SlotsContainer = Roact.createElement("Frame", {
			Name = "SlotsContainer",
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
		}, children),
	})
end

Hotbar = RoactHooks.new(Roact)(Hotbar)
return Hotbar
