return {
	-- Frame (top right, right under the BalanceDisplay)
	Position = UDim2.fromScale(0.98, 0.065),
	AnchorPoint = Vector2.new(1, 0),
	Size = UDim2.fromScale(0.1, 0.085),

	-- Block count ("x14") on top, step label ("STREAK +10%") under it, reset bar at the bottom
	CountSize = UDim2.fromScale(1, 0.5),
	LabelPosition = UDim2.fromScale(0, 0.5),
	LabelSize = UDim2.fromScale(1, 0.32),
	LabelText = "STREAK",

	-- Reset bar: full while breaking, drains over StreakResetDelay once the player stops
	BarPosition = UDim2.fromScale(1, 0.86),
	BarAnchorPoint = Vector2.new(1, 0),
	BarSize = UDim2.fromScale(0.8, 0.12),
	BarBackgroundColor = Color3.fromRGB(30, 30, 30),
	BarBackgroundTransparency = 0.3,
	BarCornerRadius = UDim.new(1, 0),
	BarStrokeThickness = 1.5,
	BarRefillDuration = 0.15, -- Seconds to snap back to full when breaking again

	-- Text and bar color per streak step
	StepColors = {
		Color3.fromRGB(255, 220, 80),
		Color3.fromRGB(255, 150, 40),
		Color3.fromRGB(255, 70, 50),
	},
	StrokeColor = Color3.fromRGB(0, 0, 0),
	StrokeThickness = 2,

	-- Pop when a block is broken
	PopScale = 1.2,
	PopDuration = 0.2,

	ZIndex = 5,
}
