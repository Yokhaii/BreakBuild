--[=[
	DurabilityBar Component
	Small bar at the bottom of an item slot showing a tool's remaining durability.
	Renders nothing for items without maxDurability.

	Props:
		Item   (table?)  -- inventory item { itemName, durability }
		ZIndex (number?) -- defaults to 1
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local Config = require(script.Config)

local function DurabilityBar(props, hooks)
	local item = props.Item
	local zIndex = props.ZIndex or 1

	if not item then return nil end

	local itemConfig = ItemData.GetItem(item.itemName)
	local maxDurability = itemConfig and itemConfig.maxDurability
	if not maxDurability then return nil end

	local durability = item.durability or maxDurability
	if Config.HideWhenFull and durability >= maxDurability then return nil end

	local ratio = math.clamp(durability / maxDurability, 0, 1)

	return Roact.createElement("Frame", {
		Name = "DurabilityBar",
		Size = Config.Size,
		Position = Config.Position,
		AnchorPoint = Config.AnchorPoint,
		BackgroundColor3 = Config.TrackColor,
		BackgroundTransparency = Config.TrackTransparency,
		BorderSizePixel = 0,
		ZIndex = zIndex,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),

		Fill = Roact.createElement("Frame", {
			Size = UDim2.fromScale(ratio, 1),
			BackgroundColor3 = Config.EmptyColor:Lerp(Config.FullColor, ratio),
			BorderSizePixel = 0,
			ZIndex = zIndex + 1,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.CornerRadius,
			}),
		}),
	})
end

DurabilityBar = RoactHooks.new(Roact)(DurabilityBar)
return DurabilityBar
