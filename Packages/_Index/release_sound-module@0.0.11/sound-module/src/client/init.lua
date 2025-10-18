-- Services
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

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

local Knit = importPackage("knit")

-- Sound data and modules
local SoundDataFolder = ReplicatedStorage.Shared.Data.Sounds
local SoundModule = require(script.Modules.SoundModule)
local SoundServ = nil

-- Player
local player = Players.LocalPlayer

--|| Controller ||--
local SoundCtrl = Knit.CreateController({
	Name = "SoundCtrl",
	Sounds = {},
	Categories = {
		UI = "UI",
		MISC = "Misc",
		MUSIC = "Music",
	},
	GlobalVolume = {
		UI = 100,
		MISC = 100,
		MUSIC = 100,
	},

	IsMusicMuted = false,
})

function SoundCtrl:MuteMusic(tweenInfo)
	if self.IsMusicMuted then
		return -- Already muted
	end
	self.IsMusicMuted = true

	-- Iterate through all sounds and mute only music
	for _, sound in pairs(self.Sounds) do
		if sound.soundData and sound.soundData.Category == self.Categories.MUSIC then
			sound:setVolumeTween(0, tweenInfo)
		end
	end
end

function SoundCtrl:UnmuteMusic(tweenInfo)
	if not self.IsMusicMuted then
		return -- Already unmuted
	end

	self.IsMusicMuted = false

	-- Create a default tween info for unmuting
	-- Iterate through all sounds and restore music volumes
	for _, sound in pairs(self.Sounds) do
		if sound.soundData and sound.soundData.Category == self.Categories.MUSIC then
			-- Calculate the proper volume using original volume and global volume
			local restoredVolume = (sound.soundData.OriginalVolume or sound.soundData.Volume)
				* (self.GlobalVolume.MUSIC / 100)
			sound:setVolumeTween(restoredVolume, tweenInfo)
		end
	end
end

function SoundCtrl:SetGlobalVolume(Category, volume)
	-- Ensure volume is within valid range
	volume = math.clamp(volume, 0, 100)

	-- Update the global volume
	self.GlobalVolume[Category] = volume

	-- Update all existing sounds in this category
	for _, sound in pairs(self.Sounds) do
		if sound.soundData.Category == self.Categories[Category] then
			-- Recalculate the volume based on the original sound data
			local newVolume = (sound.soundData.OriginalVolume or sound.soundData.Volume) * (volume / 100)
			sound:setVolume(newVolume)
		end
	end
end

function SoundCtrl:EnhanceSoundData(soundData, soundName)
    local enhanced = table.clone(soundData)

    -- Determine category from sound name prefix
    enhanced.Category = enhanced.Category or self:DetermineCategoryFromName(soundName)

    -- Store the original volume before modification
    enhanced.OriginalVolume = enhanced.Volume

    -- Keep the Spammable and StopPreviousSounds properties if they exist
    enhanced.Spammable = soundData.Spammable
    enhanced.StopPreviousSounds = soundData.StopPreviousSounds

    -- Set default values based on category
    if enhanced.Category == self.Categories.UI then
        enhanced.Volume = enhanced.Volume or 0.5
        enhanced.Pitch = enhanced.Pitch or 1
        enhanced.SoundType = "2D"
        enhanced.RollOffEnabled = false
        -- Apply global volume multiplier
        enhanced.Volume = enhanced.Volume * (self.GlobalVolume.UI / 100)
    elseif enhanced.Category == self.Categories.MISC then
        enhanced.Volume = enhanced.Volume or 0.7
        enhanced.Pitch = enhanced.Pitch or 1
        enhanced.SoundType = enhanced.SoundType or "3D"
        enhanced.RollOffEnabled = enhanced.RollOffEnabled ~= nil and enhanced.RollOffEnabled or true
        enhanced.RollOffMinDistance = enhanced.RollOffMinDistance or 5
        enhanced.RollOffMaxDistance = enhanced.RollOffMaxDistance or 100
        enhanced.EmitterSize = enhanced.EmitterSize or 10
        -- Apply global volume multiplier
        enhanced.Volume = enhanced.Volume * (self.GlobalVolume.MISC / 100)
    elseif enhanced.Category == self.Categories.MUSIC then
        enhanced.Volume = enhanced.Volume or 0.3
        enhanced.Pitch = enhanced.Pitch or 1
        enhanced.SoundType = "2D"
        enhanced.RollOffEnabled = false
        enhanced.FadeTime = enhanced.FadeTime or 2
        -- Apply global volume multiplier
        enhanced.Volume = enhanced.Volume * (self.GlobalVolume.MUSIC / 100)
    end

    return enhanced
