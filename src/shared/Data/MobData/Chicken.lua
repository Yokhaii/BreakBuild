return {
	displayName = "Chicken",
	modelPath = "ReplicatedStorage.Assets.Mobs.Chicken",
	class = "Chicken",
	hostility = "Passive",
	habitat = "Ground",
	maxHealth = 4,
	walkSpeed = 4,
	runSpeed = 10,
	jumpHeight = 4.5,
	animations = {
		Idle = "Chicken_Idle",
		Walk = "Chicken_Walk",
		Run = "Chicken_Run",
	},
	defaultBehavior = "Patrolling",
	patrol = {
		radius = 80,
		waitTime = { 2, 6 },
	},
	flee = {
		distance = 25,
		duration = 5,
	},
}
