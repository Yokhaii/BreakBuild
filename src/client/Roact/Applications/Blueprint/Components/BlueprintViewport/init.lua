--[=[
	BlueprintViewport Component
	Displays a completed blueprint model in a ViewportFrame.
	Hold-click and drag to spin on both axes; release with momentum for a flick
	that decays via friction.
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Roact = require(ReplicatedStorage.Packages.Roact)
local RoactHooks = require(ReplicatedStorage.Packages.Hooks)

local AppConfig = require(script.Parent.Parent.Config)

local SENSITIVITY = AppConfig.SpinSensitivity
local FRICTION    = AppConfig.SpinFriction

local function BlueprintViewport(props, hooks)
	local model  = props.Model
	local zIndex = props.ZIndex or 1

	local viewportRef = hooks.useValue(Roact.createRef())

	-- Per-axis angular velocity (degrees/frame)
	local velocityX = hooks.useValue(0) -- pitch (up/down), rotates around camera right
	local velocityY = hooks.useValue(0) -- yaw   (left/right), rotates around world Y

	local isDragging  = hooks.useValue(false)
	local lastMouseX  = hooks.useValue(0)
	local lastMouseY  = hooks.useValue(0)
	local frameDeltaX = hooks.useValue(0) -- horizontal drag delta this frame
	local frameDeltaY = hooks.useValue(0) -- vertical drag delta this frame

	local modelClone = hooks.useValue(nil)
	local pivotCF    = hooks.useValue(CFrame.new())
	local cameraRef  = hooks.useValue(nil) -- kept so RenderStepped can read its right vector

	hooks.useEffect(function()
		local viewport = viewportRef.value:getValue()
		if not viewport or not model then return end

		for _, child in ipairs(viewport:GetChildren()) do
			if child:IsA("Camera") or child:IsA("Model") or child:IsA("BasePart") then
				child:Destroy()
			end
		end

		local clone = model:Clone()
		clone.Parent = viewport
		modelClone.value = clone

		local cf, size = clone:GetBoundingBox()
		local radius = math.max(size.X, size.Y, size.Z)

		pivotCF.value = CFrame.new(cf.Position)

		local dist = radius * 2.0
		local camPos = cf.Position + Vector3.new(dist * 0.7, dist * 0.5, dist * 0.9)
		local camera = Instance.new("Camera")
		camera.FieldOfView = 35
		camera.CFrame = CFrame.lookAt(camPos, cf.Position)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		cameraRef.value = camera

		velocityX.value = 0
		velocityY.value = 0

		return function()
			if clone and clone.Parent then clone:Destroy() end
			if camera and camera.Parent then camera:Destroy() end
			modelClone.value = nil
			cameraRef.value = nil
		end
	end, { model })

	hooks.useEffect(function()
		local connection = RunService.RenderStepped:Connect(function()
			local clone = modelClone.value
			if not clone or not clone.Parent then return end

			if isDragging.value then
				velocityY.value = frameDeltaX.value
				velocityX.value = frameDeltaY.value
				frameDeltaX.value = 0
				frameDeltaY.value = 0
			else
				velocityX.value = velocityX.value * FRICTION
				velocityY.value = velocityY.value * FRICTION
				if math.abs(velocityX.value) < 0.01 then velocityX.value = 0 end
				if math.abs(velocityY.value) < 0.01 then velocityY.value = 0 end
				if velocityX.value == 0 and velocityY.value == 0 then return end
			end

			if velocityX.value == 0 and velocityY.value == 0 then return end

			local center = pivotCF.value

			-- Yaw: rotate around world Y through model center
			local yaw = CFrame.Angles(0, math.rad(velocityY.value), 0)

			-- Pitch: rotate around the camera's right vector through model center
			-- This keeps up/down consistent with what the player sees
			local pitchAxis = Vector3.new(1, 0, 0) -- world X as fallback
			local cam = cameraRef.value
			if cam then
				pitchAxis = cam.CFrame.RightVector
			end
			local pitch = CFrame.fromAxisAngle(pitchAxis, math.rad(velocityX.value))

			local currentPivot = clone:GetPivot()
			local rotated = center * yaw * center:Inverse() * currentPivot
			rotated = center * pitch * center:Inverse() * rotated
			clone:PivotTo(rotated)
		end)

		return function()
			connection:Disconnect()
		end
	end, {})

	local function onInputBegan(_, input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			isDragging.value = true
			lastMouseX.value = input.Position.X
			lastMouseY.value = input.Position.Y
			frameDeltaX.value = 0
			frameDeltaY.value = 0
			velocityX.value = 0
			velocityY.value = 0
			if props.OnDragStart then props.OnDragStart() end
		end
	end

	local function onInputChanged(_, input)
		if not isDragging.value then return end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			frameDeltaX.value = (input.Position.X - lastMouseX.value) * SENSITIVITY
			frameDeltaY.value = (input.Position.Y - lastMouseY.value) * SENSITIVITY
			lastMouseX.value = input.Position.X
			lastMouseY.value = input.Position.Y
		end
	end

	local function onInputEnded(_, input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			isDragging.value = false
			if props.OnDragEnd then props.OnDragEnd() end
		end
	end

	return Roact.createElement("ViewportFrame", {
		Name = "BlueprintViewport",
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = zIndex,
		Ambient = Color3.fromRGB(155, 155, 155),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -2, -1),
		[Roact.Ref] = viewportRef.value,
		[Roact.Event.InputBegan] = onInputBegan,
		[Roact.Event.InputChanged] = onInputChanged,
		[Roact.Event.InputEnded] = onInputEnded,
	})
end

BlueprintViewport = RoactHooks.new(Roact)(BlueprintViewport)
return BlueprintViewport
