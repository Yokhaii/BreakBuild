local ReplicatedStorage = game:GetService("ReplicatedStorage")

--|| Imports ||--
local ImportFolder = ReplicatedStorage:FindFirstChild("Packages")

local src = script
while src and src.Name ~= "src" do
	src = src:FindFirstAncestorWhichIsA("Folder")
end

local function importPackage(name: string)
	local RootFolder = src and src:FindFirstAncestorWhichIsA("Folder") or nil

	return RootFolder and require(RootFolder[name]) or require(ImportFolder:FindFirstChild(name))
end

local Signal = importPackage("signal")

local AnimationModule = {}
AnimationModule.__index = AnimationModule

function AnimationModule.new(animationId, animationData, customModel)
	local self = setmetatable({}, AnimationModule)
	self.animationId = animationId
	self.animationData = animationData
	self.animation = nil
	self.animationTrack = nil
	self.model = customModel
	self.humanoid = nil
	self.animator = nil
	self.isLoaded = false
	self.isPlaying = false
	self.priority = animationData.Priority or "Action"
	self.weight = animationData.Weight or 1
	self.isExclusive = animationData.isExclusive or false
	self.speed = animationData.Speed or 1
	self.fadeTime = animationData.FadeTime or 0.1
	self.loop = animationData.Loop or false
	self.finished = Signal.new()
	self.stoppedAnimations = {}
	return self
end

function AnimationModule:_getAnimator()
	if not self.model then
		warn("Model not found. Cannot get animator.")
		return nil
	end

	-- Check if the model is a character (has a Humanoid)
	self.humanoid = self.model:FindFirstChildOfClass("Humanoid")
	if self.humanoid then
		self.animator = self.humanoid:FindFirstChildOfClass("Animator")
		if not self.animator then
			self.animator = Instance.new("Animator")
			self.animator.Parent = self.humanoid
		end
	else
		-- If it's not a character, look for an Animator directly in the model
		self.animator = self.model:FindFirstChild("AnimationController"):FindFirstChildOfClass("Animator")
	end

	return self.animator
end

function AnimationModule:preload()
	if self.isLoaded then
		return
	end

	self.animator = self:_getAnimator()
	if not self.animator then
		warn("Animator not found. Cannot preload animation.")
		return
	end

	self.animation = Instance.new("Animation")
	self.animation.AnimationId = self.animationId
	self.animationTrack = self.animator:LoadAnimation(self.animation)
	self.animationTrack.Priority = self.priority
	self.animationTrack.Looped = self.loop
	self.isLoaded = true
end

function AnimationModule:play()
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

	self.animationTrack:Play(self.fadeTime, self.weight, self.speed)
	self.isPlaying = true

	self.animationTrack.Stopped:Connect(function()
		self.isPlaying = false
		self.finished:Fire()
	end)
end

function AnimationModule:_stopAllAnimations()
	self.stoppedAnimations = {}
	for _, track in ipairs(self.animator:GetPlayingAnimationTracks()) do
		if track ~= self.animationTrack then
			track:Stop()
			track:Destroy()
		end
	end
end

function AnimationModule:stop()
	if self.animationTrack and self.isPlaying then
		self.animationTrack:Stop(self.fadeTime)
		self.isPlaying = false
	end
end

function AnimationModule:destroy()
	self:stop()
	if self.animationTrack then
		self.animationTrack:Destroy()
	end
	if self.animation then
		self.animation:Destroy()
	end
	self.finished:Destroy()
	self.isLoaded = false
	self.isPlaying = false
end

return AnimationModule
