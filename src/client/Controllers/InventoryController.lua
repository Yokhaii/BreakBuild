--[=[
	InventoryController
	Handles inventory input, drag-and-drop, and service communication
	UI is now handled by Roact components via Rodux state
	Updated for dual-mode hotbar system (Break/Build)
]=]

-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

-- Knit packages
local Packages = ReplicatedStorage.Packages
local Knit = require(Packages.Knit)

-- Player
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Rodux
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Rodux.Store)
local Actions = StarterPlayer.StarterPlayerScripts.Client.Rodux.Actions
local InventoryActions = require(Actions.InventoryActions)

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
local MODE_TOGGLE_KEY = Enum.KeyCode.Tab
local HOTBAR_SIZE = 6 -- Per mode

-- Private variables
local InventoryService

-- Drag and drop state
local dragState = {
	isDragging = false,
	dragClone = nil,
	sourceType = nil, -- "hotbar" or "backpack"
	sourceIndex = nil,
	item = nil,
}

-- Callbacks for UI (can be set externally)
InventoryController.OnSlotHighlighted = nil -- function(slotIndex, itemData) - for viewport preview

--|| Private Functions ||--

-- Get item config for an item name
local function getItemConfig(itemName: string)
	return ItemData.GetItem(itemName)
end

-- Get current inventory state from Rodux
local function getInventoryState()
	return Store:getState().InventoryReducer
end

-- Get current mode's hotbar from state
local function getCurrentHotbar()
	local state = getInventoryState()
	if state.CurrentMode == "Break" then
		return state.BreakHotbar
	else
		return state.BuildHotbar
	end
end

-- Create drag clone element
local function createDragClone(item)
	local clone = Instance.new("Frame")
	clone.Name = "DragClone"
	clone.Size = UDim2.fromOffset(66, 68)
	clone.AnchorPoint = Vector2.new(0.5, 0.5)
	clone.BackgroundColor3 = Color3.fromRGB(83, 83, 83)
	clone.BackgroundTransparency = 0.3
	clone.BorderSizePixel = 0
	clone.ZIndex = 1000

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = clone

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Parent = clone

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.fromScale(1, 1)
	title.BackgroundTransparency = 1
	title.Text = item.itemName or ""
	title.TextColor3 = Color3.fromRGB(0, 0, 0)
	title.TextSize = 14
	title.Font = Enum.Font.SourceSans
	title.Parent = clone

	if item.quantity and item.quantity > 1 then
		local amount = Instance.new("TextLabel")
		amount.Name = "Amount"
		amount.Size = UDim2.fromOffset(20, 17)
		amount.Position = UDim2.fromScale(0.7, 0.7)
		amount.BackgroundTransparency = 1
		amount.Text = "x" .. tostring(item.quantity)
		amount.TextColor3 = Color3.fromRGB(0, 0, 0)
		amount.TextSize = 14
		amount.Font = Enum.Font.SourceSans
		amount.Parent = clone
	end

	return clone
end

-- Update drag clone position
local function updateDragPosition()
	if not dragState.isDragging or not dragState.dragClone then return end

	local mouse = player:GetMouse()
	dragState.dragClone.Position = UDim2.fromOffset(mouse.X, mouse.Y)
end

-- Filter backpack items by search query
local function filterBackpackItems()
	local state = getInventoryState()
	local backpackItems = state.Backpack or {}
	local searchQuery = state.SearchQuery or ""

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
end

-- Start dragging
function InventoryController:StartDrag(sourceType: string, sourceIndex: number, item)
	if dragState.isDragging then return end

	-- Prevent dragging from Build slot 1 (Hammer is locked)
	local state = getInventoryState()
	if sourceType == "hotbar" and state.CurrentMode == "Build" and sourceIndex == 1 then
		return -- Cannot drag Hammer
	end

	dragState.isDragging = true
	dragState.sourceType = sourceType
	dragState.sourceIndex = sourceIndex
	dragState.item = item

	-- Create visual drag clone
	local clone = createDragClone(item)

	-- Find the ScreenGui to parent the clone
	local screenGui = playerGui:FindFirstChild("GameScreenGui")
	if screenGui then
		clone.Parent = screenGui
	else
		-- Fallback: find any ScreenGui
		for _, gui in ipairs(playerGui:GetChildren()) do
			if gui:IsA("ScreenGui") then
				clone.Parent = gui
				break
			end
		end
	end

	dragState.dragClone = clone
	updateDragPosition()
end

-- Cancel drag
local function cancelDrag()
	if not dragState.isDragging then return end

	if dragState.dragClone then
		dragState.dragClone:Destroy()
	end

	dragState.isDragging = false
	dragState.dragClone = nil
	dragState.sourceType = nil
	dragState.sourceIndex = nil
	dragState.item = nil
end

