--[=[
	Fleeing - run away from a threat, then finish
	Runs straight away from it, turning around walls and cliffs (Steering).
	params:
	  threat    Player | BasePart | Vector3   what to run from (required)
	  distance  number?   finish once this far away (default: mob data flee.distance)
	  duration  number?   finish after this many seconds (default: flee.duration)
]=]

local BaseBehavior = require(script.Parent.BaseBehavior)
local Steering = require(script.Parent.Parent.Navigation.Steering)

local Fleeing = {}
Fleeing.__index = Fleeing
setmetatable(Fleeing, { __index = BaseBehavior })

function Fleeing.new(mob, params)
	local self = BaseBehavior.new(mob, params)
	setmetatable(self, Fleeing)

	local flee = mob.Data.flee or {}
	self.Distance = self.Params.distance or flee.distance or 30
	self.TimeLeft = self.Params.duration or flee.duration or 6
	self.Speed = mob:GetSpeed("Run")
	return self
end

-- Current position of the threat (nil once it is gone)
function Fleeing:_GetThreatPosition(): Vector3?
	local threat = self.Params.threat
	if typeof(threat) == "Vector3" then
		return threat
	elseif typeof(threat) == "Instance" then
		if threat:IsA("Player") then
			local character = threat.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			return root and root.Position
		elseif threat:IsA("BasePart") and threat.Parent then
			return threat.Position
		end
	end
	return nil
end

function Fleeing:Update(dt: number)
	self.TimeLeft -= dt
	local threatPosition = self:_GetThreatPosition()
	if self.TimeLeft <= 0 or not threatPosition then
		self:Finish()
		return
	end

	local away = self.Mover:GetPosition() - threatPosition
	away = Vector3.new(away.X, 0, away.Z)
	if away.Magnitude >= self.Distance then
		self:Finish()
		return
	end
	if away.Magnitude < 1e-3 then
		local angle = math.random() * 2 * math.pi
		away = Vector3.new(math.cos(angle), 0, math.sin(angle))
	end

	local direction = Steering.FindClearDirection(self.Mob, away)
	if direction then
		self.Mover:MoveInDirection(direction, self.Speed)
	else
		self.Mover:Stop() -- cornered
	end
end

return Fleeing
