local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animation = require(ReplicatedStorage.Packages.Animation)

local ServerBaseBlueprint = require(script.Parent.BaseBlueprint)

-- The lid (Chest_Lid* parts) is rigged on the Motor6D "Lid" (Chest_Wood -> Chest_LidWood, on the
-- back hinges) and animated through the Animation package, like the Bird.
-- Chest_Opened holds the lid open (Idle, looped) under Chest_Open, so the lid stays open once
-- Chest_Open ends. Keyframes: 3DModel/chest_animations.py
local Chest = {}
Chest.__index = Chest
setmetatable(Chest, { __index = ServerBaseBlueprint })

local OPEN_ANIMATION = "Chest_Open"
local OPENED_ANIMATION = "Chest_Opened"
local CLOSE_ANIMATION = "Chest_Close"
local LID_PREFIX = "Chest_Lid"

function Chest.new(data)
	local self = ServerBaseBlueprint.new(data)
	setmetatable(self, Chest)

	self.IsActive = false
	self.IsOpen = false
	self.LidReady = false

	self.OnCompleted:Connect(function()
		self:_OnChestCompleted()
	end)

	if self.CompletedAt > 0 then
		self:_OnChestCompleted()
	elseif self:IsComplete() then
		self.CompletedAt = os.time()
		self:_OnChestCompleted()
	end

	return self
end

function Chest:_OnChestCompleted()
	self.IsActive = true
end

function Chest:CanPlayerUse(playerId: number): boolean
	return self.IsActive and playerId == self.OwnerId
end

-- The base anchors every part of the completed model: the lid is unanchored once the
-- placement wave is over, so the Motor6D can move it
function Chest:_PlayPlacementAnimation(model: Model, centerPosition: Vector3): number
	local duration = ServerBaseBlueprint._PlayPlacementAnimation(self, model, centerPosition)
	self.LidReady = false

	task.delay(duration, function()
		if self.Model == model and model.Parent then
			self:_SetupLid(model)
		end
	end)

	return duration
end

function Chest:_SetupLid(model: Model)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and string.sub(part.Name, 1, #LID_PREFIX) == LID_PREFIX then
			part.Anchored = false
		end
	end

	Animation:PreloadAnimOnServer(model, OPEN_ANIMATION)
	Animation:PreloadAnimOnServer(model, OPENED_ANIMATION)
	Animation:PreloadAnimOnServer(model, CLOSE_ANIMATION)
	if self.Model ~= model then return end

	self.LidReady = true
	if self.IsOpen then
		Animation:PlayAnimOnServer(model, OPENED_ANIMATION)
	end
end

--|| Lid ||--

function Chest:Open()
	if self.IsOpen then return end
	self.IsOpen = true
	if not self.LidReady then return end

	Animation:StopAnimOnServer(self.Model, CLOSE_ANIMATION)
	Animation:PlayAnimOnServer(self.Model, OPENED_ANIMATION)
	Animation:PlayAnimOnServer(self.Model, OPEN_ANIMATION)
end

function Chest:Close()
	if not self.IsOpen then return end
	self.IsOpen = false
	if not self.LidReady then return end

	Animation:StopAnimOnServer(self.Model, OPEN_ANIMATION)
	Animation:StopAnimOnServer(self.Model, OPENED_ANIMATION)
	Animation:PlayAnimOnServer(self.Model, CLOSE_ANIMATION)
end

function Chest:DestroyModel()
	self.IsActive = false
	self.IsOpen = false
	self.LidReady = false
	ServerBaseBlueprint.DestroyModel(self)
end

return Chest
