================================================================================
                    MOB SYSTEM ARCHITECTURE
                    Break & Build - Roblox Game
================================================================================

This document explains how mobs (passive animals now, hostile mobs and bosses
later) are built, spawned, moved, animated and tested.

================================================================================
1. OVERVIEW
================================================================================

  - Everything that decides or moves is on the SERVER (MobService + classes).
  - The CLIENT only shows mobs: it plays their animations (MobController + classes).
  - OOP: server and client mob classes inherit their own BaseMob, one subclass per
    mob (Cow, Sheep, Chicken). Unknown classes fall back to BaseMob.
  - Movement behaviors are separate modules; they all move the mob through ONE
    module, MobMover, whose only job is moving it.
  - Mobs have NO Humanoid: physics movement on a round CollidePart.

  Who does what:
    MobService       Spawn / Enable / Disable / Despawn, registry, update loop, dev API
    MobSpawnService  natural spawning only (rates, herds, caps, respawn delay)
    BaseMob (server) health, current behavior, decisions (OnDamaged, OnThink, Attack)
    Behaviors        where to go (Immobile, Patrolling, GoToPos, Fleeing, Aggressive)
    MobMover         physics: LinearVelocity + AlignOrientation
    MobController    client mob classes, N dev panel
    BaseMob (client) Idle / Walk / Run animations through the Animation package

================================================================================
2. KEY FILES
================================================================================

SERVER:
  src/server/Services/MobService.lua
  src/server/Services/MobSpawnService.lua
  src/server/Classes/Mobs/BaseMob.lua, Cow.lua, Sheep.lua, Chicken.lua
  src/server/Classes/Mobs/MobMover.lua
  src/server/Classes/Mobs/Behaviors/BaseBehavior.lua + one module per behavior
  src/server/Classes/Mobs/Navigation/Steering.lua      (raycast checks)
  src/server/Classes/Mobs/Navigation/MobRaycast.lua    (cached obstacle filter: no mobs, no players)
  src/server/Classes/Mobs/Navigation/Water.lua         (water detection, habitats, pathfinding label)
  src/server/Classes/Mobs/Navigation/PathFollower.lua  (PathfindingService)
  src/server/Modules/SpawnUtils.lua                    (findGroundPosition, findGroundAt)

CLIENT:
  src/client/Controllers/MobController.lua
  src/client/Classes/Mobs/BaseMob.lua, Cow.lua, Sheep.lua, Chicken.lua
  src/client/Roact/Applications/MobSpawner/            (dev panel)
  src/client/Rodux/Reducers/DevMobReducer.lua (+ Actions/DevMobActions.lua)
  src/client/Modules/Synchronization/DevMob.lua

SHARED:
  src/shared/Data/MobData/                mob definitions, one module per mob (Cow.lua...),
                                          all loaded by init.lua, keyed by file name
  src/shared/Config/MobConfig.lua         tags, attributes, think rate, movement, navigation
  src/shared/Config/MobSpawnConfig.lua    natural spawn tuning
  src/shared/AnimationDataFolder/Mobs/    <Mob>_Idle / _Walk / _Run animation data

ASSETS (place file only, NOT synced by Rojo, save the place):
  ReplicatedStorage.Assets.Mobs.<Mob>

3D SOURCES:
  3DModel/mobs.blend          Cow, Sheep, Chicken meshes
  3DModel/mob_animations.py   keyframes -> exports/animations/<Mob>_<Anim>.rbxmx

================================================================================
3. MOB MODEL
================================================================================

  <Mob> (Model, PrimaryPart = RootPart, ModelStreamingMode = Atomic)
  ├── RootPart      invisible 1x1x1, assembly root (RootPriority 127), no collision
  │   └── Motor6D "Body" -> Body
  ├── CollidePart   invisible Ball, the ONLY collider (ground + players),
  │                 friction 0 (FrictionWeight 100) -> same speed on every ground.
  │                 WeldConstraint to RootPart. Its bottom = the mob's feet.
  ├── Body          MeshPart, Motor6Ds to Head, Leg*, (Tail), (WingL/WingR)
  ├── Head, Leg*... MeshParts (Massless, CanCollide false)
  ├── details       MeshParts welded (WeldConstraint) to their rig part
  │                 (Cow: Spots/Udder -> Body, Snout/Eyes/Horns -> Head, Hoof* -> Leg*)
  └── AnimationController > Animator

  Part names are generic (Body, Head, LegFL...) so animations target them by name.
  Joint frames are aligned with the mob: +X right, +Y up, -Z forward.
  Legs: Quadrupeds LegFL/LegFR/LegBL/LegBR, Chicken LegL/LegR (L = -X).
  Colors are set on part.Color + SurfaceAppearance (stud normal map), like every
  stud asset (3DModel/3dStudModelCreation.md).

