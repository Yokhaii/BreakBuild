--[=[
	ControlHints Component
	Bottom right of the HUD: the keys the player can use right now, one per row ("Break [mouse]").
	  - Left click: UIReducer.PrimaryAction (ControlHintsController), only while aiming at a target
	  - G Drop: while holding a dropable item
	  - V First / Third person: always
	Hidden while a menu is open and on touch devices.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UserInputService = game:GetService("UserInputService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local StudBackground = require(Components.Global.StudBackground)
local FancyText = require(Components.Global.FancyText)

local ItemData = require(ReplicatedStorage.Shared.Data.Items)

local Config = require(script.Config)

local function createKeyCap(zIndex: number, aspectRatio: number, cornerRadius: UDim, children)
	children.UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
		AspectRatio = aspectRatio,
		DominantAxis = Enum.DominantAxis.Height,
	})

	return Roact.createElement(StudBackground, {
		Name = "Key",
		Size = Config.KeySize,
		LayoutOrder = 2,
		ZIndex = zIndex,
		BackgroundColor = Config.KeyColor,
		ImageTransparency = Config.KeyStudImageTransparency,
		CornerRadius = cornerRadius,
		StrokeColor = Config.KeyStrokeColor,
		StrokeThickness = Config.KeyStrokeThickness,
	}, children)
end

local function createKey(key: string, zIndex: number)
	return createKeyCap(zIndex, Config.KeyAspectRatio, Config.KeyCornerRadius, {
		Text = Roact.createElement(FancyText, {
			Text = key,
			Size = Config.KeyTextSize,
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			TextColor3 = Config.KeyTextColor,
			StrokeTransparency = 1,
			ZIndex = zIndex + 1,
		}),
	})
end

local function createMouse(zIndex: number)
	return createKeyCap(zIndex, Config.MouseAspectRatio, Config.MouseCornerRadius, {
		LeftButton = Roact.createElement("Frame", {
			Position = Config.MouseButtonPosition,
			Size = Config.MouseButtonSize,
			BackgroundColor3 = Config.MouseButtonColor,
			BorderSizePixel = 0,
			ZIndex = zIndex + 1,
		}, {
			UICorner = Roact.createElement("UICorner", {
				CornerRadius = Config.MouseButtonCornerRadius,
			}),
		}),
		Divider = Roact.createElement("Frame", {
			Position = Config.MouseDividerPosition,
			AnchorPoint = Vector2.new(0.5, 0),
			Size = Config.MouseDividerSize,
			BackgroundColor3 = Config.MouseDividerColor,
			BorderSizePixel = 0,
			ZIndex = zIndex + 1,
		}),
	})
end

local function createRow(text: string, keyElement, layoutOrder: number, zIndex: number)
	return Roact.createElement("Frame", {
		Size = Config.RowSize,
		LayoutOrder = layoutOrder,
		BackgroundTransparency = 1,
		ZIndex = zIndex,
	}, {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = Config.RowItemPadding,
		}),

		Label = Roact.createElement(FancyText, {
			Text = text,
			Size = Config.LabelSize,
			LayoutOrder = 1,
			TextColor3 = Config.LabelColor,
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = zIndex + 1,
		}, {
			UITextSizeConstraint = Roact.createElement("UITextSizeConstraint", {
				MaxTextSize = Config.LabelMaxTextSize,
			}),
		}),

		Key = keyElement,
	})
end

local function ControlHints(_, hooks)
	local uiState = RoduxHooks.useSelector(hooks, function(state)
		return state.UIReducer
	end)
	local inventory = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer
	end)

	local isVisible = uiState.CurrentFrame == "HUD"
		and not inventory.BackpackOpen
		and not UserInputService.TouchEnabled

	local equippedItem = inventory.EquippedSlot and inventory.EquippedSlot > 0
		and inventory.Hotbar[inventory.EquippedSlot]
	local equippedConfig = equippedItem and ItemData.GetItem(equippedItem.itemName)

	local zIndex = Config.ZIndex
	local rows = {
		UIListLayout = Roact.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Right,
			VerticalAlignment = Enum.VerticalAlignment.Bottom,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = Config.RowPadding,
		}),
	}

	if uiState.PrimaryAction then
		rows.LeftClick = createRow(uiState.PrimaryAction, createMouse(zIndex + 1), 1, zIndex)
	end
	if equippedConfig and equippedConfig.dropable then
		rows.Drop = createRow(Config.DropText, createKey(Config.DropKey, zIndex + 1), 2, zIndex)
	end
	rows.View = createRow(
		uiState.IsFirstPerson and Config.ThirdPersonText or Config.FirstPersonText,
		createKey(Config.ViewKey, zIndex + 1),
		3,
		zIndex
	)

	return Roact.createElement("Frame", {
		Name = "ControlHints",
		Position = Config.Position,
		AnchorPoint = Config.AnchorPoint,
		Size = Config.Size,
		BackgroundTransparency = 1,
		Visible = isVisible,
		ZIndex = zIndex,
	}, rows)
end

ControlHints = RoactHooks.new(Roact)(ControlHints)
return ControlHints
