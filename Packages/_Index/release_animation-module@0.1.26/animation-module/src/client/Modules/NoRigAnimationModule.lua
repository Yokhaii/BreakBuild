-- Updated NoRigAnimationModule - loads all assets into target model
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)

local NoRigAnimationModule = {}
NoRigAnimationModule.__index = NoRigAnimationModule

function NoRigAnimationModule.new(animationId, animationData, target)
	local self = setmetatable({}, NoRigAnimationModule)

	self.animationId = animationId
	self.animationData = animationData
	self.isLoaded = false
	self.isPlaying = false
	self.priority = animationData.Priority or "Action"
	self.weight = animationData.Weight or 1
	self.isExclusive = animationData.isExclusive or false
	self.speed = animationData.Speed or 1
	self.fadeTime = animationData.FadeTime or 0.1
	self.loop = animationData.Loop or false
	self.finished = Signal.new()

	-- Store the target (Model or Part) directly
	self.target = target

	-- Store original properties to restore them later
	self.originalProperties = {}

	-- Mappings for parts and features in the animation
	self.partMappings = {} -- For BaseParts in the animation that map to parts in the target
	self.modelMappings = {} -- For Models in the animation that map to models in the target
	self.particleEmitters = {} -- For ParticleEmitters in the animation
	self.createdAssets = {} -- NEW: For tracking assets we created (for cleanup)

	self.behaviors = {}
	self.updateConnection = nil
	self.lastProcessedFrame = -1
	self.camera = workspace.CurrentCamera
	self.initialCameraState = nil
	self.currentCameraTween = nil
	self.cameraMode = animationData.Mode or "Relative"
	self.activeCameraTweens = {}
	self.activeTweens = {}
	self.cameraPos = nil
	self.originalCameraType = nil
	self.frameRate = 60
	self.totalFrames = 0
	self.elapsedTime = 0

	return self
end

-- Get the target's CFrame (root of model or the part itself)
function NoRigAnimationModule:_getTargetCFrame()
    if self.cameraPos and self.animationData.Items[1] and self.animationData.Items[1].Type == "Camera" then
        return self.camera.CFrame
    end
    
    if typeof(self.target) == "Instance" then
        if self.target:IsA("BasePart") then
            return self.target.CFrame
        elseif self.target:IsA("Model") and self.target.PrimaryPart then
            return self.target.PrimaryPart.CFrame
        else
            for _, child in ipairs(self.target:GetDescendants()) do
                if child:IsA("BasePart") then
                    return child.CFrame
                end
            end
        end
    elseif typeof(self.target) == "CFrame" then
        return self.target
    elseif typeof(self.target) == "Vector3" then
        return CFrame.new(self.target)
    end

    if self.cameraPos then
        return self.camera.CFrame
    end
    
    return CFrame.new(0, 0, 0)
end

-- Store the original properties of parts to restore later
function NoRigAnimationModule:_storeOriginalProperties()
	if typeof(self.target) ~= "Instance" then
		return
	end

	local parts = {}

	if self.target:IsA("BasePart") then
		parts = { self.target }
	elseif self.target:IsA("Model") then
		for _, part in ipairs(self.target:GetDescendants()) do
			if part:IsA("BasePart") then
				table.insert(parts, part)
			end
		end
	end

	for _, part in ipairs(parts) do
		self.originalProperties[part] = {
			CFrame = part.CFrame,
			Size = part.Size,
			Transparency = part.Transparency,
		}
	end

	if self.cameraPos then
		self.originalProperties["camera"] = {
			CFrame = self.camera.CFrame,
			FieldOfView = self.camera.FieldOfView,
			CameraType = self.camera.CameraType,
		}
	end
end

-- Find a specific part in the target model by name
function NoRigAnimationModule:_findPartInTarget(partName)
    if not self.target then
        return nil
    end

    if self.target:IsA("BasePart") and self.target.Name == partName then
        return self.target
    end

    if self.target:IsA("Model") then
        local function recursiveSearch(parent)
            for _, child in ipairs(parent:GetChildren()) do
                if child.Name == partName and child:IsA("BasePart") then
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

        return recursiveSearch(self.target)
    end

    return nil
