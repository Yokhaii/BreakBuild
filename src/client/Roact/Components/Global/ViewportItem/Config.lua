--[=[
	ViewportItem Configuration
]=]

return {
	-- Default size
	DefaultSize = UDim2.fromScale(1, 1),

	-- Background
	BackgroundTransparency = 1,

	-- Camera
	DefaultCameraFOV = 4,
	CameraOrientation = Vector3.new(-24, -160, 0),
	CameraOffset = Vector3.new(-11, 14, -29.5),

	-- Model
	ModelRotation = CFrame.Angles(0, 0, 0),
	ModelScale = 1,

	-- Lighting
	LightColor = Color3.new(1, 1, 1),
	LightDirection = Vector3.new(0, 0, 0),
	AmbientColor = Color3.fromRGB(180, 180, 180),
}
