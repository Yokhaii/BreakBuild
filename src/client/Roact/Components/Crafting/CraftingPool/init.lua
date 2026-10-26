--[=[
	CraftingPool Component
	Displays items that have been dragged into the crafting area.
	Shows empty ItemSlots when pool is empty (acts as drop zones).
	Shows filled ItemSlots with close buttons when pool has items.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local Client = StarterPlayer.StarterPlayerScripts.Client
local Store = require(Client.Rodux.Store)
local CraftingPoolActions = require(Client.Rodux.Actions.CraftingPoolActions)
local InventoryActions = require(Client.Rodux.Actions.InventoryActions)

local Components = Client.Roact.Components
local ItemSlot = require(Components.Global.ItemSlot)
local CloseButton = require(Components.Global.CloseButton)

local Images = require(ReplicatedStorage.Shared.Data.Images)
local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local Config = require(script.Config)

local function CraftingPool(props, hooks)
	local baseZIndex = props.ZIndex or 12
	local onHoverStart = props.OnHoverStart
	local onHoverEnd = props.OnHoverEnd
	local emptySlotCount = props.EmptySlotCount or 1 -- Number of empty slots to show when pool is empty
	local slotSize = props.SlotSize or UDim2.fromScale(0.12, 0.8) -- Size of each slot

	local craftingPoolState = RoduxHooks.useSelector(hooks, function(state)
		return state.CraftingPoolReducer
	end)

	local pool = craftingPoolState.Pool or {}

	-- Aggregate items by name
	local aggregated = {}
	local entryMap = {}
	for _, entry in ipairs(pool) do
		if aggregated[entry.itemName] then
			aggregated[entry.itemName] = aggregated[entry.itemName] + entry.quantity
		else
			aggregated[entry.itemName] = entry.quantity
		end
		if not entryMap[entry.itemName] then
			entryMap[entry.itemName] = {}
		end
		table.insert(entryMap[entry.itemName], entry)
	end

	local slotElements = {}
	local hasItems = next(aggregated) ~= nil

	if hasItems then
		-- Show filled slots with items and close buttons
		local i = 0
		for itemName, quantity in pairs(aggregated) do
			i = i + 1
			local itemConfig = ItemData.GetItem(itemName)
			local image = Images[itemName] or ""
			local displayName = itemConfig and (itemConfig.displayName or itemConfig.name) or itemName

			slotElements["Pool_" .. itemName] = Roact.createElement("Frame", {
				Size = slotSize,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				ZIndex = baseZIndex,
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1,
				}),
				Slot = Roact.createElement(ItemSlot, {
					Size = UDim2.fromScale(1, 1),
					Image = image,
					ItemName = displayName,
					Quantity = quantity,
					OnHoverStart = onHoverStart,
					OnHoverEnd = onHoverEnd,
					ZIndex = baseZIndex,
				}),
				RemoveButton = Roact.createElement(CloseButton, {
					Position = Config.CloseButtonPosition,
					AnchorPoint = Config.CloseButtonAnchorPoint,
					Size = Config.CloseButtonSize,
					ZIndex = baseZIndex + 5,
					OnClick = function()
						-- Restore all items of this type back to inventory
						local entries = entryMap[itemName]
						if entries then
							for _, entry in ipairs(entries) do
								if entry.gridIndex and entry.itemId then
									Store:dispatch(InventoryActions.restoreGridSlot(entry.gridIndex, {
										id = entry.itemId,
										itemName = entry.itemName,
										quantity = entry.quantity,
									}))
								end
							end
						end
						-- Remove from crafting pool
						Store:dispatch(CraftingPoolActions.removeFromCraftingPool(itemName))
					end,
				}),
			})
		end
	else
		-- Show empty slots as drop zones
		for i = 1, emptySlotCount do
			slotElements["EmptySlot_" .. i] = Roact.createElement("Frame", {
				Size = slotSize,
				BackgroundTransparency = 1,
				LayoutOrder = i,
				ZIndex = baseZIndex,
			}, {
				UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
					AspectRatio = 1,
				}),
				Slot = Roact.createElement(ItemSlot, {
					Size = UDim2.fromScale(1, 1),
					Image = nil,
					ItemName = nil,
					Quantity = nil,
					ZIndex = baseZIndex,
				}),
			})
		end
	end

	return Roact.createElement("Frame", {
		Size = props.Size or UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = baseZIndex,
		[Roact.Ref] = props[Roact.Ref],
	}, {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = Config.SlotPadding,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),

		Slots = Roact.createFragment(slotElements),
	})
end

CraftingPool = RoactHooks.new(Roact)(CraftingPool)
return CraftingPool
