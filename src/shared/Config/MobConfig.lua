local MobConfig = {}

-- Workspace folder holding every live mob model
MobConfig.MobsFolderName = "Mobs"

-- CollectionService tag on every live mob model (the client builds its mob classes from it)
MobConfig.MobTag = "Mob"

-- Model attributes replicated to clients
MobConfig.Attributes = {
	MobId = "MobId",
	MobType = "MobType",
	MoveState = "MoveState", -- "Idle" | "Walk" | "Run" (the client plays the matching animation)
	Enabled = "Enabled", -- false while frozen (dev spawn)
	Health = "Health",
	MaxHealth = "MaxHealth",
}

-- AI decisions (behaviors) run this many times per second; movement runs every Heartbeat
MobConfig.ThinkRate = 5

-- Movement (MobMover)
MobConfig.MaxAcceleration = 60 -- studs/s² the LinearVelocity can apply
MobConfig.TurnResponsiveness = 12 -- AlignOrientation responsiveness
MobConfig.ArriveRadius = 1.5 -- studs: a move target closer than this is reached
MobConfig.SlowDownRadius = 4 -- studs: start slowing down this close to a move target
MobConfig.StuckSpeedRatio = 0.2 -- below this ratio of the asked speed the mob counts as stuck
MobConfig.StuckTime = 1.5 -- seconds of being stuck before IsStuck() returns true

-- Step-up (MobMover): the frictionless ball can't roll over edges, so a moving mob probes the
-- ground just ahead and is lifted onto anything higher than the ground under it, up to its
-- data jumpHeight, before the ball touches the edge
MobConfig.MinLedgeHeight = 0.2 -- studs: lower differences (seams, sinking) are ignored
MobConfig.StepClearance = 0.15 -- studs the ball is lifted above the ledge
MobConfig.StepLookAhead = 0.5 -- studs past the ball's front where the ground is probed...
MobConfig.StepLookAheadPerSpeed = 0.15 -- ...plus this many studs per stud/s of speed
MobConfig.StepSpeed = 25 -- max studs/s the ball rises
MobConfig.StepGain = 15 -- rise speed (studs/s) per stud still to climb
MobConfig.GroundedDistance = 0.3 -- studs under the ball that still count as on the ground
MobConfig.DefaultJumpHeight = 1 -- when the mob data has no jumpHeight

-- Navigation (Steering / PathFollower)
MobConfig.LookAheadDistance = 4 -- studs checked in front of the mob for obstacles
MobConfig.MaxDropHeight = 6 -- studs: deeper drops in front of the mob count as a wall
MobConfig.GroundTag = "Ground"
MobConfig.WaterTag = "Water" -- CollectionService tag on water parts (also the pathfinding label)
MobConfig.HabitatCheckSpacing = 3 -- studs between ground checks along a straight move

-- Habitats (MobData habitat): "Ground" never enters water, "Water" never leaves it, "Any"
-- goes anywhere. Pathfinding costs per habitat (labels from PathfindingModifiers)
MobConfig.HabitatPathCosts = {
	Ground = { Water = math.huge },
	Water = {},
	Any = {},
}
MobConfig.PathRecomputeInterval = 1 -- seconds between path recomputes while following a moving target
MobConfig.WaypointReachedDistance = 2 -- studs

-- Dev spawn: distance in front of the player
MobConfig.DevSpawnDistance = 10

return MobConfig