end

-- Find a specific model in the target model by name
function NoRigAnimationModule:_findModelInTarget(modelName)
	if not self.target then
		return nil
	end

	if self.target:IsA("Model") then
		if self.target.Name == modelName then
			return self.target
		end

		local function recursiveSearch(parent)
			for _, child in ipairs(parent:GetChildren()) do
				if child.Name == modelName and child:IsA("Model") then
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

		return recursiveSearch(self.target)
	end

	return nil
end

-- NEW: Setup BaseParts from assets into the target model
function NoRigAnimationModule:_setupBaseParts(index, item)
	if not self.target or not self.target:IsA("Model") then
		warn("Target must be a Model to setup BaseParts")
		return
	end

	-- First, try to find existing part in target
	local existingPart = self:_findPartInTarget(item.Name)
	if existingPart then
		self.partMappings[index] = existingPart
		return
	end

	-- If not found, load from assets
	local animationName = self.animationData.Name
	local assetsFolder = ReplicatedStorage.Assets.Animations[animationName]

	if not assetsFolder then
		warn("Assets folder not found for animation:", animationName)
		return
	end

	local assetPart = assetsFolder:FindFirstChild(item.Name)
	if not assetPart then
		warn("BasePart asset not found:", item.Name)
		return
	end

	-- Clone the asset part into the target model
	local newPart = assetPart:Clone()
	newPart.Anchored = true
	newPart.CanCollide = false
	newPart.Transparency = 1 -- Start invisible
	newPart.Parent = self.target

	-- Store for cleanup
	table.insert(self.createdAssets, newPart)
	self.partMappings[index] = newPart
end

-- NEW: Setup Models from assets into the target model
function NoRigAnimationModule:_setupModels(index, item)
	if not self.target or not self.target:IsA("Model") then
		warn("Target must be a Model to setup Models")
		return
	end

	-- First, try to find existing model in target
	local existingModel = self:_findModelInTarget(item.Name)
	if existingModel then
		self.modelMappings[index] = existingModel
		-- Ensure it has a PrimaryPart
		if not existingModel.PrimaryPart then
			for _, part in ipairs(existingModel:GetDescendants()) do
				if part:IsA("BasePart") then
					existingModel.PrimaryPart = part
					break
				end
			end
		end
		return
	end

	-- If not found, load from assets
	local animationName = self.animationData.Name
	local assetsFolder = ReplicatedStorage.Assets.Animations[animationName]

	if not assetsFolder then
		warn("Assets folder not found for animation:", animationName)
		return
	end

	local assetModel = assetsFolder:FindFirstChild(item.Name)
	if not assetModel then
		warn("Model asset not found:", item.Name)
		return
	end

	-- Clone the asset model into the target model
	local newModel = assetModel:Clone()
	newModel.Parent = self.target

	-- Set up PrimaryPart if needed
	if not newModel.PrimaryPart then
		for _, part in ipairs(newModel:GetDescendants()) do
			if part:IsA("BasePart") then
				newModel.PrimaryPart = part
				break
			end
		end
	end

	-- Store for cleanup
	table.insert(self.createdAssets, newModel)
	self.modelMappings[index] = newModel
end

