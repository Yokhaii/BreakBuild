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
	self.beams = {}
	self.trails = {}
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
	self._createdAttachments = {}
	self.cameraPos = nil
	self.originalCameraType = nil
	self.playerMovementDisabled = false
	self.originalWalkSpeed = 0
	self.originalJumpPower = 0
	self.tweenInitialFrame = false
	self.rigMovementPos = nil
	self.rigMovementMode = "Relative"
	self.rigMovementTpBack = false
	self.activeRigMovementTweens = {}
	self.rigMovementInitialCFrame = nil

	return self
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
	self:_registerEmittersInPart(newPart)
end

-- Register ParticleEmitters found inside a part by matching against BundledInPart items
function MoonAnimationModule:_registerEmittersInPart(part)
	for itemIndex, itemData in pairs(self.animationData.Items) do
		if itemData.Type == "ParticleEmitter" and itemData.BundledInPart == part.Name
			and not self.particleEmitters[itemIndex] then
			local emitter = part:FindFirstChild(itemData.Name, true)
			if emitter and emitter:IsA("ParticleEmitter") then
				emitter.Enabled = false
				self.particleEmitters[itemIndex] = emitter
			else
				warn("Bundled emitter not found inside part:", part.Name, "->", itemData.Name)
			end
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

function MoonAnimationModule:_setupParticleEmitters(index, item)
	-- Already registered by _registerEmittersInPart when the BasePart was set up
	if self.particleEmitters[index] then
		return
	end

	-- Bundled inside a BasePart item — will be registered when that part is set up
	if item.BundledInPart then
		return
	end

	if not self.model then
		warn("Model not found. Cannot set up particle emitters.")
		return
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

	-- Handle placement based on Attachment parameter
	if item.Attachment then
		-- Initialize attachment tracking map if needed
		if not self._attachmentAssetMap then
			self._attachmentAssetMap = {}
		end

		-- Check for stored Attachment in assets using AttachmentAsset field
		local attachmentAssetName = item.AttachmentAsset
		if attachmentAssetName then
			-- Check if we already created this Attachment
			local existingAttachment = self._attachmentAssetMap[attachmentAssetName]
			if existingAttachment then
				-- Attachment already exists, find the emitter inside it
				local emitterInAttachment = existingAttachment:FindFirstChild(item.Name)
				if emitterInAttachment then
					emitterInAttachment.Enabled = false
					self.particleEmitters[index] = emitterInAttachment
					return -- Exit early, setup complete
				end
			end

			-- Try to find the stored Attachment asset
			local assetAttachment = particleEmittersFolder:FindFirstChild(attachmentAssetName)
			if assetAttachment and assetAttachment:IsA("Attachment") then
				-- Clone stored Attachment (preserves Position, CFrame, Axis, etc.)
				local attachmentClone = assetAttachment:Clone()
				attachmentClone.Name = animationName .. "_" .. attachmentAssetName
				attachmentClone.Parent = part

				-- Track this Attachment
				self._attachmentAssetMap[attachmentAssetName] = attachmentClone
				table.insert(self._createdAttachments, attachmentClone)

				-- Disable all emitters inside the Attachment
				for _, child in ipairs(attachmentClone:GetChildren()) do
					if child:IsA("ParticleEmitter") then
						child.Enabled = false
					end
				end

				-- Find the specific emitter for this item
				local emitterInAttachment = attachmentClone:FindFirstChild(item.Name)
				if emitterInAttachment then
					self.particleEmitters[index] = emitterInAttachment
					return -- Exit early, setup complete
				end
			end
		end

		-- BACKWARD COMPATIBILITY: Fall back to old behavior
		-- (for animations converted before this update)
		local originalEmitter = particleEmittersFolder:FindFirstChild(item.Name)
		if not originalEmitter then
			warn("ParticleEmitter not found:", item.Name)
			return
		end

		local newEmitter = originalEmitter:Clone()
		newEmitter.Enabled = false

		local attachment = part:FindFirstChild(animationName .. "Attachment")
		if not attachment then
			attachment = Instance.new("Attachment")
			attachment.Name = animationName .. "Attachment"
			attachment.Parent = part
			table.insert(self._createdAttachments, attachment)
		end
		newEmitter.Parent = attachment
		self.particleEmitters[index] = newEmitter
	else
		-- Original behavior - emitter not in attachment
		local originalEmitter = particleEmittersFolder:FindFirstChild(item.Name)
		if not originalEmitter then
			warn("ParticleEmitter not found:", item.Name)
			return
		end

		local newEmitter = originalEmitter:Clone()
		newEmitter.Enabled = false

		if part:IsA("Bone") then
			-- If it's a Bone, attach the ParticleEmitter directly
			newEmitter.Parent = part
		else
			-- For regular parts, place directly in the part (not in attachment)
			newEmitter.Parent = part
		end

		self.particleEmitters[index] = newEmitter
	end
