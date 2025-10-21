local AnimationModule = require(script.Parent.AnimationModule)
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local MoonAnimationModule = {}
MoonAnimationModule.__index = MoonAnimationModule
setmetatable(MoonAnimationModule, AnimationModule)

function MoonAnimationModule.new(animationId, animationData, customModel)
	local self = AnimationModule.new(animationId, animationData, customModel)
	setmetatable(self, MoonAnimationModule)

	self.animationData = animationData
	self.particleEmitters = {}
	self.baseParts = {}
	self.models = {}
	self.behaviors = {}
	self.updateConnection = nil
	self.lastProcessedFrame = -1
	self.camera = workspace.CurrentCamera
	self.initialCameraState = nil
	self.currentCameraTween = nil
	self.cameraMode = "Relative"
	self.activeCameraTweens = {}
	self.activeBasePartTweens = {}
	self.activeModelTweens = {}
	self.cameraPos = nil
	self.originalCameraType = nil
	self.playerMovementDisabled = false
	self.originalWalkSpeed = 0
	self.originalJumpPower = 0
	self.tweenInitialFrame = false

	return self
end

function MoonAnimationModule:_shouldDisablePlayerMovement()
	local player = Players.LocalPlayer
	return self.model == player.Character and (self.cameraPos ~= nil or next(self.baseParts) ~= nil)
end

function MoonAnimationModule:_disablePlayerMovement()
	if not self:_shouldDisablePlayerMovement() then
		return
	end

	if self.humanoid then
		self.originalWalkSpeed = self.humanoid.WalkSpeed
		self.originalJumpPower = self.humanoid.JumpPower
		self.humanoid.WalkSpeed = 0
		self.humanoid.JumpPower = 0
		self.playerMovementDisabled = true
	end
end

function MoonAnimationModule:_enablePlayerMovement()
	if not self.playerMovementDisabled then
		return
	end

	if self.humanoid then
		self.humanoid.WalkSpeed = self.originalWalkSpeed
		self.humanoid.JumpPower = self.originalJumpPower
	end
	self.playerMovementDisabled = false
end

function MoonAnimationModule:_findBasePartInModel(partName)
	local function recursiveSearch(parent)
		for _, child in ipairs(parent:GetChildren()) do
			if child.Name == partName then
				return child
			end
			if #child:GetChildren() > 0 then
				local result = recursiveSearch(child)
				if result then
					return result
				end
			end
		end
	end
	return recursiveSearch(self.model)
end

function MoonAnimationModule:_setupBaseParts(index, item)
	if not self.model then
		warn("Model not found. Cannot set up base parts.")
		return
	end

	local animationName = self.animationData.Name
	local baseParts = game:GetService("ReplicatedStorage").Assets.Animations[animationName]

	if not baseParts then
		warn("BaseParts folder not found for animation:", animationName)
		return
	end

	local originalPart = baseParts:FindFirstChild(item.Name)
	if not originalPart then
		warn("BasePart not found:", item.Name)
		return
	end

	local newPart = originalPart:Clone()
	newPart.CanCollide = false
	newPart.CanTouch = false
	newPart.CanQuery = false
	newPart.Anchored = true

	if item.Place == "" then
		newPart.Parent = self.model
	else
		local parentPart = self:_findBasePartInModel(item.Place)
		if parentPart then
			newPart.Parent = parentPart
		else
			warn("Parent part not found:", item.Place)
			return
		end
	end

	self.baseParts[index] = newPart

	-- Set up ParticleEmitters inside the BasePart
	for _, child in ipairs(newPart:GetDescendants()) do
		if child:IsA("ParticleEmitter") then
			self.particleEmitters[child.Name] = child
		end
	end
end

