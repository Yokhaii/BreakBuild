return {
	-- How often TutorialController recomputes the current sub-step (seconds)
	GuideUpdateInterval = 0.1,

	-- How often the closest breakable target is searched again (seconds)
	TargetRefreshInterval = 1,

	-- Breaking Area targets must be at or above this grid layer (0 = ground layer, 1+ = above ground)
	MinGridHeight = 1,

	-- Workspace container holding the breakables of each material
	BreakableContainers = {
		Log = "Outside",
		Stone = "GlobalBreakingBlocks",
	},

	-- Beam from the player to the world target
	BeamColor = Color3.fromRGB(255, 220, 60),
	BeamWidth = 0.6,
	BeamTransparency = 0.2,
	BeamLightEmission = 1,
	BeamTexture = "", -- Optional arrow texture (rbxassetid://...)
	BeamTextureSpeed = 1,
	BeamTextureLength = 2,

	-- Outline highlight on the world target
	HighlightColor = Color3.fromRGB(255, 220, 60),
	HighlightOutlineTransparency = 0,
}
