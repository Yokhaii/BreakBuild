-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

-- InventoryController
local InventoryController = Knit.CreateController({
	Name = "InventoryController",
})

-- Constants
local TOGGLE_BACKPACK_KEYS = {
	Enum.KeyCode.Backquote, -- ` key
	Enum.KeyCode.B, -- B key (alternative for Mac users)
}
local DROP_KEY = Enum.KeyCode.G
local HOTBAR_SIZE = 10
local DRAG_HOLD_TIME = 0.3 -- Time to hold before drag starts (seconds)

-- Private variables
local InventoryService
local currentInventory = nil
local backpackOpen = false
local searchQuery = ""

-- Drag and drop state
local dragState = {
	isDragging = false,
	draggedSlotFrame = nil, -- The original slot being dragged
	dragClone = nil, -- The clone following cursor
	sourceType = nil, -- "hotbar" or "backpack"
	sourceIndex = nil, -- Index in hotbar or backpack
	holdStartTime = 0,
	isHolding = false,
	holdConnection = nil,
}

-- UI references
local screenGui = nil
local backpackFrame = nil
local backpackScrollingFrame = nil
local backpackTemplate = nil
local searchBar = nil
local searchTextBox = nil
local hotbarFrame = nil
local hotbarSlots = {} -- Array of hotbar slot frames
local backpackSlots = {} -- Array of cloned backpack slot frames

-- Callbacks for UI (can be set externally)
InventoryController.OnSlotHighlighted = nil -- function(slotIndex, itemData) - for viewport preview

--|| Private Functions ||--

-- Get item config for an item name
local function getItemConfig(itemName: string)
	return ItemData.GetItem(itemName)
end

-- Start dragging a slot



-- Update a slot's visual appearance
local function updateSlotVisuals(slotFrame, item, isEquipped: boolean)
	local isEmpty = item == nil

	-- Update transparency
	slotFrame.BackgroundTransparency = isEmpty and 0.5 or 0.3

	-- Update UIStroke thickness
	local uiStroke = slotFrame:FindFirstChildOfClass("UIStroke")
	if uiStroke then
		uiStroke.Thickness = isEquipped and 3 or 1
	end

	-- Update Title text - try "Title" first, then find any TextLabel
	local titleLabel = slotFrame:FindFirstChild("Title")
	if not titleLabel then
		-- Search for first TextLabel (might be named differently)
		for _, child in ipairs(slotFrame:GetChildren()) do
			if child:IsA("TextLabel") and not child.Name:match("Amount") then
				titleLabel = child
				break
			end
		end
	end

	if titleLabel then
		if isEmpty then
			titleLabel.Text = ""
		else
			local itemConfig = getItemConfig(item.itemName)
			local displayText = itemConfig and (itemConfig.displayName or itemConfig.name) or item.itemName
			titleLabel.Text = displayText
		end
	end

	-- Update Amount text - try "Amount" first, then find any TextLabel with "Amount" in name
	local amountLabel = slotFrame:FindFirstChild("Amount")
	if not amountLabel then
		-- Search for TextLabel with "Amount" in the name
		for _, child in ipairs(slotFrame:GetChildren()) do
			if child:IsA("TextLabel") and child.Name:match("Amount") then
				amountLabel = child
				break
			end
		end
	end

	if amountLabel then
		if isEmpty then
			amountLabel.Text = ""
		else
			local amountText = item.quantity > 1 and ("x" .. tostring(item.quantity)) or ""
			amountLabel.Text = amountText
		end
	end
end

-- Update all hotbar slots
local function updateHotbarSlots()
	if not currentInventory then return end

	for i = 1, HOTBAR_SIZE do
		local slotFrame = hotbarSlots[i]
		if slotFrame then
			local item = currentInventory.Hotbar[i]
			local isEquipped = currentInventory.EquippedSlot == i
			updateSlotVisuals(slotFrame, item, isEquipped)
		end
	end
end

local function startDrag(slotFrame, sourceType: "hotbar" | "backpack", sourceIndex: number, item)
	if dragState.isDragging then return end

	dragState.isDragging = true
	dragState.draggedSlotFrame = slotFrame
	dragState.sourceType = sourceType
	dragState.sourceIndex = sourceIndex

	-- Create drag clone
	local clone = slotFrame:Clone()
	clone.Name = "DragClone"
	clone.Size = UDim2.new(0, 68, 0, 66) -- Standard slot size
	clone.Position = UDim2.new(0, 0, 0, 0)
	clone.AnchorPoint = Vector2.new(0.5, 0.5)
	clone.ZIndex = 1000

	-- For hotbar: clear all info from remaining slot
	-- For backpack: make original invisible
	if sourceType == "hotbar" then
		-- Clear the original slot's info
		updateSlotVisuals(slotFrame, nil, false)
	elseif sourceType == "backpack" then
		-- Make original slot invisible
		slotFrame.Visible = false
	end

	-- Parent clone to ScreenGui
	clone.Parent = screenGui

	-- Remove any buttons from clone
	local button = clone:FindFirstChildOfClass("TextButton")
	if button then
		button:Destroy()
	end

	dragState.dragClone = clone
end

-- Filter backpack items by search query
local function filterBackpackItems(): {any}
	if not currentInventory then return {} end

	local backpackItems = currentInventory.Backpack

	if searchQuery == "" then
		return backpackItems
	end

	local filtered = {}
	for _, item in ipairs(backpackItems) do
		local itemConfig = getItemConfig(item.itemName)
		if itemConfig then
			local displayName = string.lower(itemConfig.displayName or itemConfig.name)
			local query = string.lower(searchQuery)
			if string.find(displayName, query, 1, true) then
				table.insert(filtered, item)
			end
		end
	end

	return filtered
end

-- Clear all backpack slot clones
local function clearBackpackSlots()
	for _, slotFrame in ipairs(backpackSlots) do
		slotFrame:Destroy()
	end
	backpackSlots = {}
end


-- Update drag clone position to follow cursor
local function updateDragPosition()
	if not dragState.isDragging or not dragState.dragClone then return end

	local mouse = player:GetMouse()
	dragState.dragClone.Position = UDim2.new(0, mouse.X, 0, mouse.Y)
end

-- Update backpack slots based on filtered items
local function updateBackpackSlots()
	if not currentInventory or not backpackOpen then return end

	-- Clear existing slots
	clearBackpackSlots()

	-- Get filtered items
	local filteredItems = filterBackpackItems()

	-- Clone template for each item
	for i, item in ipairs(filteredItems) do
		local slotFrame = backpackTemplate:Clone()
		slotFrame.Name = "BackpackSlot" .. i
		slotFrame.Visible = true
		slotFrame.LayoutOrder = i

		-- Update visuals
		updateSlotVisuals(slotFrame, item, false)

		-- Add click/drag handler
		local button = slotFrame:FindFirstChildOfClass("TextButton")
		if not button then
			button = Instance.new("TextButton")
			button.Size = UDim2.new(1, 0, 1, 0)
			button.BackgroundTransparency = 1
			button.Text = ""
			button.Parent = slotFrame
		end

		-- Mouse button down - start hold timer
		button.MouseButton1Down:Connect(function()
			if dragState.isDragging then return end

			dragState.isHolding = true
			dragState.holdStartTime = tick()

			-- Store this for click detection
			local clickSlotIndex = i
			local clickItem = item

			-- Check if held long enough to start drag
			task.spawn(function()
				task.wait(DRAG_HOLD_TIME)
				if dragState.isHolding then
					startDrag(slotFrame, "backpack", i, item)
				end
			end)

			-- Wait for mouse up to detect click (global handler will end drag)
			local connection
			connection = UserInputService.InputEnded:Connect(function(input)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					connection:Disconnect()

					-- Only process as click if we're not dragging and were holding
					if not dragState.isDragging and dragState.isHolding then
						dragState.isHolding = false

						-- Call external callback for viewport preview
						if InventoryController.OnSlotHighlighted then
							InventoryController.OnSlotHighlighted(clickSlotIndex, clickItem)
						end
					end
				end
			end)
		end)

		slotFrame.Parent = backpackScrollingFrame
		table.insert(backpackSlots, slotFrame)
	end
end

-- Cancel drag (restore everything)
local function cancelDrag()
	if not dragState.isDragging then return end

	-- Destroy clone
	if dragState.dragClone then
		dragState.dragClone:Destroy()
	end

	-- Restore original slot
	if dragState.sourceType == "hotbar" then
		-- Restore hotbar slot visuals
		local item = currentInventory and currentInventory.Hotbar[dragState.sourceIndex]
		local isEquipped = currentInventory and currentInventory.EquippedSlot == dragState.sourceIndex
		updateSlotVisuals(dragState.draggedSlotFrame, item, isEquipped)
	elseif dragState.sourceType == "backpack" then
		-- Make backpack slot visible again
		if dragState.draggedSlotFrame then
			dragState.draggedSlotFrame.Visible = true
		end
	end

	-- Reset state
	dragState.isDragging = false
	dragState.draggedSlotFrame = nil
	dragState.dragClone = nil
	dragState.sourceType = nil
	dragState.sourceIndex = nil

end

-- Complete drag (successful drop - wait for server to update inventory)
local function completeDrag()
	if not dragState.isDragging then return end

	-- Destroy clone
	if dragState.dragClone then
		dragState.dragClone:Destroy()
	end

	-- Make backpack slots visible again if needed
	if dragState.sourceType == "backpack" and dragState.draggedSlotFrame then
		dragState.draggedSlotFrame.Visible = true
	end

	-- Reset drag state but keep a reference for delayed update
	local sourceType = dragState.sourceType
	local sourceIndex = dragState.sourceIndex
	local draggedFrame = dragState.draggedSlotFrame

	dragState.isDragging = false
	dragState.draggedSlotFrame = nil
	dragState.dragClone = nil
	dragState.sourceType = nil
	dragState.sourceIndex = nil


	-- Wait a frame for server update to arrive, then force visual refresh
	task.wait(0.1)
	if sourceType == "hotbar" and currentInventory then
		updateHotbarSlots()
	end
	if backpackOpen and currentInventory then
		updateBackpackSlots()
	end
end

-- End drag (attempt to drop on target)
local function endDrag()
	if not dragState.isDragging then return end

	local mouse = player:GetMouse()
	local mouseX, mouseY = mouse.X, mouse.Y

	-- Try to find which slot was dropped on
	local targetSlotFrame = nil
	local targetType = nil
	local targetIndex = nil

	-- Check hotbar slots
	for i, slotFrame in pairs(hotbarSlots) do
		local pos = slotFrame.AbsolutePosition
		local size = slotFrame.AbsoluteSize

		if mouseX >= pos.X and mouseX <= pos.X + size.X and
		   mouseY >= pos.Y and mouseY <= pos.Y + size.Y then
			targetSlotFrame = slotFrame
			targetType = "hotbar"
			targetIndex = i
			break
		end
	end

	-- If not on hotbar, check backpack slots
	if not targetSlotFrame and backpackOpen then
		for i, slotFrame in pairs(backpackSlots) do
			if slotFrame.Visible then
				local pos = slotFrame.AbsolutePosition
				local size = slotFrame.AbsoluteSize

				if mouseX >= pos.X and mouseX <= pos.X + size.X and
				   mouseY >= pos.Y and mouseY <= pos.Y + size.Y then
					targetSlotFrame = slotFrame
					targetType = "backpack"
					targetIndex = i
					break
				end
			end
		end

		-- If still not found, check if dropped anywhere in backpack frame area
		if not targetSlotFrame and backpackFrame.Visible then
			local pos = backpackFrame.AbsolutePosition
			local size = backpackFrame.AbsoluteSize

			if mouseX >= pos.X and mouseX <= pos.X + size.X and
			   mouseY >= pos.Y and mouseY <= pos.Y + size.Y then
				-- Dropped in backpack area (not on specific slot)
				targetType = "backpack"
				targetIndex = nil -- No specific slot
			end
		end
	end

	-- If no valid target, cancel drag
	if not targetSlotFrame and not targetType then
		cancelDrag()
		return
	end


	-- Don't do anything if dropped on same slot (only if targetIndex exists)
	if targetIndex and dragState.sourceType == targetType and dragState.sourceIndex == targetIndex then
		cancelDrag()
		return
	end

	-- Get source item
	local sourceItem = nil
	if dragState.sourceType == "hotbar" then
		sourceItem = currentInventory and currentInventory.Hotbar[dragState.sourceIndex]
	elseif dragState.sourceType == "backpack" then
		local filteredItems = filterBackpackItems()
		sourceItem = filteredItems[dragState.sourceIndex]
	end

	if not sourceItem then
		warn("Source item not found!")
		cancelDrag()
		return
	end

	-- Handle different drop scenarios
	if dragState.sourceType == "hotbar" and targetType == "backpack" then
		-- Hotbar to Backpack (works with or without specific target slot)
		InventoryService:MoveToBackpack(dragState.sourceIndex)
		completeDrag() -- Wait for server update

	elseif dragState.sourceType == "backpack" and targetType == "hotbar" then
		-- Backpack to Hotbar
		InventoryService:MoveToHotbar(sourceItem.id, targetIndex)
		completeDrag() -- Wait for server update

	elseif dragState.sourceType == "hotbar" and targetType == "hotbar" then
		-- Hotbar to Hotbar
		local targetItem = currentInventory and currentInventory.Hotbar[targetIndex]

		if targetItem then
			-- Swap with existing item
			InventoryService:SwapItems(sourceItem.id, targetItem.id)
			completeDrag() -- Wait for server update
		else
			-- Move to empty hotbar slot
			InventoryService:MoveHotbarSlot(dragState.sourceIndex, targetIndex)
			completeDrag() -- Wait for server update
		end

	elseif dragState.sourceType == "backpack" and targetType == "backpack" then
		-- Backpack to Backpack (swap)
		local filteredItems = filterBackpackItems()
		local targetItem = filteredItems[targetIndex]
		if targetItem and targetItem.id ~= sourceItem.id then
			InventoryService:SwapItems(sourceItem.id, targetItem.id)
			completeDrag()
		else
			-- Can't swap with same item or nothing
			cancelDrag()
		end
	else
		-- Unknown scenario
		cancelDrag()
	end
end



-- Handle inventory update from server
local function onInventoryUpdated(inventory)
	-- Convert string-keyed Hotbar to numeric indices for client use
	local convertedInventory = {
		Hotbar = {},
		Backpack = inventory.Backpack,
		EquippedSlot = inventory.EquippedSlot,
		NextItemId = inventory.NextItemId,
	}

	-- Convert string keys back to numeric indices
	for i = 1, HOTBAR_SIZE do
		convertedInventory.Hotbar[i] = inventory.Hotbar[tostring(i)]
	end

	currentInventory = convertedInventory

	-- Update hotbar UI
	updateHotbarSlots()

	-- Update backpack UI if open
	if backpackOpen then
		updateBackpackSlots()
	end
end

-- Handle item equipped
local function onItemEquipped(slot, itemName)
	-- UI will auto-update from inventory update
end

-- Handle item unequipped
local function onItemUnequipped()
	-- UI will auto-update from inventory update
end

-- Handle backpack toggle
local function toggleBackpack()
	-- If dragging and backpack is closing, cancel drag
	if dragState.isDragging and backpackOpen then
		cancelDrag()
	end

	backpackOpen = not backpackOpen

	if backpackFrame then
		backpackFrame.Visible = backpackOpen

		-- Update backpack slots when opening
		if backpackOpen then
			updateBackpackSlots()
		end
	end

end

-- Handle search query change
local function onSearchChanged(query)
	searchQuery = query
	updateBackpackSlots()
end

-- Handle hotbar slot click
local function onHotbarSlotClick(slot)
	InventoryController:ToggleEquipSlot(slot)
end

-- Handle input
local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	-- Toggle backpack (check multiple keys)
	for _, key in ipairs(TOGGLE_BACKPACK_KEYS) do
		if input.KeyCode == key then
			toggleBackpack()
			break
		end
	end

	-- Drop equipped item
	if input.KeyCode == DROP_KEY then
		InventoryService:DropEquippedItem()
	end

	-- Hotbar number keys (1-9, 0 for slot 10)
	if input.KeyCode.Name:match("^%d$") or input.KeyCode == Enum.KeyCode.Zero then
		local slot
		if input.KeyCode == Enum.KeyCode.Zero then
			slot = 10
		else
			slot = tonumber(input.KeyCode.Name:match("%d"))
		end

		if slot and slot >= 1 and slot <= HOTBAR_SIZE then
			InventoryController:ToggleEquipSlot(slot)
		end
	end
end

--|| Public Functions ||--

-- Toggle equip for a hotbar slot
function InventoryController:ToggleEquipSlot(slot: number)
	if not currentInventory then return end

	-- If this slot is already equipped, unequip
	if currentInventory.EquippedSlot == slot then
		InventoryService:UnequipItem()
	else
		-- Equip this slot
		InventoryService:EquipItem(slot)
	end
end

-- Get current inventory
function InventoryController:GetInventory()
	return currentInventory
end

-- Check if backpack is open
function InventoryController:IsBackpackOpen(): boolean
	return backpackOpen
end

-- Open backpack
function InventoryController:OpenBackpack()
	if not backpackOpen then
		toggleBackpack()
	end
end

-- Close backpack
function InventoryController:CloseBackpack()
	if backpackOpen then
		toggleBackpack()
	end
end

-- Set search query
function InventoryController:SetSearchQuery(query: string)
	searchQuery = query
	updateBackpackSlots()
end

-- Get search query
function InventoryController:GetSearchQuery(): string
	return searchQuery
end

-- Get item config from inventory item
function InventoryController:GetItemConfig(itemName: string)
	return ItemData.GetItem(itemName)
end

--|| Initialization ||--

function InventoryController:KnitStart()
	InventoryService = Knit.GetService("InventoryService")

	-- Setup input handling
	UserInputService.InputBegan:Connect(onInputBegan)

	-- Get UI references
	screenGui = playerGui:WaitForChild("ScreenGui")

	-- Backpack
	backpackFrame = screenGui:WaitForChild("Backpack")
	backpackScrollingFrame = backpackFrame:WaitForChild("ScrollingFrame")
	backpackTemplate = backpackScrollingFrame:WaitForChild("Template")
	backpackTemplate.Visible = false

	-- SearchBar (inside Backpack frame)
	searchBar = backpackFrame:WaitForChild("SearchBar")
	searchTextBox = searchBar:WaitForChild("TextBox")

	-- Wire up search box
	searchTextBox:GetPropertyChangedSignal("Text"):Connect(function()
		onSearchChanged(searchTextBox.Text)
	end)

	-- HUD and Hotbar
	local hud = screenGui:WaitForChild("HUD")
	hotbarFrame = hud:WaitForChild("Hotbar")

	-- Get all hotbar slots (1-10)
	for i = 1, HOTBAR_SIZE do
		local slotFrame = hotbarFrame:WaitForChild(tostring(i))
		hotbarSlots[i] = slotFrame

		-- Add click handler
		local button = slotFrame:FindFirstChildOfClass("TextButton")
		if not button then
			button = Instance.new("TextButton")
			button.Size = UDim2.new(1, 0, 1, 0)
			button.BackgroundTransparency = 1
			button.Text = ""
			button.Parent = slotFrame
		end

		-- Mouse button down - start hold timer
		button.MouseButton1Down:Connect(function()
			if dragState.isDragging then return end

			dragState.isHolding = true
			dragState.holdStartTime = tick()

			-- Check if held long enough to start drag
			task.spawn(function()
				task.wait(DRAG_HOLD_TIME)
				if dragState.isHolding then
					local item = currentInventory and currentInventory.Hotbar[i]
					if item then
						startDrag(slotFrame, "hotbar", i, item)
					end
				end
			end)
		end)

		-- Mouse button up - either click or end drag
		button.MouseButton1Up:Connect(function()
			if dragState.isDragging then
				endDrag()
			elseif dragState.isHolding then
				-- Was a click, not a hold
				dragState.isHolding = false
				onHotbarSlotClick(i)
			end
		end)

		-- Initialize empty slot visuals
		updateSlotVisuals(slotFrame, nil, false)
	end

	-- Hide backpack initially
	backpackFrame.Visible = false

	-- Update drag clone position every frame
	RunService.RenderStepped:Connect(function()
		updateDragPosition()
	end)

	-- Global mouse release handler (in case mouse is released outside of any slot)
	UserInputService.InputEnded:Connect(function(input, gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			if dragState.isDragging then
				endDrag()
			elseif dragState.isHolding then
				dragState.isHolding = false
			end
		end
	end)

	-- Now that UI is fully initialized, connect to inventory signals
	-- This MUST happen after hotbarSlots is populated
	InventoryService.InventoryUpdated:Connect(onInventoryUpdated)
	InventoryService.ItemEquipped:Connect(onItemEquipped)
	InventoryService.ItemUnequipped:Connect(onItemUnequipped)
end

return InventoryController
