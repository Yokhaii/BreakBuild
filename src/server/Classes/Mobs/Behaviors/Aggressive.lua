--[=[
	Aggressive - chase a player and attack when in range, finish when the target is lost
	Attacking itself is the mob's job (BaseMob:Attack, overridden by hostile mobs).
	params:
	  target        Player     who to chase (required)
	  loseDistance  number?    give up beyond this distance (default 80)
	  attackRange   number?    studs from the mob's edge to attack (default 3)
	  speedMode     "Walk" | "Run"?   default "Run"
]=]

local BaseBehavior = require(script.Parent.BaseBehavior)

local Aggressive = {}
Aggressive.__index = Aggressive
setmetatable(Aggressive, { __index = BaseBehavior })

local DEFAULT_LOSE_DISTANCE = 80
local DEFAULT_ATTACK_RANGE = 3

function Aggressive.new(mob, params)
	local self = BaseBehavior.new(mob, params)
	setmetatable(self, Aggressive)
	self.Speed = mob:GetSpeed(self.Params.speedMode or "Run")
	self.LoseDistance = self.Params.loseDistance or DEFAULT_LOSE_DISTANCE
	local radius = mob.CollidePart and mob.CollidePart.Size.X / 2 or 1
	self.AttackDistance = radius + (self.Params.attackRange or DEFAULT_ATTACK_RANGE)
	return self
end

function Aggressive:_GetTargetPosition(): Vector3?
	local target = self.Params.target
	if typeof(target) ~= "Instance" or not target:IsA("Player") or not target.Parent then
		return nil
	end
	local character = target.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil
	end
	return root.Position
end

function Aggressive:Update(_dt: number)
	local targetPosition = self:_GetTargetPosition()
	if not targetPosition then
		self:Finish()
		return
	end

	local offset = targetPosition - self.Mover:GetPosition()
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if distance > self.LoseDistance then
		self:Finish()
		return
	end

	if distance <= self.AttackDistance then
		self.Mover:Stop()
		self.Mover:FaceTowards(targetPosition)
		self.Mob:Attack(self.Params.target)
		return
	end

	self.Mover:FaceTowards(nil)
	self:NavigateTo(targetPosition, self.Speed, self.AttackDistance * 0.8)
end

return Aggressive