function NoRigAnimationModule:_setupParticleEmitters(index, item)
	if not self.target or not self.target:IsA("Model") then
		warn("Target must be a Model to setup ParticleEmitters")
		return
	end

	local partName = item.Place
	local part = self:_findPartInTarget(partName)
	

	if not part then
		warn("Part not found for ParticleEmitter placement:", partName)
		return
	end

	-- Check if emitter already exists in the part (or its attachments)
	local existingEmitter = part:FindFirstChild(item.Name, true)
	if existingEmitter and existingEmitter:IsA("ParticleEmitter") then
		-- Store original enabled state to restore later
		self.originalProperties[existingEmitter] = {
			Enabled = existingEmitter.Enabled,
		}
		self.particleEmitters[index] = existingEmitter
		return
	end

	-- Load from assets
	local animationName = self.animationData.Name
	local assetsFolder = ReplicatedStorage.Assets.Animations[animationName]

	if not assetsFolder then
		warn("Assets folder not found for animation:", animationName)
		return
	end

	local assetEmitter = assetsFolder:FindFirstChild(item.Name)
	if not assetEmitter then
		warn("ParticleEmitter asset not found:", item.Name)
		return
	end

	-- Clone the emitter
	local newEmitter = assetEmitter:Clone()
	newEmitter.Enabled = false -- Start disabled

	-- Check if it should be placed in an attachment
	if item.Attachment then
		-- Create or find an attachment
		local attachment = part:FindFirstChild(animationName .. "Attachment")
		if not attachment then
			attachment = Instance.new("Attachment")
			attachment.Name = animationName .. "Attachment"
			attachment.Parent = part
			table.insert(self.createdAssets, attachment)
		end

		newEmitter.Parent = attachment
	else
		-- Place directly in the part
		newEmitter.Parent = part
	end

	table.insert(self.createdAssets, newEmitter)
	self.particleEmitters[index] = newEmitter
end

-- UPDATED: Find parts and setup mappings - NOW LOADS ALL ASSETS INTO TARGET MODEL
function NoRigAnimationModule:_findPartsInTarget()
	if not self.target or typeof(self.target) ~= "Instance" then
		return
	end

	-- Store original properties before modifying anything
	self:_storeOriginalProperties()

	-- Map item names to target parts/models, loading from assets if needed
	for index, item in pairs(self.animationData.Items) do
		if item.Type == "BasePart" then
			self:_setupBaseParts(index, item)
		elseif item.Type == "Model" then
			self:_setupModels(index, item)
		elseif item.Type == "Camera" then
			self.cameraMode = item.Mode or self.cameraMode
			self.cameraPos = index
			self.tweenInitialFrame = item.TweenInitialFrame or false
		elseif item.Type == "ParticleEmitter" then
			self:_setupParticleEmitters(index, item)
		end
	end
end

function NoRigAnimationModule:preload()
	self:_findPartsInTarget()
	self:_setupBehaviors()
	self.isLoaded = true
end

function NoRigAnimationModule:_setupBehaviors()
	self.behaviors = {}
	for behaviorIndex, behavior in pairs(self.animationData.Behaviors) do
		behaviorIndex = tonumber(behaviorIndex)
		self.behaviors[behaviorIndex] = behavior
	end
	self.totalFrames = self:_calculateTotalFrames()
end

function NoRigAnimationModule:_calculateTotalFrames()
	local maxFrame = 0
	for _, behaviorGroup in pairs(self.behaviors) do
		for _, behaviors in pairs(behaviorGroup) do
			for frame, _ in pairs(behaviors) do
				if tonumber(frame) > maxFrame then
					maxFrame = tonumber(frame)
				end
			end
		end
	end
	return maxFrame
end

function NoRigAnimationModule:_setInitialCameraState()
	self.originalCameraType = self.camera.CameraType
	self.camera.CameraType = Enum.CameraType.Scriptable

	local initialCFrame = self.behaviors[self.cameraPos].CFrame[0]
	if initialCFrame then
		local cframe = initialCFrame.Values

		if self.cameraMode == "Relative" then
			cframe = self:_getTargetCFrame() * cframe
		end

		self.initialCameraState = {
			CFrame = cframe,
			FieldOfView = self.behaviors[self.cameraPos].FieldOfView
					and self.behaviors[self.cameraPos].FieldOfView[0]
					and self.behaviors[self.cameraPos].FieldOfView[0].Values
				or 70,
		}
	else
		self.initialCameraState = {
			CFrame = self.camera.CFrame,
			FieldOfView = self.camera.FieldOfView,
		}
	end