end

function MoonAnimationModule:_setupBeams(index, item)
	if not self.model then
		warn("Model not found. Cannot set up beams.")
		return
	end

	local animationName = self.animationData.Name
	local assetsFolder = game:GetService("ReplicatedStorage").Assets.Animations[animationName]

	if not assetsFolder then
		warn("Assets folder not found for animation:", animationName)
		return
	end

	local part = self:_findBasePartInModel(item.Place)
	if not part then
		warn("Part not found for Beam placement:", item.Place)
		return
	end

	-- Check if beam already exists in the part
	local existingBeam = part:FindFirstChild(item.Name)
	if existingBeam and existingBeam:IsA("Beam") then
		self.beams[index] = existingBeam
		return
	end

	local assetBeam = assetsFolder:FindFirstChild(item.Name)
	if not assetBeam or not assetBeam:IsA("Beam") then
		warn("Beam asset not found:", item.Name)
		return
	end

	-- Initialize attachment tracking map if needed
	if not self._attachmentAssetMap then
		self._attachmentAssetMap = {}
	end

	-- Clone the beam
	local newBeam = assetBeam:Clone()
	newBeam.Enabled = false
	newBeam.Parent = part

	-- Setup Attachment0
	local attachment0AssetName = assetBeam:GetAttribute("Attachment0Asset")
	local attachment0PartName = assetBeam:GetAttribute("Attachment0Part")
	if attachment0AssetName then
		local existingAttachment0 = self._attachmentAssetMap[attachment0AssetName]
		if existingAttachment0 then
			newBeam.Attachment0 = existingAttachment0
		else
			local assetAttachment0 = assetsFolder:FindFirstChild(attachment0AssetName)
			if assetAttachment0 and assetAttachment0:IsA("Attachment") then
				local targetPart0 = self:_findBasePartInModel(attachment0PartName)
				if targetPart0 then
					local attachmentClone0 = assetAttachment0:Clone()
					attachmentClone0.Name = animationName .. "_" .. attachment0AssetName
					attachmentClone0.Parent = targetPart0
					self._attachmentAssetMap[attachment0AssetName] = attachmentClone0
					table.insert(self._createdAttachments, attachmentClone0)
					newBeam.Attachment0 = attachmentClone0
				end
			end
		end
	end

	-- Setup Attachment1
	local attachment1AssetName = assetBeam:GetAttribute("Attachment1Asset")
	local attachment1PartName = assetBeam:GetAttribute("Attachment1Part")
	if attachment1AssetName then
		local existingAttachment1 = self._attachmentAssetMap[attachment1AssetName]
		if existingAttachment1 then
			newBeam.Attachment1 = existingAttachment1
		else
			local assetAttachment1 = assetsFolder:FindFirstChild(attachment1AssetName)
			if assetAttachment1 and assetAttachment1:IsA("Attachment") then
				local targetPart1 = self:_findBasePartInModel(attachment1PartName)
				if targetPart1 then
					local attachmentClone1 = assetAttachment1:Clone()
					attachmentClone1.Name = animationName .. "_" .. attachment1AssetName
					attachmentClone1.Parent = targetPart1
					self._attachmentAssetMap[attachment1AssetName] = attachmentClone1
					table.insert(self._createdAttachments, attachmentClone1)
					newBeam.Attachment1 = attachmentClone1
				end
			end
		end
	end

	self.beams[index] = newBeam