================================================================================
4. MOB DATA (MobData/<Mob>.lua)
================================================================================

  One module per mob, its file name = the mob type. MobData.GetMob("Cow"), MobData.Mobs.

  -- MobData/Cow.lua
  return {
    displayName = "Cow",
    modelPath = "ReplicatedStorage.Assets.Mobs.Cow",
    class = "Cow",               -- Classes/Mobs/<class> on server AND client
    hostility = "Passive",       -- Passive: flees when hurt | Hostile: chases attacker
    habitat = "Ground",          -- Ground: never enters water | Water: never leaves it | Any
    maxHealth = 10,
    walkSpeed = 3.5, runSpeed = 9.5,   -- tuned to the animation strides
    jumpHeight = 4.5,            -- highest ledge it steps up onto (higher = a wall)
    animations = { Idle = "Cow_Idle", Walk = "Cow_Walk", Run = "Cow_Run" },
    defaultBehavior = "Patrolling",
    patrol = { radius = 120, waitTime = { 4, 10 } },   -- targets random inside the radius
    flee = { distance = 30, duration = 6 },
  }

================================================================================
5. SERVER FLOW
================================================================================

SPAWN: MobService:Spawn(mobType, cframe, { enabled?, homePosition?, isDevSpawn? })
  1. Clone Assets.Mobs.<Mob>, name "<Mob>[<id>]" (brackets: the Animation package
     matches models by full-name substring)
  2. Pivot so the CollidePart bottom sits on cframe.Position, yaw from cframe
  3. Parent to Workspace.Mobs, RootPart:SetNetworkOwner(nil) (server physics)
  4. new <class>(id, mobType, data, model, options) -> starts Immobile (frozen)
  5. Tag "Mob" (clients build their classes from it), Enable() if options.enabled
  Signals: MobService.MobSpawned(mob), MobService.MobRemoved(mob, reason)

UPDATE LOOP (MobService, Heartbeat):
  - every frame:              mob:Step(dt)  -> MobMover:Step
  - MobConfig.ThinkRate (5/s): mob:Think(dt) -> OnThink, Behavior:Update, back to the
    default behavior when the current one Finished, MoveState attribute update

BEHAVIORS (Classes/Mobs/Behaviors), mob:SetBehavior(name, params):
  Immobile    stand still                       { faceTowards? }
  Patrolling  walk / wait loop around home or   { waypoints?, radius?, waitTime?, speedMode? }
              through fixed waypoints
  GoToPos     go to a position, then finish     { position, speedMode?, timeout?, onArrived?,
                                                  arriveDistance? }
  Fleeing     run away from a threat, finish    { threat (Player|BasePart|Vector3),
              when far enough / after duration    distance?, duration? }
  Aggressive  chase a player, Attack in range,  { target, loseDistance?, attackRange?, speedMode? }
              finish when lost
  Patrolling picks random points on Ground-tagged parts when its home is on the Ground
  (Outside), else on any walkable surface (dev spawns in a building zone).
  BaseBehavior:NavigateTo(goal, speed, arriveRadius?) = straight line when free, else PathFollower.
  A behavior only moves the mob through self.Mover.

MOBMOVER (only moves): MoveTo(position, speed, arriveRadius?), MoveInDirection(direction, speed),
  Stop(), FaceTowards(position?), HasArrived(), IsStuck(), GetPlanarSpeed().
  LinearVelocity (Plane X/Z, MaxForce = mass * MaxAcceleration) + AlignOrientation
  (upright, yaw = walk direction or look target). Gravity stays on Y.

  STEP-UP (ledges): the frictionless ball can't roll over an edge (and a hop can't clear
  it either: a big ball meets the edge ~1.3 studs before its center reaches it). So while
  moving, the mover compares the ground just ahead (radius + StepLookAhead + speed *
  StepLookAheadPerSpeed) with the ground UNDER the ball (not the ball's bottom, which
  sinks a little into the ground). If ahead is higher by MinLedgeHeight..jumpHeight, a
  second LinearVelocity (Line, Y only, "MoverStepVelocity") lifts the ball to that height
  + StepClearance before it touches the edge, and holds it until the ball's center is over
  the top (or a hold time for thin ledges). Disabled the rest of the time.
  Steering treats ledges up to jumpHeight as passable (walls are hit at jump height).
  Tested: 0.3 / 1 / 2.5 / 4 stud platforms climbed, 6 refused (cow, jumpHeight 4.5).

HABITAT (water, Navigation/Water.lua):
  Water = the parts tagged "Water" in the place (Workspace.GeneratedFloor "Water Block", saved
  in the place, not Rojo). They are CanCollide/CanQuery false and sit under the grass (top
  y=3, river beds at y=0, land at y>=5), so raycasts go through them: Water.IsInWater tests
  whether a point is inside a tagged part's box (the ground point + 0.5 up).
  mob.Habitat (MobData habitat, default "Ground") is enforced everywhere a mob picks a way:
    - Steering.IsDirectionClear: ground ahead outside the habitat = blocked (Fleeing,
      Patrolling), unless the mob already stands outside it (it may always walk back)
    - Steering.HasLineOfSight: samples the ground every HabitatCheckSpacing along the line;
      crossing water -> NavigateTo falls back to pathfinding
    - PathFollower: Costs = MobConfig.HabitatPathCosts[habitat]; Water.Init (MobService
      KnitInit) adds a PathfindingModifier (Label "Water") to every water part, so ground
      mob paths go around rivers (math.huge cost)
    - Steering.RandomGroundPoint (patrol targets) and MobSpawnService (herd centers and
      members) only accept points in the habitat
  A future water mob: habitat = "Water" (it never leaves the water). Its spawn and patrol
  will need water points (herd centers are picked on Ground-tagged parts today).
  Tested: river crossing (path around), flee toward a river, 34 mobs x 60s: never in water.