end


function SoundCtrl:DetermineCategoryFromName(soundName)
	if string.match(soundName, "^UI_") then
		return self.Categories.UI
	elseif string.match(soundName, "^MUSIC_") then
		return self.Categories.MUSIC
	else
		return self.Categories.MISC
	end
end

function SoundCtrl:DetermineDefaultParent(category)
	if category == self.Categories.UI then
		return player.PlayerGui
	elseif category == self.Categories.MUSIC then
		return SoundService
	else
		return workspace
	end
end

function SoundCtrl:FindPreloadedSound(soundName)
	-- First check if it's a UI or Music sound
	if string.match(soundName, "^UI_") then
		-- Look for the sound in all our stored sounds that use UIGroup
		for key, sound in pairs(self.Sounds) do
			if key:find(soundName) and key:find("UISegaSounds") then
				return sound
			end
		end
	elseif string.match(soundName, "^MUSIC_") then
		-- Look for the sound in all our stored sounds that use MusicGroup
		for key, sound in pairs(self.Sounds) do
			if key:find(soundName) and key:find("SegaMusicSounds") then
				return sound
			end
		end
	end
	return nil
end

function SoundCtrl:GetOrCreateSound(soundName, parent)
	-- First check for preloaded sounds
	local preloadedSound = self:FindPreloadedSound(soundName)
	if preloadedSound then
		return preloadedSound
	end

	-- If not preloaded, continue with regular sound creation
	local key = soundName .. "_" .. (parent and parent:GetFullName() or "noParent")

	if self.Sounds[key] then
		return self.Sounds[key]
	end

	local AllSoundData = require(SoundDataFolder)
	local soundData = AllSoundData[soundName]

	if not soundData then
		warn("Sound data not found for: " .. soundName)
		return nil
	end

	local enhancedSoundData = self:EnhanceSoundData(soundData, soundName)
	parent = parent or self:DetermineDefaultParent(enhancedSoundData.Category)

	local sound = SoundModule.new("rbxassetid://" .. enhancedSoundData.Id, enhancedSoundData, parent)
	sound:preload()

	self.Sounds[key] = sound
	return sound
end

function SoundCtrl:PlaySound(soundName, parent)
    -- Check if it's a synced sound first

    -- Normal sound playback
    local sound = self:GetOrCreateSound(soundName, parent)
    if sound then
        -- Check if it's music and currently muted
        if self.IsMusicMuted and sound.soundData.Category == self.Categories.MUSIC then
            sound:setVolume(0)
        end
        sound:play()
    end
    return sound
end

function SoundCtrl:PlayAndDestroySound(soundName, parent)
	local sound = self:GetOrCreateSound(soundName, parent)
	if sound then
		sound:play()
		sound.finished:Connect(function()
			task.wait(0.1)
			self:DestroySound(soundName, parent)
		end)
	end
end

-- Replace the StopSound method
function SoundCtrl:StopSound(soundName, parent)
	-- Normal sound stopping
	local key = soundName .. "_" .. (parent and parent:GetFullName() or "noParent")
	local sound = self.Sounds[key]
	if sound then
		sound:stop()
	end
end

function SoundCtrl:DestroySound(soundName, parent)
	local key = soundName .. "_" .. (parent and parent:GetFullName() or "noParent")
	local sound = self.Sounds[key]
	if sound then
		sound:destroy()
		self.Sounds[key] = nil
	end
end

function SoundCtrl:PreloadSound(soundName, parent)
	self:GetOrCreateSound(soundName, parent)
end

function SoundCtrl:CleanupPlayerSounds(playerDis)
	for key, sound in pairs(self.Sounds) do
		if key:find(playerDis.Name) then
			sound:destroy()
			self.Sounds[key] = nil
		end
	end
end

function SoundCtrl:StopAllSoundsInCategory(category)
	for _, sound in pairs(self.Sounds) do
		if sound.soundData and sound.soundData.Category == category then
			sound:stop()
		end
	end
