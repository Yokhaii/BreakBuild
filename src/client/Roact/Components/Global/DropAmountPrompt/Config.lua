--[=[
	DropAmountPrompt Configuration
]=]

return {
	ZIndex = 60, -- Above the backpack (10-16) and tooltips (50)

	-- Backdrop
	BackdropColor = Color3.fromRGB(0, 0, 0),
	BackdropTransparency = 0.5,

	-- Panel (kept in the upper half so the touch keyboard doesn't cover it)
	PanelPosition = UDim2.fromScale(0.5, 0.33),
	PanelSize = UDim2.fromScale(0.4, 0.4),
	PanelAspectRatio = 1.6,
	PanelBackgroundColor = Color3.fromRGB(149, 149, 149),
	PanelStudTransparency = 0.7,
	PanelStrokeColor = Color3.fromRGB(202, 202, 202),
	PanelStrokeThickness = 4,
	CornerRadius = UDim.new(0.06, 0),

	-- Title
	TitleText = "Drop how many?",
	TitlePosition = UDim2.fromScale(0.5, 0.06),
	TitleSize = UDim2.fromScale(0.9, 0.2),
	TitleColor = Color3.fromRGB(255, 255, 255),
	TitleStrokeColor = Color3.fromRGB(56, 56, 56),
	TitleStrokeThickness = 2,

	-- Amount row (item image + number field + "/ max")
	RowPosition = UDim2.fromScale(0.5, 0.33),
	RowSize = UDim2.fromScale(0.9, 0.3),
	ImageSize = UDim2.fromScale(0.25, 1),
	InputSize = UDim2.fromScale(0.4, 0.8),
	InputBackgroundColor = Color3.fromRGB(40, 40, 40),
	InputTextColor = Color3.fromRGB(255, 255, 255),
	InputPlaceholderColor = Color3.fromRGB(150, 150, 150),
	InputCornerRadius = UDim.new(0.2, 0),
	InputStrokeColor = Color3.fromRGB(0, 0, 0),
	InputStrokeThickness = 2,
	MaxLabelSize = UDim2.fromScale(0.25, 0.6),
	MaxLabelColor = Color3.fromRGB(255, 255, 255),
	RowPadding = UDim.new(0.03, 0),

	-- Buttons
	ButtonsPosition = UDim2.fromScale(0.5, 0.92),
	ButtonsSize = UDim2.fromScale(0.9, 0.24),
	ButtonSize = UDim2.fromScale(0.45, 1),
	ButtonsPadding = UDim.new(0.1, 0),
	ButtonCornerRadius = UDim.new(0.2, 0),
	ButtonStudTransparency = 0.4,
	ButtonStrokeColor = Color3.fromRGB(0, 0, 0),
	ButtonStrokeThickness = 2,
	CancelText = "CANCEL",
	CancelColor = Color3.fromRGB(180, 70, 70),
	DropText = "DROP",
	DropColor = Color3.fromRGB(70, 150, 70),
	ButtonTextColor = Color3.fromRGB(255, 255, 255),
	ButtonTextStrokeColor = Color3.fromRGB(0, 0, 0),
	ButtonTextStrokeThickness = 1,

	Font = Font.fromEnum(Enum.Font.GothamBold),
	MaxTextSize = 32,
	MinTextSize = 10,
}