DECISIONS (BaseMob, override in subclasses):
  OnThink(dt)        e.g. a hostile mob looking for players to set Aggressive
  OnDamaged(source)  default: Passive -> Fleeing from source, Hostile -> Aggressive
  Attack(target)     called by Aggressive in range (no-op for now)
  TakeDamage(amount, source) -> Health attribute, Damaged signal, Die at 0
  Die -> Died signal -> MobService despawns (fighting system: drops go here)
  MobService:GetMobFromInstance(part) finds the mob of a hit part.

================================================================================
6. NATURAL SPAWNING (MobSpawnService, MobSpawnConfig)
================================================================================

  Every SpawnInterval (5s), up to MaxHerdsPerPass (2) herds:
    - weighted pick among types below maxAlive and not blocked
    - herd center: SpawnUtils.findGroundPosition in a Workspace.Outside boundary part
      (Ground-tagged surface), >= MinHerdSeparation from other herds,
      >= MinPlayerDistance from players, nothing solid on the spot
    - herdSize members within HerdRadius, enabled, homePosition = herd center
  A natural mob removed (died, despawned) blocks its type for RespawnDelay (45s).
  Caps: Cow 12 (herds 2-4), Sheep 12 (2-4), Chicken 10 (2-3).
  MobSpawnService:SetEnabled(bool) toggles it (mobs alive stay).

================================================================================
7. CLIENT & ANIMATIONS
================================================================================

  MobController creates a client class per streamed model with the "Mob" tag and
  destroys it when the model leaves (streaming out / despawn).
  Client BaseMob listens to the MoveState attribute ("Idle" | "Walk" | "Run") and
  plays data.animations[state] with the Animation package (Animation:PlayAnim /
  StopAnim on the model). Mob animations are ALWAYS played through the Animation
  package, never with a raw Animator / AnimationTrack.
  Animation data: Shared.AnimationDataFolder.Mobs.<Mob>_<Anim> (Priority Idle for
  Idle, Movement for Walk/Run, Loop, FadeTime 0.2).

  NEW / CHANGED ANIMATIONS:
    1. Edit ANIMATIONS in 3DModel/mob_animations.py, run it
    2. python3 3DModel/export_to_roblox.py exports/animations/<Mob>_<Anim>.rbxmx
    3. Put the new id in the AnimationData module
    If you change walkSpeed / runSpeed, retune the stride (swing, period) too.

================================================================================
8. DEV PANEL (N key, dev players and Studio only)
================================================================================

  CurrentFrame "MobSpawner" (right side panel):
    - per mob: "+1" / "+5" spawn FROZEN mobs in a row in front of you, facing you
    - Enable frozen / Freeze all
    - Flee from me / Come to me (GoToPos, run) / Chase me (Aggressive), mobs
      within 120 studs
    - Hit nearest: 1 damage to the closest mob (tests OnDamaged / death)
    - Despawn dev / Despawn all, Natural spawning ON / OFF
  Server checks every call: RunService:IsStudio() or InventoryService:IsDevPlayer.
  Counts: MobService.DevStateChanged -> Synchronization/DevMob -> DevMobReducer.

================================================================================
9. ADDING A NEW MOB
================================================================================

  1. Model it in Blender (3DModel/mobs.blend, stud pipeline), one object per color
     region and per moving part; export + upload (3dStudModelCreation.md Phase 4)
  2. In Studio, build Assets.Mobs.<Mob> as in section 3 (RootPart, CollidePart,
     generic part names, Motor6Ds at the joints, AnimationController > Animator,
     ModelStreamingMode Atomic)
  3. Add its animations to 3DModel/mob_animations.py (JOINTS + ANIMATIONS), upload,
     add the AnimationData modules in Shared.AnimationDataFolder.Mobs
  4. Add MobData/<Mob>.lua (speeds matching the animation strides, jumpHeight)
  5. Server class src/server/Classes/Mobs/<Mob>.lua and client class
     src/client/Classes/Mobs/<Mob>.lua (copy Cow.lua), override hooks as needed
  6. Natural spawning: add it to MobSpawnConfig.Mobs
  7. Test with the N panel

  HOSTILE MOB: hostility = "Hostile", override OnThink (find a player in range ->
  SetBehavior("Aggressive", { target = player })) and Attack(target).
  BOSS: own class; phases in OnThink / OnDamaged, Patrolling with waypoints, etc.

================================================================================
END OF DOCUMENT
================================================================================