end

function MoonAnimationModule:_setupTrails(index, item)
	if not self.model then
		warn("Model not found. Cannot set up trails.")
		return
	end

	local animationName = self.animationData.Name
	local assetsFolder = game:GetService("ReplicatedStorage").Assets.Animations[animationName]

	if not assetsFolder then
		warn("Assets folder not found for animation:", animationName)
		return
	end

	local part = self:_findBasePartInModel(item.Place)
	if not part then
		warn("Part not found for Trail placement:", item.Place)
		return
	end

	local assetTrail = assetsFolder:FindFirstChild(item.Name)
	if not assetTrail or not assetTrail:IsA("Trail") then
		warn("Trail asset not found:", item.Name)
		return
	end

	local newTrail = assetTrail:Clone()
	newTrail.Enabled = false
	newTrail.Parent = part

	if not self._attachmentAssetMap then
		self._attachmentAssetMap = {}
	end

	local attachment0AssetName = assetTrail:GetAttribute("Attachment0Asset")
	local attachment0PartName = assetTrail:GetAttribute("Attachment0Part")
	if attachment0AssetName then
		local existingAttachment0 = self._attachmentAssetMap[attachment0AssetName]
		if existingAttachment0 then
			newTrail.Attachment0 = existingAttachment0
		else
			local assetAttachment0 = assetsFolder:FindFirstChild(attachment0AssetName)
			if assetAttachment0 and assetAttachment0:IsA("Attachment") then
				local targetPart0 = self:_findBasePartInModel(attachment0PartName)
				if targetPart0 then
					local attachmentClone0 = assetAttachment0:Clone()
					attachmentClone0.Name = animationName .. "_" .. attachment0AssetName
					attachmentClone0.Parent = targetPart0
					self._attachmentAssetMap[attachment0AssetName] = attachmentClone0
					table.insert(self._createdAttachments, attachmentClone0)
					newTrail.Attachment0 = attachmentClone0
				end
			end
		end
	end

	local attachment1AssetName = assetTrail:GetAttribute("Attachment1Asset")
	local attachment1PartName = assetTrail:GetAttribute("Attachment1Part")
	if attachment1AssetName then
		local existingAttachment1 = self._attachmentAssetMap[attachment1AssetName]
		if existingAttachment1 then
			newTrail.Attachment1 = existingAttachment1
		else
			local assetAttachment1 = assetsFolder:FindFirstChild(attachment1AssetName)
			if assetAttachment1 and assetAttachment1:IsA("Attachment") then
				local targetPart1 = self:_findBasePartInModel(attachment1PartName)
				if targetPart1 then
					local attachmentClone1 = assetAttachment1:Clone()
					attachmentClone1.Name = animationName .. "_" .. attachment1AssetName
					attachmentClone1.Parent = targetPart1
					self._attachmentAssetMap[attachment1AssetName] = attachmentClone1
					table.insert(self._createdAttachments, attachmentClone1)
					newTrail.Attachment1 = attachmentClone1
				end
			end
		end
	end

	self.trails[index] = newTrail
end

function MoonAnimationModule:_getRootPart()
	return self.model:FindFirstChild("HumanoidRootPart") or self.model.PrimaryPart
end

function MoonAnimationModule:_getModelReferenceCFrame()
	if self.model.PrimaryPart then
		return self.model.PrimaryPart.CFrame
	end
	for _, child in ipairs(self.model:GetDescendants()) do
		if child:IsA("BasePart") then
			return child.CFrame
		end
	end
	return CFrame.new()
end

