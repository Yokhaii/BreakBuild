return {
	-- Dark overlay around the hole
	OverlayColor = Color3.fromRGB(0, 0, 0),
	OverlayTransparency = 0.35,

	-- Extra space around the target, as a fraction of its smallest side
	HolePadding = 0.12,

	-- Pulsing ring around the hole
	RingColor = Color3.fromRGB(255, 220, 60),
	RingThickness = 3,
	RingMinTransparency = 0,
	RingMaxTransparency = 0.6,
	RingCornerRadius = UDim.new(0.12, 0),
	PulseSpeed = 5,

	-- Click icon (offset from the hole center, in screen scale)
	IconOffset = Vector2.new(0, 0.005),
	IconBobAmplitude = 0.008,

	-- Hint label next to the hole
	HintSize = UDim2.fromScale(0.36, 0.05),
	HintEdgeMargin = 0.19, -- Keeps the label on screen (half its width + margin)
	HintGapAbove = 0.015,
	HintGapBelow = 0.09, -- Leaves room for the click icon
	HintColor = Color3.fromRGB(255, 255, 255),
}