function MoonAnimationModule:_setupModels(index, item)
	if not self.model then
		warn("Model not found. Cannot set up models.")
		return
	end

	local animationName = self.animationData.Name
	local assets = game:GetService("ReplicatedStorage").Assets.Animations[animationName]

	if not assets then
		warn("Models folder not found for animation:", animationName)
		return
	end

	local originalModel = assets:FindFirstChild(item.Name)
	if not originalModel then
		warn("Model not found:", item.Name)
		return
	end

	local newModel = originalModel:Clone()

	if item.Place == "" then
		newModel.Parent = self.model
	else
		local parentObject = self:_findBasePartInModel(item.Place)
		if parentObject then
			newModel.Parent = parentObject
		else
			warn("Parent object not found:", item.Place)
			return
		end
	end

	-- Set initial properties
	for _, part in ipairs(newModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Transparency = 1
			part.CanCollide = false
			part.CanTouch = false
			part.CanQuery = false
		end
	end

	self.models[index] = newModel
end

function MoonAnimationModule:_setupParticleEmitters(_, item)
	if not self.model then
		warn("Model not found. Cannot set up particle emitters.")
		return
	end

	-- Check if this emitter is already set up (it might be inside a BasePart)
	if self.particleEmitters[item.Name] then
		return -- Emitter already set up, no need to do anything
	end

	local animationName = self.animationData.Name
	local particleEmittersFolder = game:GetService("ReplicatedStorage").Assets.Animations[animationName]

	if not particleEmittersFolder then
		warn("ParticleEmitters folder not found for animation:", animationName)
		return
	end

	local part = self:_findBasePartInModel(item.Place)
	if not part then
		warn("Part or Bone not found:", item.Place)
		return
	end

	local originalEmitter = particleEmittersFolder:FindFirstChild(item.Name)
	if not originalEmitter then
		warn("ParticleEmitter not found:", item.Name)
		return
	end

	local newEmitter = originalEmitter:Clone()
	newEmitter.Enabled = false -- Start with the emitter disabled

	-- Handle placement based on Attachment parameter
	if item.Attachment then
		-- Place in an attachment (new behavior based on Attachment parameter)
		local attachment = part:FindFirstChild(animationName .. "Attachment")
		if not attachment then
			attachment = Instance.new("Attachment")
			attachment.Name = animationName .. "Attachment"
			attachment.Parent = part
		end
		newEmitter.Parent = attachment
	else
		-- Original behavior - check part type
		if part:IsA("Bone") then
			-- If it's a Bone, attach the ParticleEmitter directly
			newEmitter.Parent = part
		else
			-- For regular parts, place directly in the part (not in attachment)
			newEmitter.Parent = part
		end
	end

	self.particleEmitters[item.Name] = newEmitter
end

function MoonAnimationModule:_setupItems()
	self.particleEmitters = {}
	self.baseParts = {}
	self.models = {}

	-- First, set up all BaseParts and Models
	for index, item in pairs(self.animationData.Items) do
		if item.Type == "BasePart" then
			self:_setupBaseParts(index, item)
		elseif item.Type == "Model" then
			self:_setupModels(index, item)
		elseif item.Type == "Camera" then
			self.cameraMode = item.Mode
			self.cameraPos = index
			self.tweenInitialFrame = item.TweenInitialFrame or false
		end
	end

	-- Then, set up ParticleEmitters
	for index, item in pairs(self.animationData.Items) do
		if item.Type == "ParticleEmitter" then
			self:_setupParticleEmitters(index, item)
		end
	end
end

function MoonAnimationModule:_setupBehaviors()
	for index, behaviorGroup in pairs(self.animationData.Behaviors) do
		self.behaviors[index] = behaviorGroup
	end
end

function MoonAnimationModule:_tweenInitialCameraState()
	local tweenInfo = TweenInfo.new(
		0.7, -- Duration (you can adjust this)
		Enum.EasingStyle.Quad,
		Enum.EasingDirection.In
	)

	local initialTween = TweenService:Create(self.camera, tweenInfo, {
		CFrame = self.initialCameraState.CFrame,
		FieldOfView = self.initialCameraState.FieldOfView,
	})

	initialTween:Play()
	initialTween.Completed:Connect(function()
		initialTween:Destroy()
	end)

	return initialTween
end

function MoonAnimationModule:_setInitialCameraState()
	self.originalCameraType = self.camera.CameraType
	self.camera.CameraType = Enum.CameraType.Scriptable
	local rootPart = self.model:FindFirstChild("HumanoidRootPart")
	if not rootPart then
		warn("HumanoidRootPart not found. Using current camera CFrame as fallback.")
		--rootPart = { CFrame = self.camera.CFrame }
	end

	local initialCFrame = self.behaviors[self.cameraPos].CFrame[0]
	if initialCFrame then
		local cframe = initialCFrame.Values

		if self.cameraMode == "Relative" then
			cframe = rootPart.CFrame * cframe
		end

		self.initialCameraState = {
			CFrame = cframe,
			FieldOfView = self.behaviors[self.cameraPos].FieldOfView[0].Values or 70,
		}
	else
		self.initialCameraState = {
			CFrame = self.camera.CFrame,
			FieldOfView = self.camera.FieldOfView,
		}
	end
end

function MoonAnimationModule:preload()
	AnimationModule.preload(self)
	self:_setupItems()
	self:_setupBehaviors()
end

function MoonAnimationModule:play()
	if not self.isLoaded then
		self:preload()
	end

	if not self.animationTrack then
		warn("Animation track not loaded. Cannot play animation.")
		return
	end

	if self.isExclusive then
		self:_stopAllAnimations()
	end

	-- Disable player movement if there are BaseParts or camera animations
	if self:_shouldDisablePlayerMovement() then
		self:_disablePlayerMovement()
	end

	if self.cameraPos then
		self:_setInitialCameraState()

		if self.tweenInitialFrame then
			local initialTween = self:_tweenInitialCameraState()
			initialTween.Completed:Connect(function()
				task.wait(0.2)
				self:_startAnimation()
			end)
		else
			self.camera.CFrame = self.initialCameraState.CFrame
			self.camera.FieldOfView = self.initialCameraState.FieldOfView
			self:_startAnimation()
		end
	else
		self:_startAnimation()
	end
end

function MoonAnimationModule:_startAnimationOnlyItem(animTrack, cameraReplication)
	self.isPlaying = true
	self:_startBehaviors(animTrack, cameraReplication)
end

function MoonAnimationModule:_startAnimation(_, cameraReplication)
	self.animationTrack:Play(self.fadeTime, self.weight, self.speed)
	self.isPlaying = true

	self:_startBehaviors(nil, cameraReplication)
end

function MoonAnimationModule:playOnlyItems(cameraReplication)
	if not self.isLoaded then
		self:preload()
	end
	if not self.model then
		warn("Model not found. Cannot play items.")
		return
	end

	-- Disconnect existing connection if any
	if self.animationPlayedConnection then
		self.animationPlayedConnection:Disconnect()
	end
	local foundAnimation = false

	-- Set up connection to AnimationPlayed signal
	self.animationPlayedConnection = self.animator.AnimationPlayed:Connect(function(animTrack)
		if not foundAnimation then
			if animTrack.Animation.AnimationId == self.animationId then
				foundAnimation = true
				if self.cameraPos and (cameraReplication == true or cameraReplication == nil) then
					self:_setInitialCameraState()
					self.camera.CFrame = self.initialCameraState.CFrame
					self.camera.FieldOfView = self.initialCameraState.FieldOfView
					self:_startAnimationOnlyItem(animTrack, cameraReplication)
				else
					self:_startAnimationOnlyItem(animTrack, cameraReplication)
				end
			end
		end
	end)

	-- Check if animation is already playing
	if not foundAnimation then
		local animations = self.animator:GetPlayingAnimationTracks()
		for _, animation in pairs(animations) do
			if animation.Animation.AnimationId == self.animationId then
				foundAnimation = true
				if self.cameraPos and (cameraReplication == true or cameraReplication == nil) then
					self:_setInitialCameraState()
					self.camera.CFrame = self.initialCameraState.CFrame
					self.camera.FieldOfView = self.initialCameraState.FieldOfView
					self:_startAnimationOnlyItem(animation, cameraReplication)
				else
					self:_startAnimationOnlyItem(animation, cameraReplication)
				end
			end
		end
	end
end

function MoonAnimationModule:_startBehaviors(animTrack, cameraReplication)
	self.IsPlaying = true
	self.lastProcessedFrame = -1
	self.animationTrack = animTrack or self.animationTrack

	if self.updateConnection then
		self.updateConnection:Disconnect()
	end

	self.updateConnection = RunService.RenderStepped:Connect(function(_)
		if self.IsPlaying and self.animationTrack.IsPlaying then
			local currentTime = self.animationTrack.TimePosition
			local currentFrame = math.floor(currentTime * 60)
			for frame = if self.lastProcessedFrame == 0 then self.lastProcessedFrame else self.lastProcessedFrame + 1, currentFrame do
				self:_handleBehaviors(frame, cameraReplication)
			end
			self.lastProcessedFrame = currentFrame
		else
			self:stop()
		end
	end)
end

function MoonAnimationModule:_handleBasePartBehavior(index, behaviorType, behavior, nextBehavior, frame, nextFrame)
	local part = self.baseParts[index]
	if not part then
		return
	end

	if frame == 0 then
		-- Initialize the BasePart at frame 0
		part.Transparency = 1
		if behaviorType == "CFrame" then
			local initialCFrame = behavior.Values
			if self.cameraMode == "Relative" then
				local rootPart = self.model:FindFirstChild("HumanoidRootPart")
				initialCFrame = rootPart.CFrame * initialCFrame
			end
			part.CFrame = initialCFrame
		elseif behaviorType == "Size" then
			part.Size = Vector3.new(behavior.Values.x, behavior.Values.y, behavior.Values.z)
		elseif behaviorType == "Transparency" then
			part.Transparency = behavior.Values
		end
	end
	-- Handle tweens for subsequent frames
	local startFrame = frame
	local endFrame = nextFrame or self.animationTrack.Length * 60
	local duration = (endFrame - startFrame) / 60

	local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)
	local targetValue

	if behaviorType == "CFrame" then
		targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
		if self.cameraMode == "Relative" then
			local rootPart = self.model:FindFirstChild("HumanoidRootPart")
			targetValue = rootPart.CFrame * targetValue
		end
	elseif behaviorType == "Size" then
		targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
		targetValue = Vector3.new(targetValue.x, targetValue.y, targetValue.z)
	elseif behaviorType == "Transparency" then
		targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
	end

	local newTween = TweenService:Create(part, tweenInfo, { [behaviorType] = targetValue })
	newTween:Play()

	if not self.activeBasePartTweens[index] then
		self.activeBasePartTweens[index] = {}
	end
	table.insert(self.activeBasePartTweens[index], newTween)
	newTween.Completed:Connect(function()
		if self.activeBasePartTweens[index] then
			if self.activeBasePartTweens[index] then
				table.remove(self.activeBasePartTweens[index], table.find(self.activeBasePartTweens[index], newTween))
			end
			newTween:Destroy()
		end
	end)
