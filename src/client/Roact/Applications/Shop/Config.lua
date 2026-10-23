return {
	-- Left panel (PanelFrame) — item catalog
	PanelSize = UDim2.fromScale(0.6, 1.6),
	PanelPosition = UDim2.fromScale(-0.03, 1),
	PanelAnchorPoint = Vector2.new(1, 1),
	PanelAspectRatio = 0.65,

	-- Right panel (PanelFrame) — basket / sell pool
	RightPanelSize = UDim2.fromScale(0.6, 1.6),
	RightPanelPosition = UDim2.fromScale(1.03, 1),
	RightPanelAnchorPoint = Vector2.new(0, 1),
	RightPanelAspectRatio = 0.65,

	-- Top panel (TopPanelFrame) — buy/sell action
	TopPanelSize = UDim2.fromScale(1, 0.4),
	TopPanelPosition = UDim2.fromScale(0.5, -0.03),
	TopPanelAnchorPoint = Vector2.new(0.5, 1),

	-- Title
	TitleText = "Shop",
	TitlePosition = UDim2.fromScale(0.02, 0),
	TitleSize = UDim2.fromScale(0.25, 0.2),
	TitleAnchorPoint = Vector2.new(0, 0),
	TitleZIndex = 14,

	-- Balance display
	BalancePosition = UDim2.fromScale(0.98, 0.15),
	BalanceAnchorPoint = Vector2.new(1, 0),
	BalanceSize = UDim2.fromScale(0.35, 0.2),
	BalanceColor = Color3.fromRGB(80, 200, 80),
	BalanceFont = Font.fromEnum(Enum.Font.GothamBold),

	-- Total cost / value display
	TotalPosition = UDim2.fromScale(0.5, 0.5),
	TotalAnchorPoint = Vector2.new(0.5, 0.5),
	TotalSize = UDim2.fromScale(0.4, 0.3),
	TotalColor = Color3.fromRGB(255, 255, 255),
	TotalFont = Font.fromEnum(Enum.Font.GothamBold),

	-- Action button (Buy / Sell)
	ActionButtonPosition = UDim2.fromScale(0.5, 0.8),
	ActionButtonAnchorPoint = Vector2.new(0.5, 0.5),
	ActionButtonSize = UDim2.fromScale(0.25, 0.35),
	ActionButtonFont = Font.fromEnum(Enum.Font.GothamBold),
	ActionButtonTextColor = Color3.fromRGB(255, 255, 255),
	ActionButtonCornerRadius = UDim.new(0.2, 0),
	ActionButtonStudImageTransparency = 0.7,
	ActionButtonPaddingH = UDim.new(0.05, 0),
	ActionButtonPaddingV = UDim.new(0.1, 0),

	BuyButtonColor = Color3.fromRGB(80, 180, 80),
	SellButtonColor = Color3.fromRGB(200, 60, 60),

	-- Disabled button
	DisabledButtonColor = Color3.fromRGB(80, 80, 80),
}
