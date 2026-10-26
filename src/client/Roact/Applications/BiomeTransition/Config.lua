return {
	-- Screen colors (matches ItemSlot style)
	ScreenColor = Color3.fromRGB(85, 85, 85),
	StudImageTransparency = 0.91,

	-- Text
	TextContent = "Changing Biome",
	TextPosition = UDim2.fromScale(0.5, 0.5),
	TextAnchorPoint = Vector2.new(0.5, 0.5),
	TextSize = UDim2.fromScale(0.4, 0.15),
	TextColor = Color3.fromRGB(0, 0, 0), -- Black text
	TextFont = Font.fromEnum(Enum.Font.GothamBold),

	-- Animation timing
	WipeInDuration = 0.5, -- Left to right wipe in
	HoldDuration = 2.0, -- Stay visible
	WipeOutDuration = 0.5, -- Right to left wipe out

	-- ZIndex (above everything)
	ZIndex = 1000,
}
