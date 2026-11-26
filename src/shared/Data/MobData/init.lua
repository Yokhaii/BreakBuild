--[[
	MobData
	Definition of every mob type, one module per mob in this folder (Cow.lua, Sheep.lua...).
	Every child module is loaded automatically, keyed by its name: to add a mob, add a file.
	Format: see .claude/mob-system-instructions.md section 4.

	walkSpeed / runSpeed are tuned to the Walk / Run animation strides
	(3DModel/mob_animations.py) so the feet don't slide.
]]

local MobData = {}

MobData.Mobs = {}
for _, module in ipairs(script:GetChildren()) do
	if module:IsA("ModuleScript") then
		MobData.Mobs[module.Name] = require(module)
	end
end

function MobData.GetMob(mobType: string)
	return MobData.Mobs[mobType]
end

return MobData