end

function MoonAnimationModule:_handleParticleEmitterBehavior(index, behaviorType, behavior)
	local emitter
	local itemName = self.animationData.Items[index].Name
	
	-- First check if we have it in our direct mapping
	if self.particleEmitters[itemName] then
		emitter = self.particleEmitters[itemName]
	else
		-- Search for the emitter in BaseParts (including in attachments)
		for _, part in pairs(self.baseParts) do
			-- Search recursively in the part and its descendants (including attachments)
			emitter = part:FindFirstChild(itemName, true)
			if emitter and emitter:IsA("ParticleEmitter") then
				break
			end
		end
		
		-- If still not found, search in the main model
		if not emitter then
			local part = self:_findBasePartInModel(self.animationData.Items[index].Place)
			if part then
				emitter = part:FindFirstChild(itemName, true)
			end
		end
	end

	if emitter and emitter:IsA("ParticleEmitter") then
		if behaviorType == "Emit" then
			emitter:Emit(behavior.Values)
		elseif behaviorType == "Enabled" then
			emitter.Enabled = behavior.Values
		end
	else
		-- Only warn if we actually expect to find this emitter
		if self.animationData.Items[index] and self.animationData.Items[index].Type == "ParticleEmitter" then
			warn("ParticleEmitter not found for index:", index, "name:", itemName)
		end
	end
