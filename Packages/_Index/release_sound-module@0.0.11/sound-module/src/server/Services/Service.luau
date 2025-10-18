-- Services
local Players = game:GetService("Players")
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

local Knit = importPackage("knit")

--|| Service ||--
local SoundServ = Knit.CreateService({
	Name = "SoundServ",
	Client = {
		PlaySoundSignal = Knit.CreateSignal(),
		StopSoundSignal = Knit.CreateSignal(),
	},
})

-- Client exposed methods
function SoundServ.Client:PlaySound(_, soundName, parent)
	return self.Server:PlaySound(soundName, parent)
end

function SoundServ.Client:StopSound(_, soundName, parent)
	return self.Server:StopSound(soundName, parent)
end

-- Server methods
function SoundServ:PlaySound(soundName, parent)
	-- Validate if the sound exists in our data
	local SoundData = require(ReplicatedStorage.Shared.Data.Sounds)
	if not SoundData[soundName] then
		warn("Attempted to play non-existent sound:", soundName)
		return false
	end

	-- Determine which players should receive the sound
	local playersToReceive = self:GetPlayersInRange(parent)

	-- Fire the signal to play the sound for appropriate clients
	for _, player in ipairs(playersToReceive) do
		self.Client.PlaySoundSignal:Fire(player, soundName, parent)
	end

	return true
end

function SoundServ:StopSound(soundName, parent)
	-- Determine which players should receive the stop signal
	local playersToReceive = self:GetPlayersInRange(parent)

	-- Fire the signal to stop the sound for appropriate clients
	for _, player in ipairs(playersToReceive) do
		self.Client.StopSoundSignal:Fire(player, soundName, parent)
	end

	return true
end

function SoundServ:PlaySoundForPlayer(player, soundName, parent)
	if typeof(player) == "Instance" and player:IsA("Player") then
		self.Client.PlaySoundSignal:Fire(player, soundName, parent)
		return true
	end
	return false
end

function SoundServ:PlaySoundForAll(soundName, parent)
	self.Client.PlaySoundSignal:FireAll(soundName, parent)
	return true
end

function SoundServ:PlaySoundInRange(soundName, position, range)
	-- Play sound for players within specified range of a position
	local playersInRange = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character and character:FindFirstChild("HumanoidRootPart") then
			local distance = (character.HumanoidRootPart.Position - position).Magnitude
			if distance <= range then
				table.insert(playersInRange, player)
			end
		end
	end

	for _, player in ipairs(playersInRange) do
		self.Client.PlaySoundSignal:Fire(player, soundName, workspace)
	end

	return true
end

-- Helper methods
function SoundServ:GetPlayersInRange(parent)
	local players = {}

	-- If no parent specified or parent is a global object, send to all players
	if not parent or parent == workspace or parent == game:GetService("SoundService") then
		return Players:GetPlayers()
	end

	-- If parent is associated with a specific player (like PlayerGui), only send to that player
	local playerOwner = self:GetPlayerFromInstance(parent)
	if playerOwner then
		return { playerOwner }
	end

	-- For 3D positional sounds, get players within audible range
	local position = self:GetParentPosition(parent)
	if position then
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			if character and character:FindFirstChild("HumanoidRootPart") then
				local distance = (character.HumanoidRootPart.Position - position).Magnitude
				-- Use a reasonable default range (you might want to make this configurable)
				if distance <= 100 then
					table.insert(players, player)
				end
			end
		end
	end

	return players
end

function SoundServ:GetParentPosition(parent)
	if typeof(parent) == "Vector3" then
		return parent
	elseif typeof(parent) == "Instance" then
		if parent:IsA("BasePart") then
			return parent.Position
		elseif parent:IsA("Model") and parent.PrimaryPart then
			return parent.PrimaryPart.Position
		end
	end
	return nil
end

function SoundServ:GetPlayerFromInstance(instance)
	if not instance then
		return nil
	end

	-- Check if instance is directly under a player
	local ancestor = instance
	while ancestor do
		if ancestor:IsA("Player") then
			return ancestor
		end
		ancestor = ancestor.Parent
	end

	return nil
end

--|| Lifecycle ||--
function SoundServ:KnitInit()
	-- Initialize any necessary server-side setup
end

function SoundServ:KnitStart()
	-- Start any necessary processes after all services are initialized
end

return SoundServ
