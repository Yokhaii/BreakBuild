local NPC = {}
NPC.__index = NPC

function NPC.new(name: string, area: string, power: number, reward: number, boss: boolean)
	local self = setmetatable({}, NPC)

	self.name = name
	self.area = area
	self.power = power
	self.reward = reward
	self.boss = boss

	self.fightable = true
	self.beaten = false

	return self
end

function NPC:IsInArea(area: string): boolean
	return self.area == area
end

function NPC:LoadModel(): Model
	self.model = workspace:FindFirstChild(self.area):FindFirstChild(self.name)
	return self.model
end

function NPC:UnloadModel()
	self.model = nil
end

return NPC
