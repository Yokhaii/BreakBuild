--[=[
	ModeToggle Component
	Button above hotbar to switch between Break and Build modes
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)
local RoduxHooks = require(ReplicatedStorage.Packages.Roduxhooks)
local Knit = require(ReplicatedStorage.Packages.Knit)

local Config = require(script.Config)

local function ModeToggle(props, hooks)
	-- Get current mode from Rodux
	local currentMode = RoduxHooks.useSelector(hooks, function(state)
		return state.InventoryReducer.CurrentMode
	end) or "Build"

	-- Hover state
	local isHovered, setIsHovered = hooks.useState(false)

	-- Get mode-specific config
	local modeConfig = Config[currentMode] or Config.Build

	-- Handle click
	local handleClick = hooks.useCallback(function()
		local InventoryService = Knit.GetService("InventoryService")
		InventoryService:SwitchMode()
	end, {})

	-- Determine background color (with hover effect)
	local backgroundColor = isHovered and modeConfig.HoverColor or modeConfig.BackgroundColor

	return Roact.createElement("TextButton", {
		Name = "ModeToggle",
		Size = Config.ButtonSize,
		Position = Config.ButtonPosition,
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = backgroundColor,
		Text = modeConfig.Text,
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

ModeToggle = RoactHooks.new(Roact)(ModeToggle)
return ModeToggle