-- End drag (attempt to drop)
local function endDrag()
	if not dragState.isDragging then return end

	local state = getInventoryState()
	local mouse = player:GetMouse()
	local mouseX, mouseY = mouse.X, mouse.Y

	-- For now, simplified drop logic:
	-- If backpack is open and dropped in backpack area, move to backpack
	-- Otherwise try to find hotbar slot

	local sourceItem = dragState.item
	if not sourceItem then
		cancelDrag()
		return
	end

	-- Simple heuristic: if dropped in top 60% of screen while backpack open, it's backpack area
	-- Otherwise, if dropped in bottom 20% it's hotbar area
	local screenHeight = workspace.CurrentCamera.ViewportSize.Y
	local screenWidth = workspace.CurrentCamera.ViewportSize.X

	local isBackpackArea = state.BackpackOpen and mouseY < screenHeight * 0.8 and mouseY > screenHeight * 0.3
	local isHotbarArea = mouseY > screenHeight * 0.85

	local currentHotbar = getCurrentHotbar()

	if dragState.sourceType == "hotbar" then
		if isBackpackArea then
			-- Move from hotbar to backpack
			InventoryService:MoveToBackpack(dragState.sourceIndex)
		elseif isHotbarArea then
			-- Calculate target hotbar slot (1-6 based on X position)
			local hotbarStartX = screenWidth * 0.5 - 210 -- Adjusted for 6 slots
			local slotWidth = 70
			local targetSlot = math.floor((mouseX - hotbarStartX) / slotWidth) + 1
			targetSlot = math.clamp(targetSlot, 1, HOTBAR_SIZE)

			-- Prevent dropping to Build slot 1
			if state.CurrentMode == "Build" and targetSlot == 1 then
				cancelDrag()
				return
			end

			if targetSlot ~= dragState.sourceIndex then
				local targetItem = currentHotbar[targetSlot]
				if targetItem then
					InventoryService:SwapItems(sourceItem.id, targetItem.id)
				else
					InventoryService:MoveHotbarSlot(dragState.sourceIndex, targetSlot)
				end
			end
		end
	elseif dragState.sourceType == "backpack" then
		if isHotbarArea then
			-- Calculate target hotbar slot
			local hotbarStartX = screenWidth * 0.5 - 210 -- Adjusted for 6 slots
			local slotWidth = 70
			local targetSlot = math.floor((mouseX - hotbarStartX) / slotWidth) + 1
			targetSlot = math.clamp(targetSlot, 1, HOTBAR_SIZE)

			-- Prevent dropping to Build slot 1
			if state.CurrentMode == "Build" and targetSlot == 1 then
				cancelDrag()
				return
			end

			InventoryService:MoveToHotbar(sourceItem.id, targetSlot)
		end
	end

	-- Clean up drag state
	if dragState.dragClone then
		dragState.dragClone:Destroy()
	end

	dragState.isDragging = false
	dragState.dragClone = nil
	dragState.sourceType = nil
	dragState.sourceIndex = nil
	dragState.item = nil
end

-- Toggle backpack
local function toggleBackpack()
	local state = getInventoryState()
	local newState = not state.BackpackOpen

	-- Cancel any ongoing drag when closing backpack
	if dragState.isDragging and state.BackpackOpen then
		cancelDrag()
	end

	Store:dispatch(InventoryActions.setBackpackOpen(newState))
end

-- Handle input
local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	-- Toggle backpack
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

	-- Mode toggle with Tab key
	if input.KeyCode == MODE_TOGGLE_KEY then
		-- Cancel any ongoing drag when switching modes
		if dragState.isDragging then
			cancelDrag()
		end
		InventoryService:SwitchMode()
	end

	-- Hotbar number keys (1-6 only)
	local keyName = input.KeyCode.Name
	if keyName:match("^%d$") then
		local slot = tonumber(keyName)
		if slot and slot >= 1 and slot <= HOTBAR_SIZE then
			InventoryController:ToggleEquipSlot(slot)
		end
	end
end

-- Handle mouse release for drag end
local function onInputEnded(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if dragState.isDragging then
			endDrag()
		end
	end
end

--|| Public Functions ||--

-- Toggle equip for a hotbar slot
function InventoryController:ToggleEquipSlot(slot: number)
	local state = getInventoryState()

	if state.EquippedSlot == slot then
		InventoryService:UnequipItem()
	else
		InventoryService:EquipItem(slot)
	end
end

-- Get current inventory (from Rodux state)
function InventoryController:GetInventory()
	return getInventoryState()
end

-- Get current mode
function InventoryController:GetCurrentMode(): string
	return getInventoryState().CurrentMode or "Build"
end

-- Switch mode
function InventoryController:SwitchMode()
	-- Cancel any ongoing drag when switching modes
	if dragState.isDragging then
		cancelDrag()
	end
	InventoryService:SwitchMode()
end

-- Check if backpack is open
function InventoryController:IsBackpackOpen(): boolean
	return getInventoryState().BackpackOpen
end

-- Open backpack
function InventoryController:OpenBackpack()
	Store:dispatch(InventoryActions.setBackpackOpen(true))
end

-- Close backpack
function InventoryController:CloseBackpack()
	if dragState.isDragging then
		cancelDrag()
	end
	Store:dispatch(InventoryActions.setBackpackOpen(false))
end

-- Set search query
function InventoryController:SetSearchQuery(query: string)
	Store:dispatch(InventoryActions.setSearchQuery(query))
end

-- Get search query
function InventoryController:GetSearchQuery(): string
	return getInventoryState().SearchQuery or ""
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
	UserInputService.InputEnded:Connect(onInputEnded)

	-- Update drag position every frame
	RunService.RenderStepped:Connect(updateDragPosition)

	print("[InventoryController] Started - Dual-Mode Hotbar (Break/Build)")
end

return InventoryController
