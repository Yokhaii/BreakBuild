return {
	-- Light type settings
	LightEnabled = true, -- Set to false to disable player lights entirely

	-- PointLight properties
	Brightness = 0.2, -- Light intensity (0-10+, default ~1)
	Color = Color3.fromRGB(255, 220, 180), -- Warm white light color
	Range = 20, -- How far the light reaches in studs
	Shadows = false, -- Whether the light casts shadows

	-- Attachment settings
	AttachmentOffset = Vector3.new(0, 0, 0), -- Offset from HumanoidRootPart center
}