end

function NoRigAnimationModule:play()
	if not self.isLoaded then
		self:preload()
	end

	if self.cameraPos then
		self:_setInitialCameraState()
		self.camera.CFrame = self.initialCameraState.CFrame
		self.camera.FieldOfView = self.initialCameraState.FieldOfView
	end

	self:_startAnimation()
end

function NoRigAnimationModule:_startAnimation()
	self.isPlaying = true
	self.lastProcessedFrame = -1
	self.elapsedTime = 0

	if self.updateConnection then
		self.updateConnection:Disconnect()
	end

	self.updateConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if self.isPlaying then
			self.elapsedTime = self.elapsedTime + deltaTime * self.speed
			local currentFrame = math.floor(self.elapsedTime * self.frameRate)

			for frame = if self.lastProcessedFrame == 0 then self.lastProcessedFrame else self.lastProcessedFrame + 1, currentFrame do
				self:_handleBehaviors(frame)
			end
			self.lastProcessedFrame = currentFrame

			if currentFrame >= self.totalFrames and not self.loop then
				self:stop()
				self.finished:Fire()
			elseif currentFrame >= self.totalFrames and self.loop then
				self.lastProcessedFrame = -1
				self.elapsedTime = 0
			end
		end
	end)
end

function NoRigAnimationModule:_handlePartBehavior(index, behaviorType, behavior, nextBehavior, frame, nextFrame)
	local part = self.partMappings[index]
	if not part then
		return
	end

	if frame == 0 then
		if behaviorType == "CFrame" then
			local initialCFrame = behavior.Values
			if self.cameraMode == "Relative" then
				initialCFrame = self:_getTargetCFrame() * initialCFrame
			end
			part.CFrame = initialCFrame
		elseif behaviorType == "Size" then
			part.Size = Vector3.new(behavior.Values.x, behavior.Values.y, behavior.Values.z)
		elseif behaviorType == "Transparency" then
			part.Transparency = behavior.Values
		end
		return
	end

	local startFrame = frame
	local endFrame = nextFrame or self.totalFrames
	local duration = (endFrame - startFrame) / self.frameRate / self.speed

	local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)
	local targetValue

	if behaviorType == "CFrame" then
		targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
		if self.cameraMode == "Relative" then
			targetValue = self:_getTargetCFrame() * targetValue
		end
	elseif behaviorType == "Size" then
		targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
		targetValue = Vector3.new(targetValue.x, targetValue.y, targetValue.z)
	elseif behaviorType == "Transparency" then
		targetValue = if nextBehavior then nextBehavior.Values else behavior.Values
	end

	local newTween = TweenService:Create(part, tweenInfo, { [behaviorType] = targetValue })
	newTween:Play()

	if not self.activeTweens[part] then
		self.activeTweens[part] = {}
	end

	table.insert(self.activeTweens[part], newTween)
	newTween.Completed:Connect(function()
		if self.activeTweens[part] then
			local tweenIndex = table.find(self.activeTweens[part], newTween)
			if tweenIndex then
				table.remove(self.activeTweens[part], tweenIndex)
			end
			newTween:Destroy()
		end
	end)
end