function MoonAnimationModule:_setupItems()
	self.particleEmitters = {}
	self.baseParts = {}
	self.basePartModes = {}
	self.models = {}
	self.beams = {}
	self.trails = {}

	-- First, set up all BaseParts and Models
	for index, item in pairs(self.animationData.Items) do
		if item.Type == "BasePart" then
			self:_setupBaseParts(index, item)
			self.basePartModes[index] = item.Mode or "Free"
		elseif item.Type == "Model" then
			self:_setupModels(index, item)
		elseif item.Type == "Camera" then
			self.cameraMode = item.Mode
			self.cameraPos = index
			self.tweenInitialFrame = item.TweenInitialFrame or false
		elseif item.Type == "RigMovement" then
			self.rigMovementPos = index
			self.rigMovementMode = item.Mode or "Relative"
			self.rigMovementTpBack = item.TpBack or false
		end
	end

	-- Then, set up ParticleEmitters and Beams
	for index, item in pairs(self.animationData.Items) do
		if item.Type == "ParticleEmitter" then
			self:_setupParticleEmitters(index, item)
		elseif item.Type == "Beam" then
			self:_setupBeams(index, item)
		elseif item.Type == "Trail" then
			self:_setupTrails(index, item)
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
	-- If the camera is already Scriptable, an external system (e.g. ShowcaseMode)
	-- owns CameraType. Don't capture it — stop() would restore to Scriptable
	-- instead of Custom, leaving the camera stuck.
	if self.camera.CameraType ~= Enum.CameraType.Scriptable then
		self.originalCameraType = self.camera.CameraType
		self.camera.CameraType = Enum.CameraType.Scriptable
	else
		self.originalCameraType = nil
	end
	local rootPart = self:_getRootPart()
	if not rootPart then
		warn("Root part not found. Using current camera CFrame as fallback.")
	end

	local cameraBehaviors = self.behaviors[self.cameraPos]
	local cframeBehaviors = cameraBehaviors and cameraBehaviors.CFrame
	local fovBehaviors = cameraBehaviors and cameraBehaviors.FieldOfView

	local initialCFrame = cframeBehaviors and cframeBehaviors[0]
	local initialFov = fovBehaviors and fovBehaviors[0]

	if initialCFrame then
		local cframe = initialCFrame.Values

		if self.cameraMode == "Relative" and rootPart then
			cframe = rootPart.CFrame * cframe
		end

		self.initialCameraState = {
			CFrame = cframe,
			FieldOfView = initialFov and initialFov.Values or self.camera.FieldOfView,
		}
	else
		self.initialCameraState = {
			CFrame = self.camera.CFrame,
			FieldOfView = initialFov and initialFov.Values or self.camera.FieldOfView,
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
	-- Capture HRP CFrame before animation starts for rig movement reference
	if self.rigMovementPos and not self.rigMovementInitialCFrame then
		local rootPart = self:_getRootPart()
		if rootPart then
			self.rigMovementInitialCFrame = rootPart.CFrame
		end
	end

	self.animationTrack:Play(0, self.weight, self.speed)
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
	if not self:_getRootPart() then
		warn("Root part not found. Model may not be streamed. Skipping items.")
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
			if self.cameraMode == "Relative" and self.model.PrimaryPart then
				initialCFrame = self.model.PrimaryPart.CFrame * initialCFrame
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

	local targetValue

	if behaviorType == "CFrame" then
		targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
		if self.cameraMode == "Relative" and self.model.PrimaryPart then
			targetValue = self.model.PrimaryPart.CFrame * targetValue
		end
	elseif behaviorType == "Size" then
		targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
		targetValue = Vector3.new(targetValue.x, targetValue.y, targetValue.z)
	elseif behaviorType == "Transparency" then
		targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
	end

	if behavior.Easing.Style == "Constant" then
		task.delay(duration, function()
			if part and part.Parent then
				part[behaviorType] = targetValue
			end
		end)
		return
	end

	local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)
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
	-- Use index directly for secure lookup (avoids name collisions across animations)
	local emitter = self.particleEmitters[index]

	if emitter and emitter:IsA("ParticleEmitter") then
		if behaviorType == "Emit" then
			emitter:Emit(behavior.Values)
		elseif behaviorType == "Enabled" then
			emitter.Enabled = behavior.Values
		end
	else
		-- Only warn if we actually expect to find this emitter
		if self.animationData.Items[index] and self.animationData.Items[index].Type == "ParticleEmitter" then
			warn("ParticleEmitter not found for index:", index, "name:", self.animationData.Items[index].Name)
		end
	end