end

function MoonAnimationModule:_handleCameraBehavior(behaviorType, behavior, nextBehavior, frame, nextFrame)
	if behaviorType == "CFrame" then
		self:_handleCameraCFrame(nextBehavior or behavior, frame, nextFrame)
	elseif behaviorType == "FieldOfView" then
		self:_handleCameraFieldOfView(nextBehavior, behavior, frame, nextFrame)
	end
end

function MoonAnimationModule:_handleModelBehavior(index, behaviorType, behavior, nextBehavior, frame, nextFrame)
	local model = self.models[index]
	if not model then
		return
	end
	if frame == 0 then
		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Transparency = 0
			end
		end
		-- Initialize the Model at frame 0
		if behaviorType == "CFrame" then
			local initialCFrame = behavior.Values
			if self.cameraMode == "Relative" then
				local rootPart = self.model:FindFirstChild("HumanoidRootPart")
				initialCFrame = rootPart.CFrame * initialCFrame
			end
			model.PrimaryPart.CFrame = initialCFrame
		elseif behaviorType == "Transparency" then
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = behavior.Values
				end
			end
		end
	end
	-- Handle tweens for subsequent frames
	local startFrame = frame
	local endFrame = nextFrame or self.animationTrack.Length * 60
	local duration = (endFrame - startFrame) / 60

	local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)

	if behaviorType == "CFrame" then
		local targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
		if self.cameraMode == "Relative" then
			local rootPart = self.model:FindFirstChild("HumanoidRootPart")
			targetValue = rootPart.CFrame * targetValue
		end

		local newTween = TweenService:Create(model.PrimaryPart, tweenInfo, { CFrame = targetValue })
		newTween:Play()

		-- Store the tween
		if not self.activeModelTweens[index] then
			self.activeModelTweens[index] = {}
		end
		table.insert(self.activeModelTweens[index], newTween)
		newTween.Completed:Connect(function()
			if self.activeModelTweens[index] then
				table.remove(self.activeModelTweens[index], table.find(self.activeModelTweens[index], newTween))
			end
			newTween:Destroy()
		end)
	elseif behaviorType == "Transparency" then
		local targetValue = if nextBehavior then nextBehavior.Values else behavior.Values

		for _, part in ipairs(model:GetDescendants()) do
			if part:IsA("BasePart") then
				local newTween = TweenService:Create(part, tweenInfo, { Transparency = targetValue })
				newTween:Play()

				if not self.activeModelTweens[index] then
					self.activeModelTweens[index] = {}
				end
				table.insert(self.activeModelTweens[index], newTween)
				newTween.Completed:Connect(function()
					if self.activeModelTweens[index] then
						table.remove(self.activeModelTweens[index], table.find(self.activeModelTweens[index], newTween))
					end
					newTween:Destroy()
				end)
			end
		end
	end