function NoRigAnimationModule:_handleModelBehavior(index, behaviorType, behavior, nextBehavior, frame, nextFrame)
    local model = self.modelMappings[index]
    if not model then
        return
    end

    if not model.PrimaryPart then
        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                model.PrimaryPart = part
                break
            end
        end

        if not model.PrimaryPart then
            return
        end
    end

    if frame == 0 then
        if behaviorType == "CFrame" then
            local initialCFrame = behavior.Values
            if self.cameraMode == "Relative" then
                local referenceCFrame = self:_getTargetCFrame()
                initialCFrame = referenceCFrame * initialCFrame
            end
            model:SetPrimaryPartCFrame(initialCFrame)
        elseif behaviorType == "Transparency" then
            for _, part in ipairs(model:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.Transparency = behavior.Values
                end
            end
        end
        return
    end

    local startFrame = frame
    local endFrame = nextFrame or self.totalFrames
    local duration = (endFrame - startFrame) / self.frameRate / self.speed
    duration = math.max(duration, 0.01)

    local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction, 0, false, 0)

    if behaviorType == "CFrame" then
        local targetValue = nextBehavior and nextBehavior.Values or behavior.Values
        if self.cameraMode == "Relative" then
            local referenceCFrame = self:_getTargetCFrame()
            targetValue = referenceCFrame * targetValue
        end

        local newTween = TweenService:Create(model.PrimaryPart, tweenInfo, { CFrame = targetValue })
        newTween:Play()

        if not self.activeTweens[model] then
            self.activeTweens[model] = {}
        end

        table.insert(self.activeTweens[model], newTween)
        newTween.Completed:Connect(function()
            if self.activeTweens[model] then
                local tweenIndex = table.find(self.activeTweens[model], newTween)
                if tweenIndex then
                    table.remove(self.activeTweens[model], tweenIndex)
                end
                newTween:Destroy()
            end
        end)
    elseif behaviorType == "Transparency" then
        local targetValue = nextBehavior and nextBehavior.Values or behavior.Values

        for _, part in ipairs(model:GetDescendants()) do
            if part:IsA("BasePart") then
                local newTween = TweenService:Create(part, tweenInfo, { Transparency = targetValue })
                newTween:Play()

                if not self.activeTweens[part] then
                    self.activeTweens[part] = {}
                end

                table.insert(self.activeTweens[part], newTween)
                newTween.Completed:Connect(function()
                    if self.activeTweens[part] then
                        local tweenIndex = table.find(self.activeTweens[part], newTween)
                        if tweenIndex then
                            table.remove(self.activeTweens[part], tweenIndex)
                        end
                        newTween:Destroy()
                    end
                end)
            end
        end
    end
end

function NoRigAnimationModule:_handleParticleEmitterBehavior(index, behaviorType, behavior)
	local emitter = self.particleEmitters[index]
	if not emitter then
		return
	end

	if behaviorType == "Emit" then
		emitter:Emit(behavior.Values)
	elseif behaviorType == "Enabled" then
		emitter.Enabled = behavior.Values
	end
end

function NoRigAnimationModule:_handleCameraBehavior(behaviorType, behavior, nextBehavior, frame, nextFrame)
	if behaviorType == "CFrame" then
		self:_handleCameraCFrame(nextBehavior or behavior, frame, nextFrame)
	elseif behaviorType == "FieldOfView" then
		self:_handleCameraFieldOfView(nextBehavior, behavior, frame, nextFrame)
	end
end

function NoRigAnimationModule:_handleCameraCFrame(behavior, frame, nextFrame)
	local targetCFrame = behavior.Values
	if self.cameraMode == "Relative" then
		targetCFrame = self:_getTargetCFrame() * targetCFrame
	end

	local startFrame = frame
	local endFrame = nextFrame or self.totalFrames
	local duration = (endFrame - startFrame) / self.frameRate / self.speed
	local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)
	local newTween = TweenService:Create(self.camera, tweenInfo, { CFrame = targetCFrame })
	newTween:Play()

	if not self.activeTweens["camera"] then
		self.activeTweens["camera"] = {}
	end

	table.insert(self.activeTweens["camera"], newTween)
	newTween.Completed:Connect(function()
		if self.activeTweens["camera"] then
			local index = table.find(self.activeTweens["camera"], newTween)
			if index then
				table.remove(self.activeTweens["camera"], index)
			end
			newTween:Destroy()
		end
	end)
end

