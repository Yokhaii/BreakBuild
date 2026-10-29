--[=[
	InventoryButton Component
	Backpack icon slot positioned to the right of the hotbar
	Toggles the backpack/inventory visibility when clicked
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Components = StarterPlayer.StarterPlayerScripts.Client.Roact.Components
local ItemSlot = require(Components.Global.ItemSlot)
local TutorialTargets = require(StarterPlayer.StarterPlayerScripts.Client.Modules.TutorialTargets)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local function InventoryButton(props, hooks)
	local isHovered, setIsHovered = hooks.useState(false)

	local backpackOpen = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer.BackpackOpen
	end) or false

	local handleClick = hooks.useCallback(function()
		local InventoryController = Knit.GetController("InventoryController")
		if InventoryController then
			if InventoryController:IsBackpackOpen() then
				InventoryController:CloseBackpack()
			else
				InventoryController:OpenBackpackFromHUD()
			end
		end
	end, {})

	-- Determine visual state
	local backgroundColor
	if backpackOpen then
		backgroundColor = Config.ActiveBackgroundColor
	elseif isHovered then
		backgroundColor = Config.HoverBackgroundColor
	else
		backgroundColor = Config.DefaultBackgroundColor
	end

	local strokeColor = backpackOpen and Config.ActiveStrokeColor or Config.DefaultStrokeColor
	local strokeThickness = backpackOpen and Config.ActiveStrokeThickness or Config.DefaultStrokeThickness
	local strokeTransparency = backpackOpen and Config.ActiveStrokeTransparency or Config.DefaultStrokeTransparency

	return Roact.createElement("Frame", {
		Name = "InventoryButton",
		Size = Config.SlotSize,
		Position = Config.SlotPosition,
		AnchorPoint = Config.SlotAnchorPoint,
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex or 1,
		[Roact.Ref] = TutorialTargets.Ref("InventoryButton"),
	}, {
		ItemSlot = Roact.createElement(ItemSlot, {
			Image = Images.Backpack,
			ItemName = "Inventory",
			OnClick = handleClick,
			OnHoverStart = function()
				setIsHovered(true)
			end,
			OnHoverEnd = function()
				setIsHovered(false)
			end,
			BackgroundColor = backgroundColor,
			StrokeColor = strokeColor,
			StrokeThickness = strokeThickness,
			StrokeTransparency = strokeTransparency,
			ZIndex = props.ZIndex or 1,
		}),
	})
end

InventoryButton = RoactHooks.new(Roact)(InventoryButton)
return InventoryButton