end

function SoundCtrl:SetCategoryVolume(category, volume)
	for _, sound in pairs(self.Sounds) do
		if sound.soundData and sound.soundData.Category == category then
			sound:setVolume(volume)
		end
	end
end

function SoundCtrl:SetVolume(soundName, volume, parent)
	local sound = self:GetOrCreateSound(soundName, parent)
	if sound then
		sound:setVolume(volume)
	end
end

-- NEW FUNCTION: Clean up UI sounds
function SoundCtrl:CleanupUISounds()
	local keysToRemove = {}
	
	for key, sound in pairs(self.Sounds) do
		if sound.soundData and sound.soundData.Category == self.Categories.UI then
			sound:destroy()
			table.insert(keysToRemove, key)
		end
	end
	
	-- Remove keys after iteration to avoid modifying the table during iteration
	for _, key in ipairs(keysToRemove) do
		self.Sounds[key] = nil
	end
	
	-- Also destroy the UI sound group if it exists
	local uiGroup = player.PlayerGui:FindFirstChild("UISegaSounds")
	if uiGroup then
		uiGroup:Destroy()
	end
end

-- NEW FUNCTION: Recreate UI sound group and preload UI sounds
function SoundCtrl:ReloadUISounds()
	-- Create UI sound group
	local UIGroup = Instance.new("SoundGroup")
	UIGroup.Name = "UISegaSounds"
	UIGroup.Parent = player.PlayerGui

	-- Preload UI sounds
	local AllSoundData = require(SoundDataFolder)
	local count = 0
	
	for soundName, _ in pairs(AllSoundData) do
		if string.match(soundName, "^UI_") then
			self:PreloadSound(soundName, player.PlayerGui)
			count += 1
		end
	end
	
end

function SoundCtrl:PreloadCategorySounds()
	local AllSoundData = require(SoundDataFolder)

	-- Create sound groups for better organization
	local UIGroup = Instance.new("SoundGroup")
	UIGroup.Name = "UISegaSounds"
	UIGroup.Parent = player.PlayerGui

	local MusicGroup = Instance.new("SoundGroup")
	MusicGroup.Name = "SegaMusicSounds"
	MusicGroup.Parent = SoundService

	-- Track count for logging
	local uiCount, musicCount = 0, 0

	-- Preload UI and Music sounds
	for soundName, _ in pairs(AllSoundData) do
		if string.match(soundName, "^UI_") then
			self:PreloadSound(soundName, player.PlayerGui)
			uiCount += 1
		elseif string.match(soundName, "^MUSIC_") then
			self:PreloadSound(soundName, SoundService)
			musicCount += 1
		end
	end
	
end

function SoundCtrl:PlayServerSound(soundName, parent)
	--self:PlaySound(soundName, parent)
	return SoundServ:PlaySound(soundName, parent)
end

function SoundCtrl:Cleanup()
	for key, sound in pairs(self.Sounds) do
		sound:destroy()
		self.Sounds[key] = nil
	end
end

-- NEW FUNCTION: Handle player death
function SoundCtrl:HandlePlayerDeath()
	self:CleanupUISounds()
end

-- NEW FUNCTION: Handle player respawn
function SoundCtrl:HandlePlayerRespawn()
	self:ReloadUISounds()
end

--|| Knit Lifecycle ||--
function SoundCtrl:KnitInit()
	SoundServ = Knit.GetService("SoundServ")

	SoundServ.PlaySoundSignal:Connect(function(soundName, parent)
		self:PlaySound(soundName, parent)
	end)

	Players.PlayerRemoving:Connect(function(playerDis)
		self:CleanupPlayerSounds(playerDis)
	end)

	-- NEW: Listen for character events
	player.CharacterAdded:Connect(function(character)
		self:HandlePlayerRespawn()
		
		-- Setup death event for the new character
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			self:HandlePlayerDeath()
		end)
	end)
	
	-- Handle the case if player already has a character when controller initializes
	if player.Character then
		local humanoid = player.Character:FindFirstChild("Humanoid")
		if humanoid then
			humanoid.Died:Connect(function()
				self:HandlePlayerDeath()
			end)
		end
	end
end

function SoundCtrl:KnitStart()
	-- Preload UI and Music sounds during start
	self:PreloadCategorySounds()
end

return SoundCtrl