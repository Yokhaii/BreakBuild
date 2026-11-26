return {
	displayName = "Sheep",
	modelPath = "ReplicatedStorage.Assets.Mobs.Sheep",
	class = "Sheep",
	hostility = "Passive",
	habitat = "Ground",
	maxHealth = 8,
	walkSpeed = 3.7,
	runSpeed = 10,
	jumpHeight = 4.5,
	animations = {
		Idle = "Sheep_Idle",
		Walk = "Sheep_Walk",
		Run = "Sheep_Run",
	},
	defaultBehavior = "Patrolling",
	patrol = {
		radius = 100,
		waitTime = { 3, 9 },
	},
	flee = {
		distance = 30,
		duration = 6,
	},
}
