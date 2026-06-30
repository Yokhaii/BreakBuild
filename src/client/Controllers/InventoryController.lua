--[=[
	InventoryController
	Handles inventory input, drag-and-drop, and service communication.
	Drag-and-drop uses a generic drop zone registry so any UI (backpack, workbench, etc.)
	can participate. Swaps are optimistic on the client for instant feedback.
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
local UIActions = require(Actions.UIActions)

-- Data
local ItemData = require(ReplicatedStorage.Shared.Data.Items)
local Images = require(ReplicatedStorage.Shared.Data.Images)

-- Set once at KnitStart
local isDevPlayer = false

-- InventoryController
local InventoryController = Knit.CreateController({
	Name = "InventoryController",
})

-- Constants
local TOGGLE_BACKPACK_KEYS = {
	Enum.KeyCode.Backquote,
	Enum.KeyCode.B,
}
local DROP_KEY = Enum.KeyCode.G
local HAMMER_KEY = Enum.KeyCode.H
local HOTBAR_SIZE = 7
local BACKPACK_SIZE = 21
local DRAG_CLONE_SIZE = UDim2.fromOffset(66, 68)

-- Private variables
local InventoryService

-- Drag state
local dragState = {
	isDragging = false,
	dragClone = nil,
	sourceGridIndex = nil,
	item = nil,
}

-- Generic drop zone registry: key = unique id, value = { gridIndex, absPosition, absSize }
local dropZones = {}

--|| Private Functions ||--

local function getInventoryState()
	return Store:getState().InventoryReducer
end

local function createDragClone(item)
	local clone = Instance.new("ImageLabel")
	clone.Name = "DragClone"
	clone.Size = DRAG_CLONE_SIZE
	clone.AnchorPoint = Vector2.new(0.5, 0.5)
	clone.BackgroundTransparency = 1
	clone.BorderSizePixel = 0
	clone.ZIndex = 1000
	clone.ScaleType = Enum.ScaleType.Fit
	clone.Image = Images[item.itemName] or ""

	return clone
end

local function updateDragPosition()
	if not dragState.isDragging or not dragState.dragClone then return end

	local mousePos = UserInputService:GetMouseLocation()
	dragState.dragClone.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
end

local function findDropZoneAtPosition(mouseX, mouseY): number?
	local inset = game:GetService("GuiService"):GetGuiInset()
	local adjustedY = mouseY - inset.Y

	for _, zone in pairs(dropZones) do
		local obj = zone.object
		if obj and obj.Parent then
			local pos = obj.AbsolutePosition
			local size = obj.AbsoluteSize
			if mouseX >= pos.X and mouseX <= pos.X + size.X
				and adjustedY >= pos.Y and adjustedY <= pos.Y + size.Y then
				return zone.gridIndex
			end
		end
	end
	return nil
end

local function cancelDrag()
	if not dragState.isDragging then return end

	if dragState.dragClone then
		dragState.dragClone:Destroy()
	end

	dragState.isDragging = false
	dragState.dragClone = nil
	dragState.sourceGridIndex = nil
	dragState.item = nil
end

local function endDrag()
	if not dragState.isDragging then return end

	local mousePos = UserInputService:GetMouseLocation()
	local targetGridIndex = findDropZoneAtPosition(mousePos.X, mousePos.Y)

	if targetGridIndex == -1 then
		-- Trash zone: remove the item
		local item = dragState.item
		local fromIdx = dragState.sourceGridIndex
		Store:dispatch(InventoryActions.removeGridSlot(fromIdx))
		task.spawn(function()
			InventoryService:DevRemoveItem(item.id)
		end)
	elseif targetGridIndex and targetGridIndex ~= dragState.sourceGridIndex then
		Store:dispatch(InventoryActions.swapGridSlots(dragState.sourceGridIndex, targetGridIndex))

		local fromIdx = dragState.sourceGridIndex
		task.spawn(function()
			InventoryService:SwapGridSlots(fromIdx, targetGridIndex)
		end)
	end

	if dragState.dragClone then
		dragState.dragClone:Destroy()
	end

	dragState.isDragging = false
	dragState.dragClone = nil
	dragState.sourceGridIndex = nil
	dragState.item = nil
end

local function toggleBackpack()
	local state = getInventoryState()
	local newState = not state.BackpackOpen

	if dragState.isDragging then
		cancelDrag()
	end

	Store:dispatch(InventoryActions.setBackpackOpen(newState))
	Store:dispatch(InventoryActions.setDevPickerOpen(newState and isDevPlayer))

	if not newState then
		local uiState = Store:getState().UIReducer
		if uiState.CurrentFrame == "Workbench" or uiState.CurrentFrame == "StoneCutter" then
			Store:dispatch(UIActions.setCurrentFrame("HUD"))
		end

		local CraftingController = Knit.GetController("CraftingController")
		if CraftingController and CraftingController:HasActiveSession() then
			CraftingController:EndSession()
		end
	end
end

local function onInputBegan(input, gameProcessed)
	if gameProcessed then return end

	-- Toggle backpack
	for _, key in ipairs(TOGGLE_BACKPACK_KEYS) do
		if input.KeyCode == key then
			toggleBackpack()
			break
		end
	end

	local state = getInventoryState()

	-- Block equip/drop when inventory overlay is open
	if state.BackpackOpen then return end

	-- Drop equipped item
	if input.KeyCode == DROP_KEY then
		InventoryService:DropEquippedItem()
	end

	-- Hammer key
	if input.KeyCode == HAMMER_KEY then
		if state.HammerAvailable then
			InventoryController:ToggleEquipSlot(0)
		end
	end

	-- Hotbar number keys (1-7)
	local keyName = input.KeyCode.Name
	if keyName:match("^%d$") then
		local slot = tonumber(keyName)
		if slot and slot >= 1 and slot <= HOTBAR_SIZE then
			InventoryController:ToggleEquipSlot(slot)
		end
	end
end

local function onInputEnded(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		if dragState.isDragging then
			endDrag()
		end
	end
end

--|| Public Functions ||--

function InventoryController:StartDrag(gridIndex: number, item)
	if dragState.isDragging then return end
	if not getInventoryState().BackpackOpen then return end

	dragState.isDragging = true
	dragState.sourceGridIndex = gridIndex
	dragState.item = item

	local clone = createDragClone(item)

	local screenGui = playerGui:FindFirstChild("GameScreenGui")
	if screenGui then
		clone.Parent = screenGui
	else
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

function InventoryController:RegisterDropZone(id: string, gridIndex: number, guiObject: GuiObject)
	dropZones[id] = {
		gridIndex = gridIndex,
		object = guiObject,
	}

	return function()
		dropZones[id] = nil
	end
end

function InventoryController:UnregisterDropZone(id: string)
	dropZones[id] = nil
end

function InventoryController:ToggleEquipSlot(slot: number)
	local state = getInventoryState()
	if state.BackpackOpen then return end

	if state.EquippedSlot == slot then
		InventoryService:UnequipItem()
	else
		InventoryService:EquipItem(slot)
	end
end

function InventoryController:GetInventory()
	return getInventoryState()
end

function InventoryController:IsBackpackOpen(): boolean
	return getInventoryState().BackpackOpen
end

function InventoryController:IsDragging(): boolean
	return dragState.isDragging
end

function InventoryController:OpenBackpack()
	Store:dispatch(InventoryActions.setBackpackOpen(true))
end

function InventoryController:CloseBackpack()
	if dragState.isDragging then
		cancelDrag()
	end
	Store:dispatch(InventoryActions.setBackpackOpen(false))
	Store:dispatch(InventoryActions.setDevPickerOpen(false))

	local uiState = Store:getState().UIReducer
	if uiState.CurrentFrame == "Workbench" or uiState.CurrentFrame == "StoneCutter" then
		Store:dispatch(UIActions.setCurrentFrame("HUD"))
	end

	local CraftingController = Knit.GetController("CraftingController")
	if CraftingController and CraftingController:HasActiveSession() then
		CraftingController:EndSession()
	end
end

function InventoryController:GetItemConfig(itemName: string)
	return ItemData.GetItem(itemName)
end

--|| Initialization ||--

function InventoryController:KnitStart()
	InventoryService = Knit.GetService("InventoryService")

	InventoryService:IsDevPlayer():andThen(function(result)
		isDevPlayer = result

		UserInputService.InputBegan:Connect(onInputBegan)
		UserInputService.InputEnded:Connect(onInputEnded)
	end)

	RunService.RenderStepped:Connect(updateDragPosition)
end

return InventoryController