function NoRigAnimationModule:_handleCameraFieldOfView(nextBehavior, behavior, frame, nextFrame)
	local startFrame = frame
	local endFrame = nextFrame or self.totalFrames
	local duration = (endFrame - startFrame) / self.frameRate / self.speed

	local tweenInfo = TweenInfo.new(duration, behavior.Easing.Style, behavior.Easing.Direction)

	local newTween = TweenService:Create(
		self.camera,
		tweenInfo,
		{ FieldOfView = if nextBehavior then nextBehavior.Values else behavior.Values }
	)

	if not self.activeTweens["camera"] then
		self.activeTweens["camera"] = {}
	end

	table.insert(self.activeTweens["camera"], newTween)
	newTween:Play()
	newTween.Completed:Connect(function()
		if self.activeTweens["camera"] then
			local index = table.find(self.activeTweens["camera"], newTween)
			if index then
				table.remove(self.activeTweens["camera"], index)
			end
			newTween:Destroy()
		end
	end)
end

function NoRigAnimationModule:_findNextKeyframe(behaviors, currentFrame)
	local nextKeyframe = nil
	for frame, _ in pairs(behaviors) do
		if frame > currentFrame and (nextKeyframe == nil or frame < nextKeyframe) then
			nextKeyframe = frame
		end
	end
	return nextKeyframe
end

function NoRigAnimationModule:_findNextCFrameKeyframe(currentFrame)
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

function NoRigAnimationModule:_findNextFieldOfViewKeyframe(currentFrame)
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

function NoRigAnimationModule:_handleBehaviors(frame)
	for index, behaviorGroup in pairs(self.behaviors) do
		for behaviorType, behaviors in pairs(behaviorGroup) do
			local behavior = behaviors[frame]
			if behavior then
				if self.cameraPos and index == self.cameraPos then
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
				else
					local nextBehavior
					local nextFrame = self:_findNextKeyframe(behaviorGroup[behaviorType], frame)
					nextBehavior = behaviors[nextFrame]

					if self.partMappings[index] then
						self:_handlePartBehavior(index, behaviorType, behavior, nextBehavior, frame, nextFrame)
					elseif self.modelMappings[index] then
						self:_handleModelBehavior(index, behaviorType, behavior, nextBehavior, frame, nextFrame)
					elseif self.particleEmitters[index] then
						self:_handleParticleEmitterBehavior(index, behaviorType, behavior)
					end
				end
			end
		end
	end
end

function NoRigAnimationModule:_restoreOriginalProperties()
	for instance, props in pairs(self.originalProperties) do
		if instance == "camera" then
			if props.CameraType then
				self.camera.CameraType = props.CameraType
			end
			if props.FieldOfView then
				self.camera.FieldOfView = props.FieldOfView
			end
			if props.CFrame then
				self.camera.CFrame = props.CFrame
			end
		elseif instance and instance:IsA("Instance") and instance:IsDescendantOf(game) then
			for prop, value in pairs(props) do
				pcall(function()
					instance[prop] = value
				end)
			end
		end
	end
end

function NoRigAnimationModule:stop()
	self.isPlaying = false

	if self.updateConnection then
		self.updateConnection:Disconnect()
		self.updateConnection = nil
	end

	-- Cancel all active tweens
	for _, tweens in pairs(self.activeTweens) do
		for _, tween in ipairs(tweens) do
			tween:Cancel()
			tween:Destroy()
		end
	end
	self.activeTweens = {}

	-- Disable any particle emitters
	for _, emitter in pairs(self.particleEmitters) do
		if emitter and emitter:IsA("ParticleEmitter") then
			emitter.Enabled = false
		end
	end

	-- Restore original properties
	self:_restoreOriginalProperties()

	self.lastProcessedFrame = -1
	self.elapsedTime = 0
end

function NoRigAnimationModule:destroy()
	self:stop()

	-- Clean up any assets we created
	for _, asset in pairs(self.createdAssets) do
		if asset and asset:IsA("Instance") then
			asset:Destroy()
		end
	end

	self.partMappings = {}
	self.modelMappings = {}
	self.particleEmitters = {}
	self.createdAssets = {}
	self.behaviors = {}
	self.originalProperties = {}

	self.finished:Destroy()
end

return NoRigAnimationModule