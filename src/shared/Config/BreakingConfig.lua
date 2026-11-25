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

	-- Breaking streak (any tool): every StreakStepDuration seconds of active breaking,
	-- the next completed break moves the streak up one step
	StreakStepDuration = 10, -- Seconds of active breaking per step
	StreakStepBonuses = { 0.1, 0.2, 0.3 }, -- Break time reduction per step (step 1 = 10% faster)
	StreakResetDelay = 7, -- Seconds without breaking before the streak resets
}
