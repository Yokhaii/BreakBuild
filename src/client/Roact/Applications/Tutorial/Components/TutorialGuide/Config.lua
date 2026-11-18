return {
	-- Frame (top middle, under the CycleTimer)
	Position = UDim2.fromScale(0.5, 0.08),
	AnchorPoint = Vector2.new(0.5, 0),
	Size = UDim2.fromScale(0.26, 0.1),
	TitleShare = 0.38, -- Fraction of the frame height used by the title

	-- Title ("TUTORIAL 1/6")
	TitleText = "TUTORIAL %d/%d",

	-- Close button skipping the tutorial (right side of the title bar, square fitted in this size)
	SkipButtonPosition = UDim2.fromScale(0.985, 0.19), -- 0.19 = middle of the title (TitleShare / 2)
	SkipButtonAnchorPoint = Vector2.new(1, 0.5),
	SkipButtonSize = UDim2.fromScale(0.1, 0.28), -- Height-bound: ~75% of the title bar

	-- Step explanation
	HintSize = UDim2.fromScale(1, 1),
	HintColor = Color3.fromRGB(255, 255, 255),
	HintFont = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold),
	PaddingHorizontal = UDim.new(0.04, 0),
	PaddingVertical = UDim.new(0.12, 0),
}
