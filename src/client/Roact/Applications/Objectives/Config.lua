return {
	FrameName = "Objectives",
	Title = "Objectives",

	-- Centered panel
	ContainerSize = UDim2.fromScale(0.55, 0.8),
	ContainerPosition = UDim2.fromScale(0.5, 0.5),
	ContainerAnchorPoint = Vector2.new(0.5, 0.5),
	ContainerAspectRatio = 1.25,

	-- Close button (top-right corner of the panel)
	CloseButtonPosition = UDim2.fromScale(0.985, 0.012),
	CloseButtonAnchorPoint = Vector2.new(1, 0),
	CloseButtonSize = UDim2.fromScale(0.06, 0.06),

	-- Tabs (top of the content area)
	TabsSize = UDim2.fromScale(0.72, 0.075),
	TabsPosition = UDim2.fromScale(0.02, 0.015),
	Tabs = {
		{ key = "Active", label = "Active" },
		{ key = "Locked", label = "Locked" },
		{ key = "Completed", label = "Done" },
	},
	DefaultTab = "Active",

	-- Pin counter (top-right of the content area)
	PinCountText = "Pinned %d/%d",
	PinCountSize = UDim2.fromScale(0.22, 0.05),
	PinCountPosition = UDim2.fromScale(0.98, 0.03),
	PinCountAnchorPoint = Vector2.new(1, 0),
	PinCountColor = Color3.fromRGB(255, 255, 255),

	-- List (below the tabs)
	ListSize = UDim2.fromScale(1, 0.895),
	ListPosition = UDim2.fromScale(0, 0.105),

	-- Layering
	OverlayZIndex = 10,
	PanelZIndex = 12,
	ContentZIndex = 14,
}
