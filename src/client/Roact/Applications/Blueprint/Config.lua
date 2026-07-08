return {
	-- Left panel (blueprint list) — vertically centered, hugging the left edge
	LeftPanelSize = UDim2.fromScale(0.24, 0.78),
	LeftPanelPosition = UDim2.fromScale(0.02, 0.5),
	LeftPanelAnchorPoint = Vector2.new(0, 0.5),
	LeftPanelAspectRatio = 0.65,

	-- Right panel (recipe / materials) — vertically centered, hugging the right edge
	RightPanelSize = UDim2.fromScale(0.24, 0.78),
	RightPanelPosition = UDim2.fromScale(0.98, 0.5),
	RightPanelAnchorPoint = Vector2.new(1, 0.5),
	RightPanelAspectRatio = 0.65,

	-- Panel label (top-left of content area inside each PanelFrame)
	PanelLabelSize = UDim2.fromScale(0.5, 0.06),
	PanelLabelColor = Color3.fromRGB(180, 180, 180),

	-- Center title panel (TopPanelFrame) — centered horizontally, sits above center of screen
	TitlePanelSize = UDim2.fromScale(0.2, 0.07),
	TitlePanelPosition = UDim2.fromScale(0.5, 0.12),
	TitlePanelAnchorPoint = Vector2.new(0.5, 0.5),

	-- Center viewport (no background) — smaller center area
	ViewportSize = UDim2.fromScale(0.4, 0.52),
	ViewportPosition = UDim2.fromScale(0.5, 0.48),
	ViewportAnchorPoint = Vector2.new(0.5, 0.5),

	-- Close button (on title panel)
	CloseBtnPosition = UDim2.fromScale(0.97, 0.5),
	CloseBtnAnchorPoint = Vector2.new(1, 0.5),
	CloseBtnSize = UDim2.fromScale(0.1, 0.7),

	-- Title text
	TitlePosition = UDim2.fromScale(0.45, 0.5),
	TitleAnchorPoint = Vector2.new(0.5, 0.5),
	TitleSize = UDim2.fromScale(0.75, 0.65),
	TitleZIndex = 14,

	-- Material strip (bottom-center, below the viewport)
	MaterialStripSize = UDim2.fromScale(0.22, 0.06),
	MaterialStripPosition = UDim2.fromScale(0.5, 0.78),
	MaterialStripAnchorPoint = Vector2.new(0.5, 0.5),

	-- Selected card highlight
	SelectedCardStrokeColor = Color3.fromRGB(255, 200, 50),
	SelectedCardBackgroundColor = Color3.fromRGB(90, 90, 50),

	-- Spin interaction
	SpinFriction = 0.92,   -- velocity multiplier per frame when released
	SpinSensitivity = 0.5, -- degrees per pixel dragged
}
