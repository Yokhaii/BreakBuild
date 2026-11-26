--[=[
	Client BaseMob - visuals of one mob, created by MobController for each mob model
	streamed to this client (CollectionService tag MobConfig.MobTag).
	Plays the Idle / Walk / Run animation matching the server's MoveState attribute,
	always through the Animation package (Shared.AnimationDataFolder.Mobs).
	Override in subclasses for mob-specific visuals (sounds, particles, health bar...).
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Animation = require(ReplicatedStorage.Packages.Animation)
local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)

local ATTRIBUTES = MobConfig.Attributes

local BaseMob = {}
BaseMob.__index = BaseMob

function BaseMob.new(model: Model, data)
	local self = setmetatable({}, BaseMob)
	self.Model = model
	self.Data = data
	self.MoveState = nil
	self.Connections = {}

	table.insert(self.Connections, model:GetAttributeChangedSignal(ATTRIBUTES.MoveState):Connect(function()
		self:SetMoveState(model:GetAttribute(ATTRIBUTES.MoveState))
	end))
	self:SetMoveState(model:GetAttribute(ATTRIBUTES.MoveState) or "Idle")

	return self
end

function BaseMob:SetMoveState(state: string?)
	if not state or state == self.MoveState then return end
	local animations = self.Data.animations or {}

	local previous = self.MoveState and animations[self.MoveState]
	if previous then
		Animation:StopAnim(previous, self.Model)
	end

	self.MoveState = state
	local animationName = animations[state]
	if animationName then
		Animation:PlayAnim(animationName, self.Model)
	end
end

function BaseMob:Destroy()
	for _, connection in ipairs(self.Connections) do
		connection:Disconnect()
	end
	self.Connections = {}
	-- Also covers a model already streamed out (its full name changed)
	Animation:CleanupInstanceAnimations(self.Model)
end

return BaseMob
