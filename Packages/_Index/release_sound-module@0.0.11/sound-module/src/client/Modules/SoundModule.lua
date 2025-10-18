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

local SoundModule = {}
SoundModule.__index = SoundModule

-- Sound types enum
SoundModule.Type = {
	EFFECT_3D = "3D", -- Positional sounds like footsteps
	EFFECT_2D = "2D", -- Non-positional effects like UI sounds
	MUSIC = "Music", -- Background music
	AMBIENT = "Ambient", -- Environmental sounds
}

function SoundModule.new(soundId, soundData, parent)
	local self = setmetatable({}, SoundModule)
	self.soundId = soundId
	self.sound = nil
	self.parent = parent
	self.isLoaded = false
	self.isPlaying = false
	self.soundData = soundData
	-- Sound properties from soundData
	self.volume = soundData.Volume or 1
	self.pitch = soundData.Pitch or 1
	self.loop = soundData.Looped or false
	self.fadeTime = soundData.FadeTime or 0.1
	self.isExclusive = soundData.isExclusive or false
	self.soundType = soundData.SoundType or SoundModule.Type.EFFECT_3D
	self.isSpammable = soundData.Spammable or false
	self.stopPreviousSounds = soundData.StopPreviousSounds or false
	self.childSounds = {} -- Store child sounds for spammable sounds

	self.finished = Signal.new()

	return self
end

function SoundModule:preload()
	if self.isLoaded then
		return
	end

	if not self.parent then
		warn("Parent not found. Cannot create sound.")
		return
	end

	self.sound = Instance.new("Sound")
	self.sound.SoundId = self.soundId
	self.sound.Volume = self.volume
	self.sound.Pitch = self.pitch
	self.sound.Looped = self.loop

	-- Configure sound based on type
	if self.soundType == SoundModule.Type.EFFECT_2D or self.soundType == SoundModule.Type.MUSIC then
		-- Non-positional sounds
		self.sound.RollOffMode = Enum.RollOffMode.Linear
		self.sound.EmitterSize = 0
	elseif self.soundType == SoundModule.Type.EFFECT_3D then
		-- 3D positional sounds
		self.sound.RollOffMode = Enum.RollOffMode.Linear
		self.sound.EmitterSize = 10
		self.sound.RollOffMinDistance = 5
		self.sound.RollOffMaxDistance = 150
	elseif self.soundType == SoundModule.Type.AMBIENT then
		-- Ambient sounds with gentle falloff
		self.sound.RollOffMode = Enum.RollOffMode.Linear
		self.sound.EmitterSize = 50
		self.sound.RollOffMinDistance = 20
		self.sound.RollOffMaxDistance = 1000
	end

	self.sound.Parent = self.parent

	self.sound.Ended:Connect(function()
		self.isPlaying = false
		self.finished:Fire()
	end)

	self.isLoaded = true
end

function SoundModule:createChildSound()
	local childSound = Instance.new("Sound")
	childSound.SoundId = self.soundId
	childSound.Volume = self.volume
	childSound.Pitch = self.pitch
	childSound.Looped = self.loop
	childSound.Parent = self.parent

	-- Configure child sound based on parent's type
	if self.soundType == SoundModule.Type.EFFECT_2D or self.soundType == SoundModule.Type.MUSIC then
		childSound.RollOffMode = Enum.RollOffMode.Linear
		childSound.EmitterSize = 0
	elseif self.soundType == SoundModule.Type.EFFECT_3D then
		childSound.RollOffMode = Enum.RollOffMode.Linear
		childSound.EmitterSize = 10
		childSound.RollOffMinDistance = 5
		childSound.RollOffMaxDistance = 150
	elseif self.soundType == SoundModule.Type.AMBIENT then
		childSound.RollOffMode = Enum.RollOffMode.Linear
		childSound.EmitterSize = 50
		childSound.RollOffMinDistance = 20
		childSound.RollOffMaxDistance = 1000
	end

	-- Add to child sounds table
	table.insert(self.childSounds, childSound)

	-- Auto cleanup when sound ends
	childSound.Ended:Connect(function()
		for i, sound in ipairs(self.childSounds) do
			if sound == childSound then
				table.remove(self.childSounds, i)
				childSound:Destroy()
				break
			end
		end
	end)

	return childSound
end

