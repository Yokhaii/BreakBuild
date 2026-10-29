--[=[
	ClickIcon Component
	Pointing-hand icon telling the player where to click.
	Uses Images.ClickIcon when it exists, otherwise an emoji fallback.
	Never sinks input, so clicks reach the element underneath.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Images = require(ReplicatedStorage.Shared.Data.Images)

local Config = require(script.Config)

local function ClickIcon(props, hooks)
	local image = Images.ClickIcon

	local children = {
		UIAspectRatioConstraint = Roact.createElement("UIAspectRatioConstraint", {
			AspectRatio = 1,
		}),
	}

	if image then
		return Roact.createElement("ImageLabel", {
			Name = "ClickIcon",
			Size = Config.Size,
			Position = props.Position,
			AnchorPoint = Config.AnchorPoint,
			BackgroundTransparency = 1,
			Image = image,
			ScaleType = Enum.ScaleType.Fit,
			Visible = props.Visible,
			ZIndex = props.ZIndex or 1,
		}, children)
	end

	return Roact.createElement("TextLabel", {
		Name = "ClickIcon",
		Size = Config.Size,
		Position = props.Position,
		AnchorPoint = Config.AnchorPoint,
		BackgroundTransparency = 1,
		Text = Config.FallbackText,
		TextColor3 = Config.FallbackColor,
		TextScaled = true,
		Visible = props.Visible,
		ZIndex = props.ZIndex or 1,
	}, children)
end

ClickIcon = RoactHooks.new(Roact)(ClickIcon)
return ClickIcon
