return {
	-- Card (width-driven height so it works inside the ScrollingFrame)
	CardSize = UDim2.fromScale(0.97, 1),
	AspectRatio = 4.4,
	CornerRadius = UDim.new(0.08, 0),

	CardStudBackgroundColor = Color3.fromRGB(145, 145, 145),
	CardStudImageTransparency = 0.7,
	CardStrokeColor = Color3.fromRGB(255, 255, 255),
	CardStrokeThickness = 2,
	CardStrokeTransparency = 0.87,
	CompleteStrokeColor = Color3.fromRGB(255, 200, 50),
	CompleteStrokeTransparency = 0,

	DimOverlayColor = Color3.fromRGB(0, 0, 0),
	LockedOverlayTransparency = 0.55,
	ClaimedOverlayTransparency = 0.7,

	ContentPaddingHorizontal = UDim.new(0.025, 0),
	ContentPaddingVertical = UDim.new(0.07, 0),

	-- Left: info
	InfoSize = UDim2.fromScale(0.64, 1),
	InfoListPadding = UDim.new(0.03, 0),

	TagSize = UDim2.fromScale(1, 0.15),
	MainTagText = "MAIN",
	SideTagText = "SIDE",
	MainTagColor = Color3.fromRGB(255, 220, 60),
	SideTagColor = Color3.fromRGB(120, 190, 255),

	TitleSize = UDim2.fromScale(1, 0.24),
	TitleColor = Color3.fromRGB(40, 40, 40),
	TitleStrokeColor = Color3.fromRGB(160, 160, 160),
	TitleStrokeThickness = 2,

	DescriptionSize = UDim2.fromScale(1, 0.22),
	DescriptionColor = Color3.fromRGB(70, 70, 70),
	DescriptionFont = Font.fromEnum(Enum.Font.Gotham),

	BarSize = UDim2.fromScale(0.95, 0.22),

	StatusTextSize = UDim2.fromScale(1, 0.2),
	LockedMainText = "Complete the previous main objective",
	LockedSideText = "Unlocks after: %s",
	ClaimedText = "Claimed",
	LockedTextColor = Color3.fromRGB(230, 230, 230),
	ClaimedTextColor = Color3.fromRGB(120, 230, 120),

	-- Right: rewards + buttons
	SideSize = UDim2.fromScale(0.34, 1),
	SidePosition = UDim2.fromScale(1, 0),
	SideAnchorPoint = Vector2.new(1, 0),
	SideListPadding = UDim.new(0.04, 0),

	RewardsLabelText = "REWARDS",
	RewardsLabelSize = UDim2.fromScale(1, 0.16),
	RewardsLabelColor = Color3.fromRGB(60, 60, 60),

	RewardsRowSize = UDim2.fromScale(1, 0.34),
	RewardsRowPadding = UDim.new(0.04, 0),
	DollarRewardSize = UDim2.fromScale(0.4, 1),
	DollarRewardColor = Color3.fromRGB(40, 150, 40),
	RewardItemSize = UDim2.fromScale(0.25, 1),

	ButtonRowSize = UDim2.fromScale(1, 0.3),
	ButtonRowPadding = UDim.new(0.04, 0),
	ClaimText = "CLAIM",
	PinText = "PIN",
	UnpinText = "UNPIN",
	ButtonSize = UDim2.fromScale(0.48, 1),
}
