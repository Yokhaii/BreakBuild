return {
	-- Frame (left side, right below the SpawnButton)
	Position = UDim2.fromScale(0.005, 0.325),
	AnchorPoint = Vector2.new(0, 0),
	Size = UDim2.fromScale(0.13, 0.34),

	-- Heights below are fractions of the tracker height (the panel grows with its rows)
	TitleHeight = 0.11,
	ContentPadding = 0.02, -- Top / bottom padding inside the content area
	RowHeight = 0.14,
	DividerHeight = 0.02, -- Space holding the line between main and pinned objectives

	-- How many upcoming main objectives are previewed under the current one
	UpcomingMainCount = 2,

	TitleText = "OBJECTIVES",
	ContentPaddingHorizontal = UDim.new(0.04, 0),

	-- Divider between the main and pinned objectives
	DividerSize = UDim2.fromScale(1, 0.15),
	DividerColor = Color3.fromRGB(255, 255, 255),
	DividerTransparency = 0.75,

	ZIndex = 5,
}
