return {
	-- Bar along the bottom of the item slot
	Size = UDim2.fromScale(0.75, 0.08),
	Position = UDim2.fromScale(0.5, 0.92),
	AnchorPoint = Vector2.new(0.5, 1),
	CornerRadius = UDim.new(1, 0),

	TrackColor = Color3.fromRGB(20, 20, 20),
	TrackTransparency = 0.2,

	-- Fill color goes from EmptyColor (worn out) to FullColor (new)
	FullColor = Color3.fromRGB(90, 220, 90),
	EmptyColor = Color3.fromRGB(230, 60, 60),

	-- Hide the bar while the tool is still unused
	HideWhenFull = true,
}
