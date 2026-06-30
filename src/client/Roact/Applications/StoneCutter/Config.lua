return {
	-- Left panel (PanelFrame) - same pattern as Workbench
	PanelSize = UDim2.fromScale(0.6, 1.6),
	PanelPosition = UDim2.fromScale(-0.03, 1),
	PanelAnchorPoint = Vector2.new(1, 1),
	PanelAspectRatio = 0.65,

	-- Top panel (TopPanelFrame) - sits above the backpack
	TopPanelSize = UDim2.fromScale(1, 0.4),
	TopPanelPosition = UDim2.fromScale(0.5, -0.03),
	TopPanelAnchorPoint = Vector2.new(0.5, 1),

	-- Title
	TitleText = "Stone Cutter",
	TitlePosition = UDim2.fromScale(0.02, 0),
	TitleSize = UDim2.fromScale(0.3, 0.2),
	TitleAnchorPoint = Vector2.new(0, 0),
	TitleZIndex = 14,

	-- Crafting area (input slots + arrow + output slot + craft button)
	CraftingAreaSize = UDim2.fromScale(0.96, 0.7),
	CraftingAreaPosition = UDim2.fromScale(0.5, 0.6),
	CraftingAreaAnchorPoint = Vector2.new(0.5, 0.5),
	CraftingAreaPadding = UDim.new(0.02, 0),

	-- Item slots
	SlotSize = UDim2.fromScale(0.12, 0.8),
	MissingSlotBackgroundColor = Color3.fromRGB(110, 70, 70),
	MissingImageTransparency = 0.5,

	-- Arrow
	ArrowSize = UDim2.fromScale(0.08, 0.6),
	ArrowText = "\226\134\146",
	ArrowColor = Color3.fromRGB(200, 200, 200),
	ArrowFont = Font.fromEnum(Enum.Font.GothamBold),

	-- Craft button
	CraftButtonPosition = UDim2.fromScale(0.92, 0.6),
	CraftButtonAnchorPoint = Vector2.new(0.5, 0.5),
	CraftButtonSize = UDim2.fromScale(0.14, 0.5),
	CraftButtonColor = Color3.fromRGB(80, 180, 80),
	CraftButtonStudImageTransparency = 0.7,
	CraftButtonText = "Craft",
	CraftButtonTextColor = Color3.fromRGB(255, 255, 255),
	CraftButtonFont = Font.fromEnum(Enum.Font.GothamBold),
	CraftButtonCornerRadius = UDim.new(0.2, 0),
	CraftButtonPaddingH = UDim.new(0.05, 0),
	CraftButtonPaddingV = UDim.new(0.1, 0),

	-- Progress bar (on top panel)
	ProgressBarSize = UDim2.fromScale(0.9, 0.06),
	ProgressBarPosition = UDim2.fromScale(0.5, 0.95),
	ProgressBarAnchorPoint = Vector2.new(0.5, 1),
	ProgressBarBackgroundColor = Color3.fromRGB(40, 40, 40),
	ProgressBarFillColor = Color3.fromRGB(80, 200, 80),
	ProgressBarCornerRadius = UDim.new(0.5, 0),
}
