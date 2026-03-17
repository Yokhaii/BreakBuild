--[=[
	BaseFrame Configuration
]=]

local Config = {
	-- Background
	BackgroundColor = Color3.fromRGB(50, 50, 50),
	BackgroundTransparency = 1,

	-- Main
	DefaultSize = UDim2.fromScale(0.696, 0.784),
	MainStudBackgroundColor = Color3.fromRGB(149, 149, 149),
	MainStudImageTransparency = 0.7,
	StrokeColor = Color3.fromRGB(202, 202, 202),
	StrokeThickness = 6.1,
	StrokeTransparency = 0.5,
	CornerRadius = UDim.new(0.02, 0),

	-- Title
	TitleColor = Color3.fromRGB(56, 56, 56),
	TitleStrokeColor = Color3.fromRGB(56, 56, 56),
	TitleStrokeThickness = 2,
	TitleColor2 = Color3.fromRGB(255, 255, 255),
	TitleStrokeColor2 = Color3.fromRGB(255, 255, 255),
	TitleStrokeThickness2 = 2,
	TitleSize = UDim2.fromScale(0.957, 0.153),
	TitleStudBackgroundColor = Color3.fromRGB(191, 191, 191),
	TitleStudImageTransparency = 0.6,
	TitleCornerRadius = UDim.new(0.05, 0),
	TitleFrameStrokeColor = Color3.fromRGB(191, 191, 191),
	TitleFrameStrokeThickness = 4,
	TitleFrameStrokeTransparency = 0.5,

	-- Content
	ContentSize = UDim2.fromScale(0.95, 0.786),
	ContentStudBackgroundColor = Color3.fromRGB(80, 80, 80),
	ContentStudImageTransparency = 0.8,
	ContentCornerRadius = UDim.new(0.01, 0),
	ContentStrokeColor = Color3.fromRGB(77, 77, 77),
	ContentStrokeThickness = 4,
	ContentStrokeTransparency = 0.5,

	-- Border

	CloseButtonSize = UDim2.fromScale(0.08, 0.08),

	-- Animation
	SpringTension = 100,
	SpringFriction = 10,
}

return Config
