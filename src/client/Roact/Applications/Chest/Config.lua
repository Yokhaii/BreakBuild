return {
	-- Panel (PanelFrame) — positioned to the left of the backpack, just like crafting UIs
	PanelSize = UDim2.fromScale(0.7, 1.6),
	PanelPosition = UDim2.fromScale(-0.03, 1),
	PanelAnchorPoint = Vector2.new(1, 1),
	PanelAspectRatio = 0.65,

	-- Title
	TitleText = "Chest",

	-- Item grid inside the panel
	GridColumns = 5,
	GridRows = 5,
	SlotSize = UDim2.fromScale(1 / 5 - 0.02, 1 / 5 - 0.02),
	SlotCornerRadius = UDim.new(0.15, 0),
	SlotBackgroundColor = Color3.fromRGB(85, 85, 85),
	SlotStudImageTransparency = 0.91,
	SlotStrokeColor = Color3.fromRGB(0, 0, 0),
	SlotStrokeThickness = 2.5,
	SlotStrokeTransparency = 1,

	-- Hover / selected slot stroke
	SelectedStrokeColor = Color3.fromRGB(255, 220, 100),
	SelectedStrokeThickness = 3,
	SelectedStrokeTransparency = 0.2,

	-- Amount text
	AmountColor = Color3.fromRGB(255, 255, 255),
	AmountStrokeColor = Color3.fromRGB(0, 0, 0),
	AmountStrokeThickness = 1.5,

	-- Withdraw / Deposit buttons
	ButtonSize = UDim2.fromScale(0.42, 0.09),
	ButtonCornerRadius = UDim.new(0.3, 0),
	DepositButtonColor = Color3.fromRGB(60, 130, 60),
	WithdrawButtonColor = Color3.fromRGB(130, 80, 40),
	ButtonStudImageTransparency = 0.7,
	ButtonTextColor = Color3.fromRGB(255, 255, 255),
	ButtonFont = Font.fromEnum(Enum.Font.GothamBold),
}
