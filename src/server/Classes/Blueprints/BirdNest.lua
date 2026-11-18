local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Knit = require(ReplicatedStorage.Packages.Knit)

local ServerBaseBlueprint = require(script.Parent.BaseBlueprint)
local Bird = require(script.Parent.Parent.Bird)

-- Passive structure: production and collection are handled by PassiveBlueprintService.
-- The completed nest has a bird whose trips follow the passive timer: it leaves after
-- a short rest and lands back when the trip's loot is rolled. It stays in the nest when full.
local BirdNest = {}
BirdNest.__index = BirdNest
setmetatable(BirdNest, { __index = ServerBaseBlueprint })

local NEST_OFFSET = Vector3.new(0, 12, 0) -- top of the nest planks, relative to the anchor block
local NEST_YAW = math.rad(45) -- diagonal, so the 4-stud bird fits between the rim planks
local REST_TIME = 6 -- seconds in the nest before the next trip
local CHECK_INTERVAL = 0.25

function BirdNest.new(data)
	local self = ServerBaseBlueprint.new(data)
	setmetatable(self, BirdNest)

	self.IsActive = false
	self.Bird = nil

	self.OnCompleted:Connect(function()
		self:_OnNestCompleted()
	end)

	if self.CompletedAt > 0 then
		self:_OnNestCompleted()
	elseif self:IsComplete() then
		self.CompletedAt = os.time()
		self:_OnNestCompleted()
	end

	return self
end

function BirdNest:_OnNestCompleted()
	self.IsActive = true
end

function BirdNest:CanPlayerUse(playerId: number): boolean
	return self.IsActive and playerId == self.OwnerId
end

function BirdNest:CreateCompletedModel(buildingAreaOrigin: Vector3, parentZone: Instance?): Model?
	local model = ServerBaseBlueprint.CreateCompletedModel(self, buildingAreaOrigin, parentZone)
	if model then
		self:_SpawnBird(buildingAreaOrigin + self.RelativePosition, model.Parent)
	end
	return model
end

function BirdNest:DestroyModel()
	self.IsActive = false
	self:_DestroyBird()
	ServerBaseBlueprint.DestroyModel(self)
end

--|| Bird ||--

-- The bird is a sibling of the nest model so it does not change the nest's bounding box
function BirdNest:_SpawnBird(anchorPosition: Vector3, parent: Instance)
	self:_DestroyBird()

	local nestCFrame = CFrame.new(anchorPosition + NEST_OFFSET) * CFrame.Angles(0, NEST_YAW, 0)
	local bird = Bird.new(nestCFrame, parent)
	if not bird then return end

	bird.Model.Name = "Bird_" .. self.Id
	self.Bird = bird
	task.spawn(function()
		self:_RunBird(bird)
	end)
end

function BirdNest:_DestroyBird()
	if self.Bird then
		self.Bird:Destroy()
		self.Bird = nil
	end
end

-- { stored, maxStored, interval, secsRemaining? } or nil (owner gone, nest not active)
function BirdNest:_GetPassiveState()
	local player = Players:GetPlayerByUserId(self.OwnerId)
	if not player then return nil end
	return Knit.GetService("PassiveBlueprintService"):GetState(player, self.Id)
end

function BirdNest:_RunBird(bird)
	local restUntil = os.clock() + REST_TIME

	while self.Bird == bird do
		local state = self:_GetPassiveState()
		local secsRemaining = state and state.secsRemaining

		if bird.IsHome then
			-- Leave only if there is time for a full trip before the loot is rolled
			local tripTime = bird.DepartureDuration + bird.ReturnDuration
			if secsRemaining and secsRemaining > tripTime and os.clock() >= restUntil then
				bird:FlyAway()
			end
		elseif not secsRemaining or secsRemaining <= bird.ReturnDuration then
			-- Land when the loot is rolled (or right away if the nest is full)
			bird:FlyBack()
			restUntil = os.clock() + REST_TIME
		end

		task.wait(CHECK_INTERVAL)
	end
end

return BirdNest
