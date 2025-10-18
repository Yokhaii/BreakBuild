local Pet = {}
Pet.__index = Pet

function Pet.new(name: string, power: number, rarity: string, movement: "Fly" | "Walk")
	local self = setmetatable({}, Pet)

	self.Name = name
	self.Power = power
	self.Rarity = rarity
	self.Movement = movement
	self.Speed = 16

	return self
end

return Pet
