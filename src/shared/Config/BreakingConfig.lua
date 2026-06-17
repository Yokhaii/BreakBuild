--[[
	BreakingConfig.lua
	Configuration for the Breaking system grid and spawning
]]

return {
	-- Breaking settings
	BreakRange = 24, -- Studs
	BreakConeAngle = 60, -- Degrees (total cone, so 30 degrees each side)

	-- Bare hand breaking (no tool equipped)
	BareHandBreakSpeed = 0.25, -- Very slow break speed (4x slower than normal)
	BareHandToolTier = "Hand", -- Can only break materials that require "Hand" tier or lower
}
