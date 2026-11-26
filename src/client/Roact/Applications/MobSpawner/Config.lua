return {
	FrameName = "MobSpawner",
	Title = "Mob Spawner",

	-- Panel on the right side of the screen (the player keeps moving while it is open)
	FrameSize = UDim2.fromScale(0.3, 0.8),
	FramePosition = UDim2.fromScale(0.83, 0.5),
	FrameAspectRatio = 0.62,
	ZIndex = 12,

	-- Scrolling list inside the content area. Heights are fractions of the visible list
	-- height; the canvas grows when the rows don't fit (more mob types)
	ListPadding = 0.015,
	ListInnerPadding = UDim.new(0.04, 0),
	ScrollBarThickness = 4,
	ScrollBarColor = Color3.fromRGB(200, 200, 200),
	SectionHeight = 0.055,
	MobRowHeight = 0.085,
	ActionRowHeight = 0.085,
	ToggleHeight = 0.08,

	-- Section titles
	SectionTextColor = Color3.fromRGB(255, 255, 255),
	SectionStrokeColor = Color3.fromRGB(40, 40, 40),
	SpawnSectionText = "SPAWN (frozen, in front of you)",
	MobsSectionText = "MOBS  ·  %d alive  ·  %d frozen  ·  %d dev",

	-- Mob rows: name + alive count, then the spawn buttons
	MobNameSize = UDim2.fromScale(0.42, 0.8),
	MobNameTextColor = Color3.fromRGB(255, 255, 255),
	MobCountText = "%s  (%d)",
	SpawnAmounts = { 1, 5 },
	SpawnButtonSize = UDim2.fromScale(0.26, 0.85),
	SpawnButtonColor = Color3.fromRGB(70, 170, 90),

	-- Action buttons (two per row)
	ActionButtonWidth = 0.485,
	ActionColor = Color3.fromRGB(70, 130, 220),
	DangerColor = Color3.fromRGB(200, 70, 70),
	ToggleOnColor = Color3.fromRGB(70, 170, 90),
	ToggleOffColor = Color3.fromRGB(120, 120, 120),
	NaturalSpawnText = "Natural spawning: %s",
}