end

function MoonAnimationModule:_handleBeamBehavior(index, behaviorType, behavior)
	local beam = self.beams[index]

	if beam and beam:IsA("Beam") then
		if behaviorType == "Enabled" then
			beam.Enabled = behavior.Values
		end
	else
		if self.animationData.Items[index] and self.animationData.Items[index].Type == "Beam" then
			warn("Beam not found for index:", index, "name:", self.animationData.Items[index].Name)
		end
	end
end

function MoonAnimationModule:_handleTrailBehavior(index, behaviorType, behavior)
	local trail = self.trails[index]

	if trail and trail:IsA("Trail") then
		if behaviorType == "Enabled" then
			trail.Enabled = behavior.Values
		end
	else
		if self.animationData.Items[index] and self.animationData.Items[index].Type == "Trail" then
			warn("Trail not found for index:", index, "name:", self.animationData.Items[index].Name)
		end
	end
end

function MoonAnimationModule:_handleCameraBehavior(behaviorType, behavior, nextBehavior, frame, nextFrame)
	if behaviorType == "CFrame" then
		self:_handleCameraCFrame(nextBehavior or behavior, behavior.Easing, frame, nextFrame)
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
			if self.cameraMode == "Relative" and self.model.PrimaryPart then
				initialCFrame = self.model.PrimaryPart.CFrame * initialCFrame
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

	if behaviorType == "CFrame" then
		local targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
		if self.cameraMode == "Relative" and self.model.PrimaryPart then
			targetValue = self.model.PrimaryPart.CFrame * targetValue
		end

		if behavior.Easing.Style == "Constant" then
			task.delay(duration, function()
				if model and model.PrimaryPart and model.Parent then
					model.PrimaryPart.CFrame = targetValue
				end
			end)
			return
		end

		local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)
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

		local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)
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

function MoonAnimationModule:_handleRigMovementBehavior(behaviorType, behavior, nextBehavior, frame, nextFrame)
	if behaviorType ~= "CFrame" then
		return
	end

	local rootPart = self:_getRootPart()
	if not rootPart then
		warn("Root part not found. Cannot apply rig movement.")
		return
	end

	-- Store initial CFrame on first frame for relative calculations
	if not self.rigMovementInitialCFrame then
		self.rigMovementInitialCFrame = rootPart.CFrame
	end

	if frame == 0 then
		local initialCFrame = behavior.Values
		if self.rigMovementMode == "Relative" then
			initialCFrame = self.rigMovementInitialCFrame * initialCFrame
		end
		rootPart.CFrame = initialCFrame
		return
	end

	local startFrame = frame
	local endFrame = nextFrame or self.animationTrack.Length * 60
	local duration = (endFrame - startFrame) / 60

	local targetCFrame = if nextBehavior then nextBehavior.Values else behavior.Values
	if self.rigMovementMode == "Relative" then
		targetCFrame = self.rigMovementInitialCFrame * targetCFrame
	end

	if behavior.Easing.Style == "Constant" then
		task.delay(duration, function()
			if rootPart and rootPart.Parent then
				rootPart.CFrame = targetCFrame
			end
		end)
		return
	end

	local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)
	local newTween = TweenService:Create(rootPart, tweenInfo, { CFrame = targetCFrame })
	newTween:Play()

	table.insert(self.activeRigMovementTweens, newTween)
	newTween.Completed:Connect(function()
		if self.activeRigMovementTweens then
			local tweenIndex = table.find(self.activeRigMovementTweens, newTween)
			if tweenIndex then
				table.remove(self.activeRigMovementTweens, tweenIndex)
			end
			newTween:Destroy()
		end
	end)