function SoundModule:play()
	if not self.isLoaded then
		self:preload()
	end

	if not self.sound then
		warn("Sound not loaded. Cannot play sound.")
		return
	end

	if self.isExclusive then
		self:_stopAllSounds()
	end

	if self.isSpammable then
		-- If StopPreviousSounds is true, stop and destroy all previous child sounds
		if self.stopPreviousSounds then
			for _, childSound in ipairs(self.childSounds) do
				childSound:Stop()
				childSound:Destroy()
			end
			self.childSounds = {}
		end

		-- Create and play a new child sound
		local childSound = self:createChildSound()
		childSound:Play()
	else
		-- Handle fade-in for non-spammable sounds
		if self.fadeTime > 0 then
			local originalVolume = self.sound.Volume
			self.sound.Volume = 0
			self.sound:Play()
			local tweenInfo = TweenInfo.new(self.fadeTime, Enum.EasingStyle.Linear)
			game:GetService("TweenService"):Create(self.sound, tweenInfo, { Volume = originalVolume }):Play()
		else
			self.sound:Play()
		end
		self.isPlaying = true
	end
end

function SoundModule:stop()
	if self.isSpammable then
		-- Stop all child sounds
		for _, childSound in ipairs(self.childSounds) do
			if self.fadeTime > 0 then
				local tweenInfo = TweenInfo.new(self.fadeTime, Enum.EasingStyle.Linear)
				local tween = game:GetService("TweenService"):Create(childSound, tweenInfo, { Volume = 0 })
				tween.Completed:Connect(function()
					childSound:Stop()
				end)
				tween:Play()
			else
				childSound:Stop()
			end
		end
	elseif self.sound and self.isPlaying then
		if self.fadeTime > 0 then
			local tweenInfo = TweenInfo.new(self.fadeTime, Enum.EasingStyle.Linear)
			local tween = game:GetService("TweenService"):Create(self.sound, tweenInfo, { Volume = 0 })
			tween.Completed:Connect(function()
				self.sound:Stop()
				self.sound.Volume = self.volume
			end)
			tween:Play()
		else
			self.sound:Stop()
		end
		self.isPlaying = false
	end
end

function SoundModule:destroy()
	-- Stop and destroy all child sounds for spammable sounds
	for _, childSound in ipairs(self.childSounds) do
		if childSound.IsPlaying and self.fadeTime > 0 then
			local tweenInfo = TweenInfo.new(self.fadeTime, Enum.EasingStyle.Linear)
			local tween = game:GetService("TweenService"):Create(childSound, tweenInfo, { Volume = 0 })
			tween:Play()
			task.wait(self.fadeTime)
		end
		childSound:Destroy()
	end
	self.childSounds = {}

	if self.sound then
		if self.isPlaying and self.fadeTime > 0 then
			local tweenInfo = TweenInfo.new(self.fadeTime, Enum.EasingStyle.Linear)
			local tween = game:GetService("TweenService"):Create(self.sound, tweenInfo, { Volume = 0 })
			tween:Play()
			task.wait(self.fadeTime)
		end
		self.sound:Destroy()
	end

	self.finished:Destroy()
	self.isLoaded = false
	self.isPlaying = false
end

-- Additional utility functions with spammable sound support
function SoundModule:setVolume(volume)
	self.volume = volume
	if self.sound then
		self.sound.Volume = volume
	end
	-- Update volume for all child sounds
	for _, childSound in ipairs(self.childSounds) do
		childSound.Volume = volume
	end
end

function SoundModule:setVolumeTween(volume, tweenInfo)
	self.volume = volume

	-- Default tween info if none provided
	tweenInfo = tweenInfo or TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

	if self.sound then
		task.spawn(function()
			local tween = game:GetService("TweenService"):Create(self.sound, tweenInfo, { Volume = volume })
			tween:Play()
		end)
	end

	-- Tween volume for all child sounds
	for _, childSound in ipairs(self.childSounds) do
		task.spawn(function()
			local tween = game:GetService("TweenService"):Create(childSound, tweenInfo, { Volume = volume })
			tween:Play()
		end)
	end
end

function SoundModule:setPitch(pitch)
	self.pitch = pitch
	if self.sound then
		self.sound.Pitch = pitch
	end
	-- Update pitch for all child sounds
	for _, childSound in ipairs(self.childSounds) do
		childSound.Pitch = pitch
	end
end

function SoundModule:setLoop(loop)
	self.loop = loop
	if self.sound then
		self.sound.Looped = loop
	end
	-- Update loop for all child sounds
	for _, childSound in ipairs(self.childSounds) do
		childSound.Looped = loop
	end
end

return SoundModule
