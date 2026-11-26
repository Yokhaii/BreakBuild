return {
	displayName = "Cow",
	modelPath = "ReplicatedStorage.Assets.Mobs.Cow",
	class = "Cow", -- Server/client class module name (falls back to BaseMob)
	hostility = "Passive", -- Passive: flees when hurt | Hostile: chases its attacker
	habitat = "Ground", -- "Ground": never enters water | "Water": never leaves it | "Any"
	maxHealth = 10,
	walkSpeed = 3.5,
	runSpeed = 9.5,
	jumpHeight = 4.5, -- Highest ledge (studs) the mob steps up onto; higher = a wall
	animations = {
		Idle = "Cow_Idle",
		Walk = "Cow_Walk",
		Run = "Cow_Run",
	},
	defaultBehavior = "Patrolling",
	patrol = {
		radius = 120, -- Studs around the mob's home position (targets are random inside it)
		waitTime = { 4, 10 }, -- Seconds idling between two walks
	},
	flee = {
		distance = 30, -- Studs to put between the mob and the threat
		duration = 6, -- Max seconds of fleeing
	},
}
