--[=[
	DarkOverlay Component
	Full-screen semi-transparent overlay that closes the current frame on click.
	Use as a backdrop behind any frame/modal.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Config = require(script.Config)

local function DarkOverlay(props, hooks)
	return Roact.createElement("ImageButton", {
		Name = props.Name or "DarkOverlay",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = props.OverlayColor or Config.OverlayColor,
		BackgroundTransparency = props.OverlayTransparency or Config.OverlayTransparency,
		BorderSizePixel = 0,
		Image = "",
		AutoButtonColor = false,
		ZIndex = props.ZIndex or 10,
		[Roact.Event.MouseButton1Click] = props.OnClose,
	}, props[Roact.Children])
end

DarkOverlay = RoactHooks.new(Roact)(DarkOverlay)
return DarkOverlay