end

function MoonAnimationModule:_handleCameraCFrame(behavior, easing, frame, nextFrame)
	local rootPart = self:_getRootPart()
	if not rootPart and self.cameraMode == "Relative" then
		warn("Root part not found. Cannot set relative camera position.")
		return
	end
	local targetCFrame = behavior.Values
	if self.cameraMode == "Relative" then
		targetCFrame = rootPart.CFrame * targetCFrame
	end

	local startFrame = frame
	local endFrame = nextFrame or self.animationTrack.Length * 60
	local duration = (endFrame - startFrame) / 60

	if easing.Style == "Constant" then
		task.delay(duration, function()
			if self.camera then
				self.camera.CFrame = targetCFrame
			end
		end)
		return
	end

	local tweenInfo = TweenInfo.new(duration, easing.Style, easing.Direction)
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
				elseif self.rigMovementPos and index == self.rigMovementPos then
					local nextBehavior
					local nextFrame
					nextFrame = self:_findNextKeyframe(behaviorGroup[behaviorType], frame)
					nextBehavior = behaviors[nextFrame]
					self:_handleRigMovementBehavior(behaviorType, behavior, nextBehavior, frame, nextFrame)
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
				elseif self.beams[index] then
					self:_handleBeamBehavior(index, behaviorType, behavior)
				elseif self.trails[index] then
					self:_handleTrailBehavior(index, behaviorType, behavior)
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

	for _, tween in ipairs(self.activeRigMovementTweens) do
		tween:Cancel()
		tween:Destroy()
	end
	self.activeRigMovementTweens = {}

	if self.rigMovementTpBack and self.rigMovementInitialCFrame then
		local rootPart = self:_getRootPart()
		if rootPart then
			rootPart.CFrame = self.rigMovementInitialCFrame
		end
	end
	self.rigMovementInitialCFrame = nil

	if self.initialCameraState then
		self.camera.FieldOfView = self.initialCameraState.FieldOfView or 70
	end

	if self.originalCameraType then
		self.camera.CameraType = self.originalCameraType
	end

	for _, emitter in pairs(self.particleEmitters) do
		if emitter and emitter:IsA("ParticleEmitter") then
			emitter.Enabled = false
		end
	end

	for _, beam in pairs(self.beams) do
		if beam and beam:IsA("Beam") then
			beam.Enabled = false
		end
	end

	for _, trail in pairs(self.trails) do
		if trail and trail:IsA("Trail") then
			trail.Enabled = false
		end
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

	-- Clean up created attachments first (includes attachments with emitters inside)
	if self._createdAttachments then
		for _, attachment in pairs(self._createdAttachments) do
			if attachment and attachment:IsA("Attachment") and attachment.Parent then
				attachment:Destroy()
			end
		end
		self._createdAttachments = {}
	end

	-- Clean up particle emitters and their attachments (for backward compatibility emitters)
	for _, emitter in pairs(self.particleEmitters) do
		if emitter and emitter:IsA("ParticleEmitter") and emitter.Parent then
			local parent = emitter.Parent
			emitter:Destroy()

			-- If the parent is an attachment we created and it's now empty, destroy it
			if parent and parent:IsA("Attachment") and parent.Parent then
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

	-- Clean up beams
	for _, beam in pairs(self.beams) do
		if beam and beam:IsA("Beam") then
			beam:Destroy()
		end
	end

	-- Clean up trails
	for _, trail in pairs(self.trails) do
		if trail and trail:IsA("Trail") then
			trail:Destroy()
		end
	end

	-- Clear all references
	self.models = {}
	self.particleEmitters = {}
	self.baseParts = {}
	self.beams = {}
	self.trails = {}
	self.behaviors = {}
	self._attachmentAssetMap = {}
end

return MoonAnimationModule
