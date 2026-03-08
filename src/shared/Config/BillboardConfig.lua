--[[
	BillboardConfig.lua
	Configuration for GeneralPlayer Billboard animations and styling
]]

local BillboardConfig = {
	-- Hover Animation Settings
	Hover = {
		PositionXStart = 0.65, -- Starting X scale position
		PositionXEnd = 0.75, -- Ending X scale position (on hover)
		TransparencyStart = 1, -- Starting background transparency
		TransparencyEnd = 0.85, -- Ending background transparency (on hover)
		TweenTime = 0.2, -- Duration of the hover animation in seconds
		EasingStyle = Enum.EasingStyle.Quad, -- Easing style for smooth animation
		EasingDirection = Enum.EasingDirection.Out, -- Easing direction
	},

	-- Click Animation Settings
	Click = {
		BackgroundColor = Color3.fromRGB(220, 220, 220), -- Greyish white color on click
		TransparencyFlash = 0.77, -- Transparency value during click flash
		FlashTime = 0.1, -- Duration of the quick flash in seconds
		EasingStyle = Enum.EasingStyle.Linear, -- Easing for the click animation
		EasingDirection = Enum.EasingDirection.InOut,
	},

	-- Button Default Colors
	DefaultColors = {
		BackgroundColor = Color3.fromRGB(255, 255, 255), -- Default background color
		TextColor = Color3.fromRGB(0, 0, 0), -- Default text color
	},
}

return BillboardConfig
