--[=[
	Server BaseMob - parent of every mob class (Cow, Sheep, Chicken, later hostile mobs and bosses)
	Owns the mob's model, health, current behavior and MobMover. Created by MobService:Spawn.

	The mob DECIDES which behavior runs (OnDamaged, Think); behaviors decide where it goes;
	MobMover moves it. Override in subclasses:
	  OnThink(dt)        extra decisions every think tick (e.g. a hostile mob looking for players)
	  OnDamaged(source)  reaction to a hit (default: Passive flees, Hostile chases the attacker)
	  Attack(target)     called by the Aggressive behavior when in range (default: nothing)

	Replicated to clients via model attributes (MobConfig.Attributes):
	  MoveState (Idle/Walk/Run, the client plays the animation), Enabled, Health, MaxHealth
]=]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Packages.Signal)
local MobConfig = require(ReplicatedStorage.Shared.Config.MobConfig)
local MobMover = require(script.Parent.MobMover)

local Behaviors = {}
for _, module in ipairs(script.Parent.Behaviors:GetChildren()) do
	if module:IsA("ModuleScript") and module.Name ~= "BaseBehavior" then
		Behaviors[module.Name] = require(module)
	end
end

local ATTRIBUTES = MobConfig.Attributes
local IDLE_SPEED = 0.5 -- planar speed under which the mob plays Idle

local BaseMob = {}
BaseMob.__index = BaseMob

function BaseMob.new(id: number, mobType: string, data, model: Model, options)
	local self = setmetatable({}, BaseMob)
	options = options or {}

	self.Id = id
	self.Type = mobType
	self.Data = data
	self.Model = model
	self.Root = model.PrimaryPart
	self.CollidePart = model:FindFirstChild("CollidePart")
	self.Mover = MobMover.new(self.Root, self.CollidePart, data.jumpHeight)

	self.HomePosition = options.homePosition or self.Root.Position
	self.Habitat = data.habitat or "Ground" -- "Ground" | "Water" | "Any" (Navigation/Water)
	self.IsDevSpawn = options.isDevSpawn == true
	self.MaxHealth = data.maxHealth or 10
	self.Health = self.MaxHealth
	self.Enabled = false
	self.IsDead = false
	self.ModelDestroyed = false
	self.Behavior = nil
	self.BehaviorName = nil
	self.MoveState = nil
	self.ThinkTimer = math.random() / MobConfig.ThinkRate -- spread mobs over the think ticks

	self.Died = Signal.new() -- (killer)
	self.Damaged = Signal.new() -- (amount, source)
	self.EnabledChanged = Signal.new() -- (enabled)

	model:SetAttribute(ATTRIBUTES.MobId, id)
	model:SetAttribute(ATTRIBUTES.MobType, mobType)
	model:SetAttribute(ATTRIBUTES.MaxHealth, self.MaxHealth)
	model:SetAttribute(ATTRIBUTES.Health, self.Health)
	model:SetAttribute(ATTRIBUTES.Enabled, false)

	self:SetBehavior("Immobile")
	self:_SetMoveState("Idle")
	return self
end

--|| Behaviors ||--

-- Replace the current behavior. Names: Immobile, Patrolling, GoToPos, Fleeing, Aggressive
function BaseMob:SetBehavior(name: string, params)
	local behaviorClass = Behaviors[name]
	if not behaviorClass then
		warn("[BaseMob] Unknown behavior:", name)
		return
	end
	if self.Behavior then
		self.Behavior:Exit()
	end
	self.BehaviorName = name
	self.Behavior = behaviorClass.new(self, params)
	self.Behavior:Enter()
end

function BaseMob:SetDefaultBehavior()
	self:SetBehavior(self.Data.defaultBehavior or "Patrolling")
end

function BaseMob:GetSpeed(speedMode: string): number
	if speedMode == "Run" then
		return self.Data.runSpeed
	end
	return self.Data.walkSpeed
end

--|| Enable / freeze ||--

function BaseMob:Enable()
	if self.Enabled or self.IsDead then return end
	self.Enabled = true
	self.Model:SetAttribute(ATTRIBUTES.Enabled, true)
	self:SetDefaultBehavior()
	self.EnabledChanged:Fire(true)
end

-- Freeze: stands still (Immobile) until enabled again
function BaseMob:Disable()
	if not self.Enabled then return end
	self.Enabled = false
	self.Model:SetAttribute(ATTRIBUTES.Enabled, false)
	self:SetBehavior("Immobile")
	self.EnabledChanged:Fire(false)
end

--|| Update (MobService) ||--

-- Every Heartbeat
function BaseMob:Step(dt: number)
	self.Mover:Step(dt)
end

-- MobConfig.ThinkRate times per second
function BaseMob:Think(dt: number)
	if self.Enabled and self.Behavior then
		self:OnThink(dt)
		self.Behavior:Update(dt)
		if self.Behavior.Finished then
			self:SetDefaultBehavior()
		end
	end
	self:_UpdateMoveState()
end

function BaseMob:OnThink(_dt: number) end

function BaseMob:_UpdateMoveState()
	local state = "Idle"
	local commanded = self.Mover:GetCommandedSpeed()
	if commanded > 0 and self.Mover:GetPlanarSpeed() > IDLE_SPEED then
		state = commanded > self.Data.walkSpeed + 0.5 and "Run" or "Walk"
	end
	self:_SetMoveState(state)
end

function BaseMob:_SetMoveState(state: string)
	if self.MoveState == state then return end
	self.MoveState = state
	self.Model:SetAttribute(ATTRIBUTES.MoveState, state)
end

--|| Combat hooks (the fighting system plugs in here) ||--

function BaseMob:TakeDamage(amount: number, source)
	if self.IsDead or amount <= 0 then return end
	self.Health = math.max(self.Health - amount, 0)
	self.Model:SetAttribute(ATTRIBUTES.Health, self.Health)
	self.Damaged:Fire(amount, source)

	if self.Health <= 0 then
		self:Die(source)
	elseif self.Enabled then
		self:OnDamaged(source)
	end
end

function BaseMob:OnDamaged(source)
	if self.Data.hostility == "Hostile" and typeof(source) == "Instance" and source:IsA("Player") then
		self:SetBehavior("Aggressive", { target = source })
	elseif source then
		self:SetBehavior("Fleeing", { threat = source })
	end
end

function BaseMob:Attack(_target: Player) end

-- MobService listens to Died and despawns the mob
function BaseMob:Die(killer)
	if self.IsDead then return end
	self.IsDead = true
	self:SetBehavior("Immobile")
	self.Died:Fire(killer)
end

function BaseMob:GetPosition(): Vector3
	return self.Root.Position
end

function BaseMob:Destroy()
	if self.Behavior then
		self.Behavior:Exit()
		self.Behavior = nil
	end
	self.Died:Destroy()
	self.Damaged:Destroy()
	self.EnabledChanged:Destroy()
	-- ModelDestroyed: the model is already being destroyed (MobService, Destroying event)
	if not self.ModelDestroyed then
		self.Mover:Destroy()
		self.Model:Destroy()
	end
end

return BaseMob
