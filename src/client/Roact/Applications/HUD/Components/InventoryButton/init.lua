--[=[
	InventoryButton Component
	Button above hotbar to toggle the backpack/inventory visibility
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

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

	local backgroundColor = backpackOpen
		and Config.ActiveColor
		or (isHovered and Config.HoverColor or Config.DefaultColor)

	return Roact.createElement("TextButton", {
		Name = "InventoryButton",
		Size = Config.ButtonSize,
		Position = Config.ButtonPosition,
		AnchorPoint = Config.ButtonAnchorPoint,
		BackgroundColor3 = backgroundColor,
		Text = Config.Text,
		TextColor3 = Config.TextColor,
		TextSize = Config.TextSize,
		FontFace = Config.Font,
		AutoButtonColor = false,
		ZIndex = props.ZIndex or 1,
		[Roact.Event.MouseButton1Click] = handleClick,
		[Roact.Event.MouseEnter] = function()
			setIsHovered(true)
		end,
		[Roact.Event.MouseLeave] = function()
			setIsHovered(false)
		end,
	}, {
		UICorner = Roact.createElement("UICorner", {
			CornerRadius = Config.CornerRadius,
		}),
		UIStroke = Roact.createElement("UIStroke", {
			Thickness = Config.StrokeThickness,
			Color = Config.StrokeColor,
			Transparency = Config.StrokeTransparency,
		}),
	})
end

InventoryButton = RoactHooks.new(Roact)(InventoryButton)
return InventoryButton
