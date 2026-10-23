return {
	CardSize = UDim2.fromScale(0.94, 0.12),
	CornerRadius = UDim.new(0.05, 0),

	CardStudBackgroundColor = Color3.fromRGB(145, 145, 145),
	CardStudImageTransparency = 0.7,

	CardStrokeColor = Color3.fromRGB(255, 255, 255),
	CardStrokeThickness = 2,
	CardStrokeTransparency = 0.87,

	ContentPaddingLeft = UDim.new(0.04, 0),
	ContentPaddingRight = UDim.new(0.02, 0),
	ContentPaddingTop = UDim.new(0.05, 0),
	ContentPaddingBottom = UDim.new(0.05, 0),

	-- Image container (left side)
	ImageSize = UDim2.fromScale(0.18, 0.85),
	ImageCornerRadius = UDim.new(0.1, 0),
	ImageStudBackgroundColor = Color3.fromRGB(60, 60, 60),
	ImageStudImageTransparency = 0.91,
	ImageStrokeColor = Color3.fromRGB(0, 0, 0),
	ImageStrokeThickness = 2.5,
	ImageStrokeTransparency = 0.5,
	IconSize = UDim2.fromScale(0.8, 0.8),

	-- Info container
	InfoContainerSize = UDim2.fromScale(0.42, 0.9),
	InfoContainerPosition = UDim2.fromScale(0.24, 0.5),
	InfoContainerAnchorPoint = Vector2.new(0, 0.5),
	InfoLayoutPadding = UDim.new(0.02, 0),

	-- Title
	TitleSize = UDim2.fromScale(1, 0.4),
	TitleColor = Color3.fromRGB(40, 40, 40),
	TitleStrokeColor = Color3.fromRGB(160, 160, 160),
	TitleStrokeThickness = 2,

	-- Price
	PriceSize = UDim2.fromScale(1, 0.5),
	PriceColor = Color3.fromRGB(60, 140, 60),
	PriceSellColor = Color3.fromRGB(180, 140, 40),
	PriceFont = Font.fromEnum(Enum.Font.GothamBold),

	-- Action buttons
	ButtonContainerSize = UDim2.fromScale(0.3, 0.85),
	ButtonContainerPosition = UDim2.fromScale(0.96, 0.5),
	ButtonContainerAnchorPoint = Vector2.new(1, 0.5),
	ButtonSpacing = UDim.new(0.05, 0),

	ButtonCornerRadius = UDim.new(0.2, 0),
	ButtonColor = Color3.fromRGB(80, 180, 80),
	ButtonStudImageTransparency = 0.7,
	ButtonTextColor = Color3.fromRGB(255, 255, 255),
	ButtonFont = Font.fromEnum(Enum.Font.GothamBold),
}