end

function MoonAnimationModule:_handleCameraCFrame(behavior, frame, nextFrame)
	local rootPart = self.model:FindFirstChild("HumanoidRootPart")
	if not rootPart and self.cameraMode == "Relative" then
		warn("HumanoidRootPart not found. Cannot set relative camera position.")
		return
	end
	local targetCFrame = behavior.Values
	if self.cameraMode == "Relative" then
		targetCFrame = rootPart.CFrame * targetCFrame
	end

	local startFrame = frame
	local endFrame = nextFrame or self.animationTrack.Length * 60 -- Convert length to frames
	local duration = (endFrame - startFrame) / 60
	local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)
	local newTween = TweenService:Create(self.camera, tweenInfo, { CFrame = targetCFrame })
	newTween:Play()
	table.insert(self.activeCameraTweens, {
		tween = newTween,
		startFrame = startFrame,
		endFrame = endFrame,
	})
	newTween.Completed:Connect(function()
		if self.activeCameraTweens then
			table.remove(self.activeCameraTweens, table.find(self.activeCameraTweens, newTween))
		end
		newTween:Destroy()
	end)
end

function MoonAnimationModule:_findNextCFrameKeyframe(currentFrame)
	if not self.cameraPos then
		return nil
	end
	local cameraBehaviors = self.behaviors[self.cameraPos]["CFrame"]
	local nextKeyframe = nil
	for frame, _ in pairs(cameraBehaviors) do
		if frame > currentFrame and (nextKeyframe == nil or frame < nextKeyframe) then
			nextKeyframe = frame
		end
	end
	return nextKeyframe
end

function MoonAnimationModule:_handleCameraFieldOfView(nextBehavior, behavior, frame, nextFrame)
	local startFrame = frame
	local endFrame = nextFrame or self.animationTrack.Length * 60
	local duration = (endFrame - startFrame) / 60 -- Convert frames to seconds

	local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)

	local newTween = TweenService:Create(
		self.camera,
		tweenInfo,
		{ FieldOfView = if nextBehavior then nextBehavior.Values else behavior.Values }
	)
	table.insert(self.activeCameraTweens, {
		tween = newTween,
		startFrame = startFrame,
		endFrame = endFrame,
	})
	newTween:Play()
	newTween.Completed:Connect(function()
		if self.activeCameraTween then
			table.remove(self.activeCameraTweens, table.find(self.activeCameraTweens, newTween))
		end
		newTween:Destroy()
	end)
end

function MoonAnimationModule:_findNextFieldOfViewKeyframe(currentFrame)
	if not self.cameraPos then
		return nil
	end
	local cameraBehaviors = self.behaviors[self.cameraPos]["FieldOfView"]
	local nextKeyframe = nil
	for frame, _ in pairs(cameraBehaviors) do
		if frame > currentFrame and (nextKeyframe == nil or frame < nextKeyframe) then
			nextKeyframe = frame
		end
	end
	return nextKeyframe
end

