--[=[
	ViewportItem Component
	Renders a 3D model inside a ViewportFrame with full camera and model control

	Props:
		Model: Model or BasePart to display

		-- Layout
		Size: UDim2 (optional)
		Position: UDim2 (optional)
		AnchorPoint: Vector2 (optional)
		ZIndex: number (optional)

		-- Camera
		CameraFOV: number (optional, field of view)
		CameraOrientation: Vector3 (optional, degrees — paste directly from Studio e.g. Vector3.new(-23.968, -160.593, 0))
		CameraOffset: Vector3 (optional, camera position relative to model center)

		-- Model
		ModelRotation: CFrame (optional, rotate the model itself)
		ModelScale: number (optional, scale the model up/down)

		-- Lighting
		LightColor: Color3 (optional)
		LightDirection: Vector3 (optional)
		AmbientColor: Color3 (optional)
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local Config = require(script.Config)

local function ViewportItem(props, hooks)
	local viewportRef = hooks.useValue(Roact.createRef())

	local model = props.Model
	local size = props.Size or Config.DefaultSize
	local cameraFOV = props.CameraFOV or Config.DefaultCameraFOV
	local cameraOrientation = props.CameraOrientation or Config.CameraOrientation
	local cameraOffset = props.CameraOffset or Config.CameraOffset
	local modelRotation = props.ModelRotation or Config.ModelRotation
	local modelScale = props.ModelScale or Config.ModelScale
	local lightColor = props.LightColor or Config.LightColor
	local lightDirection = props.LightDirection or Config.LightDirection
	local ambientColor = props.AmbientColor or Config.AmbientColor

	hooks.useEffect(function()
		local viewport = viewportRef.value:getValue()
		if not viewport or not model then return end

		-- Clear previous children
		for _, child in ipairs(viewport:GetChildren()) do
			if child:IsA("Camera") or child:IsA("Model") or child:IsA("BasePart") then
				child:Destroy()
			end
		end

		-- Clone the model into the viewport
		local clone
		if model:IsA("Model") or model:IsA("BasePart") then
			clone = model:Clone()
		else
			return
		end

		-- Apply model scale
		if modelScale ~= 1 then
			if clone:IsA("Model") then
				clone:ScaleTo(modelScale)
			else
				clone.Size = clone.Size * modelScale
			end
		end

		-- Apply model rotation
		if clone:IsA("Model") then
			local pivot = clone:GetPivot()
			clone:PivotTo(pivot * modelRotation)
		else
			clone.CFrame = clone.CFrame * modelRotation
		end

		local selectionBox = Instance.new("SelectionBox")
		selectionBox.Color3 = Color3.fromRGB(0, 0, 0)
		selectionBox.LineThickness = 0.02
		selectionBox.SurfaceTransparency = 1
		selectionBox.Adornee = clone
		selectionBox.Parent = clone

		clone.Parent = viewport

		-- Get model center
		local cf
		if clone:IsA("Model") then
			cf = clone:GetBoundingBox()
		else
			cf = clone.CFrame
		end

		-- Camera placed at exact offset from model center, with exact orientation
		local camera = Instance.new("Camera")
		camera.FieldOfView = cameraFOV
		local orientation = CFrame.fromOrientation(
			math.rad(cameraOrientation.X),
			math.rad(cameraOrientation.Y),
			math.rad(cameraOrientation.Z)
		)
		camera.CFrame = CFrame.new(cf.Position + cameraOffset) * orientation

		camera.Parent = viewport
		viewport.CurrentCamera = camera

		return function()
			if clone then clone:Destroy() end
			if camera then camera:Destroy() end
		end
	end, { model })

	return Roact.createElement("ViewportFrame", {
		Name = "ViewportItem",
		Size = size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = Config.BackgroundTransparency,
		BorderSizePixel = 0,
		ZIndex = props.ZIndex or 1,
		Ambient = ambientColor,
		LightColor = lightColor,
		LightDirection = lightDirection,
		[Roact.Ref] = viewportRef.value,
	})
end

ViewportItem = RoactHooks.new(Roact)(ViewportItem)
return ViewportItem
