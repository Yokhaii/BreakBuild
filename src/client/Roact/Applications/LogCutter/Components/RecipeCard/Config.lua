return {
	CardSize = UDim2.fromScale(1, 0.16),
	CornerRadius = UDim.new(0.05, 0),

	CardStudBackgroundColor = Color3.fromRGB(145, 145, 145),
	CardStudImageTransparency = 0.7,

	CardStrokeColor = Color3.fromRGB(255, 255, 255),
	CardStrokeThickness = 3.5,
	CardStrokeTransparency = 0.87,

	-- Selected state
	SelectedStrokeColor = Color3.fromRGB(160, 100, 40),
	SelectedStrokeTransparency = 0,

	-- Content padding
	ContentPaddingLeft = UDim.new(0.04, 0),
	ContentPaddingRight = UDim.new(0.02, 0),
	ContentPaddingTop = UDim.new(0.05, 0),
	ContentPaddingBottom = UDim.new(0.05, 0),

	-- Image container (left side)
	ImageSize = UDim2.fromScale(0.22, 0.85),
	ImageCornerRadius = UDim.new(0.1, 0),
	ImageStudBackgroundColor = Color3.fromRGB(60, 60, 60),
	ImageStudImageTransparency = 0.91,
	ImageStrokeColor = Color3.fromRGB(0, 0, 0),
	ImageStrokeThickness = 2.5,
	ImageStrokeTransparency = 0.5,
	RecipeIconSize = UDim2.fromScale(0.8, 0.8),

	-- Info container
	InfoContainerSize = UDim2.fromScale(0.73, 0.9),
	InfoContainerPosition = UDim2.fromScale(0.28, 0.5),
	InfoContainerAnchorPoint = Vector2.new(0, 0.5),
	InfoLayoutPadding = UDim.new(0.02, 0),

	-- Title
	TitleSize = UDim2.fromScale(1, 0.3),
	TitleColor = Color3.fromRGB(40, 40, 40),
	TitleStrokeColor = Color3.fromRGB(160, 160, 160),
	TitleStrokeThickness = 1.2,

	-- Materials
	MaterialsContainerSize = UDim2.fromScale(1, 0.7),
	MaterialFrameSize = UDim2.fromScale(0.3, 1),
	MaterialAspectRatio = 2.5,
	MaterialIconSize = UDim2.fromScale(0.4, 0.8),
	MaterialAmountSize = UDim2.fromScale(0.55, 1),
	MaterialAmountPosition = UDim2.fromScale(0.45, 0),
	MaterialTextColor = Color3.fromRGB(0, 0, 0),
	MaterialFont = Font.fromEnum(Enum.Font.GothamMedium),
}