function MoonAnimationModule:_handleBehaviors(frame, cameraReplication)
	for index, behaviorGroup in pairs(self.behaviors) do
		for behaviorType, behaviors in pairs(behaviorGroup) do
			local behavior = behaviors[frame]
			if behavior then
				if
					self.cameraPos
					and index == self.cameraPos
					and (cameraReplication == true or cameraReplication == nil)
				then
					local nextBehavior
					local nextFrame
					if behaviorType == "CFrame" then
						nextFrame = self:_findNextCFrameKeyframe(frame)
						nextBehavior = behaviors[nextFrame]
					elseif behaviorType == "FieldOfView" then
						nextFrame = self:_findNextFieldOfViewKeyframe(frame)
						nextBehavior = behaviors[nextFrame]
					end
					self:_handleCameraBehavior(behaviorType, behavior, nextBehavior, frame, nextFrame)
				elseif self.baseParts[index] then
					local nextBehavior
					local nextFrame
					nextFrame = self:_findNextKeyframe(behaviorGroup[behaviorType], frame)
					nextBehavior = behaviors[nextFrame]
					self:_handleBasePartBehavior(index, behaviorType, behavior, nextBehavior, frame, nextFrame)
				elseif self.models[index] then
					local nextBehavior
					local nextFrame
					nextFrame = self:_findNextKeyframe(behaviorGroup[behaviorType], frame)
					nextBehavior = behaviors[nextFrame]
					self:_handleModelBehavior(index, behaviorType, behavior, nextBehavior, frame, nextFrame)
				else
					self:_handleParticleEmitterBehavior(index, behaviorType, behavior)
				end
			end
		end
	end
end

function MoonAnimationModule:_findNextKeyframe(behaviors, currentFrame)
	local nextKeyframe = nil
	for frame, _ in pairs(behaviors) do
		if frame > currentFrame and (nextKeyframe == nil or frame < nextKeyframe) then
			nextKeyframe = frame
		end
	end
	return nextKeyframe
end

function MoonAnimationModule:stop()
	AnimationModule.stop(self)

	self:_enablePlayerMovement()

	if self.updateConnection then
		self.updateConnection:Disconnect()
		self.updateConnection = nil
	end

	for _, tweens in pairs(self.activeModelTweens) do
		for _, tween in ipairs(tweens) do
			tween:Destroy()
		end
	end
	self.activeModelTweens = {}

	for _, model in pairs(self.models) do
		if model ~= self.model then
			for _, part in ipairs(model:GetDescendants()) do
				if part:IsA("BasePart") then
					part.Transparency = 1
					part.CanCollide = false
					part.CanTouch = false
					part.CanQuery = false
				end
			end
		end
	end

	for _, tweenInfo in ipairs(self.activeCameraTweens) do
		tweenInfo.tween:Cancel()
	end
	self.activeCameraTweens = {}

	for _, tweens in pairs(self.activeBasePartTweens) do
		for _, tween in ipairs(tweens) do
			tween:Cancel()
		end
	end
	self.activeBasePartTweens = {}
	if self.initialCameraState then
		self.camera.FieldOfView = 70
	end

	if self.originalCameraType then
		self.camera.CameraType = self.originalCameraType
	end

	for _, emitter in ipairs(self.particleEmitters) do
		emitter.Enabled = false
	end

	for _, part in pairs(self.baseParts) do
		part.Transparency = 1
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
	end

	self.lastProcessedFrame = -1
end

function MoonAnimationModule:destroy()
	self:stop()
	AnimationModule.destroy(self)

	-- Clean up particle emitters and their attachments
	for _, emitter in pairs(self.particleEmitters) do
		if emitter and emitter:IsA("ParticleEmitter") then
			local parent = emitter.Parent
			emitter:Destroy()
			
			-- If the parent is an attachment we created and it's now empty, destroy it
			if parent and parent:IsA("Attachment") then
				local animationName = self.animationData.Name
				if parent.Name == animationName .. "Attachment" and #parent:GetChildren() == 0 then
					parent:Destroy()
				end
			end
		end
	end
	
	-- Clean up base parts
	for _, part in pairs(self.baseParts) do
		if part and part:IsA("BasePart") then
			part:Destroy()
		end
	end

	-- Clean up models
	for _, model in pairs(self.models) do
		if model and model:IsA("Model") then
			model:Destroy()
		end
	end
	
	-- Clear all references
	self.models = {}
	self.particleEmitters = {}
	self.baseParts = {}
	self.behaviors = {}
end

return MoonAnimationModule
