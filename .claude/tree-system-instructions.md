================================================================================
                    TREE SYSTEM ARCHITECTURE
                    Break & Build - Roblox Game
================================================================================

This document explains how the tree system works in this project.
Read this to understand how trees spawn, are broken, drop items,
and respawn.

================================================================================
1. OVERVIEW
================================================================================

The tree system provides:
- Procedural tree spawning in the Outside zone
- Multiple tree types with weighted random selection
- Trees as global breakables (any player can chop)
- Log drops from individual tree parts
- Full tree destruction when all logs broken
- Automatic respawn after delay

Trees are NOT per-player. They exist in the shared world.

================================================================================
2. KEY FILES
================================================================================

SERVER:
  src/server/Services/TreeService.lua
    - Tree spawning, lifecycle, and respawn
    - Log break tracking and tree destruction
    - Uses SpawnUtils for ground detection

  src/server/Modules/SpawnUtils.lua
    - findGroundPosition() raycast utility
    - Weighted random selection

CLIENT:
  src/client/Controllers/TreeController.lua
    - Currently a placeholder (no special tree client logic)
    - All visual feedback handled by BreakingController

SHARED:
  src/shared/Data/TreeData.lua
    - Tree type definitions (breakTime, model path, tier)

  src/shared/Config/TreeSpawnConfig.lua
    - All spawn tuning parameters

================================================================================
3. TREE TYPES
================================================================================

Defined in TreeData.lua:

  Spruce:
    breakTime = 1.5s per log
    model = "ReplicatedStorage.Assets.Tree.Spruce"
    requiredTier = "Wood"
    spawnWeight = 70

  FirTree:
    breakTime = 2.0s per log
    model = "ReplicatedStorage.Assets.Tree.FirTree"
    requiredTier = "Wood"
    spawnWeight = 30

  ApricotTree:
    breakTime = 2.0s per log
    model = "ReplicatedStorage.Assets.Tree.ApricotTree"
    requiredTier = "Wood"
    spawnWeight = 10

  CherryBlossomTree:
    breakTime = 2.0s per log
    model = "ReplicatedStorage.Assets.Tree.CherryBlossomTree"
    requiredTier = "Wood"
    spawnWeight = 20

ALL trees:
  - Drop "Log" item (1 per broken log part)
  - Require minimum "Wood" tool tier
  - Registered as "Log" material type with BreakingService

================================================================================
4. SPAWN CONFIGURATION
================================================================================

TreeSpawnConfig values:
  MaxTrees = 128              -- Maximum trees alive at once
  SpawnInterval = 5s          -- How often fillTrees() runs
  RespawnDelay = 30s          -- Wait after tree dies before respawn eligible
  MinTreeSeparation = 8       -- Minimum studs between trees
  SpawnHeightOffset = 2       -- Studs above ground to place tree
  OutsideFolderName = "Outside"
  BoundaryPartName = "Outside"
  GroundTag = "Ground"        -- CollectionService tag on ground parts

================================================================================
5. SPAWN MECHANISM
================================================================================

INITIAL SPAWN:
  - All trees spawn 2 seconds after server starts (KnitStart)
  - fillTrees() called to populate up to MaxTrees

CONTINUOUS MAINTENANCE:
  - fillTrees() called every SpawnInterval (5 seconds)
  - Fills empty slots up to MaxTrees count

SPAWN ALGORITHM (per tree):
  1. Pick random boundary part from Outside folder
  2. Pick random XZ point inside boundary part's bounding box
  3. Raycast downward from 500 studs above:
     - Only hits parts tagged with "Ground" (CollectionService)
     - Up to 20 attempts per tree
  4. Check MinTreeSeparation (8 studs) from all existing trees
  5. If valid: pick weighted random tree type
  6. Clone model, position at hit + SpawnHeightOffset (2 studs up)
  7. Rotate randomly: 0°, 90°, 180°, or 270°

TREE NAMING:
  "WorldTree_world_tree_{INDEX}" where INDEX increments monotonically

================================================================================
6. LOG REGISTRATION
================================================================================

Each tree model is scanned for breakable log parts:
  - Parts/Models named matching config's breakablePartName ("Log")
  - Both Model objects (with PrimaryPart) and BasePart objects detected
  - Avoids double-counting Model + its PrimaryPart

Each log receives StringValues:
  - BreakableId: "world_tree_{treeIndex}_log_{logIndex}"
  - PlayerId: 0 (global, any player can break)
  - MaterialType: "Log"

Registered with BreakingService:
  BreakingService:RegisterGlobalBreakable(breakableId, {
    materialType = "Log",
    dropItem = "Log",
    dropAmount = 1,
    position = logPosition,
    part = logModel,
    customBreakTime = treeType.breakTime,  -- 1.5s or 2.0s
    onBroken = onLogBrokenCallback,
  })

================================================================================
7. BREAKING FLOW
================================================================================

Trees use the unified BreakingService (see breaking-system-instructions.txt):

  1. Client raycasts, finds log with BreakableId + PlayerId=0
  2. Client shows highlight + billboard ("Log")
  3. Player holds mouse → BreakingService:StartBreaking(breakableId)
  4. Server calculates: customBreakTime / toolBreakSpeed
  5. Progress tracked on Heartbeat
  6. On completion:
     - Log part destroyed
     - 1x "Log" item added to player inventory
     - onBroken callback fires in TreeService

================================================================================
8. TREE DESTRUCTION & RESPAWN
================================================================================

PER-LOG TRACKING:
  liveTrees[treeId] = {
    model = treeModel,
    brokenLogs = 0,
    logCount = totalLogsInTree,
  }

DESTRUCTION:
  When brokenLogs >= logCount:
    - Entire tree model destroyed
    - Tree ID added to respawnQueue with timestamp: os.time() + RespawnDelay

RESPAWN:
  - processRespawnQueue() checks every SpawnInterval (5 seconds)
  - When os.time() >= respawnTimestamp: ID removed from queue
  - Normal fillTrees() loop fills the empty slot on next cycle
  - New tree spawns at a new random valid position (not same spot)

================================================================================
9. CLIENT VISUAL EFFECTS
================================================================================

All handled by BreakingController (no tree-specific client code):

HOVERING:
  - White outline highlight
  - Billboard with "Log" label

BREAKING:
  - Mining animation (Humanoid_Mining)
  - Shake effect (2-10 Hz based on progress)
  - Wood-colored particles (from MaterialData "Log" color)

COMPLETION:
  - 50-particle burst at log position
  - Log part disappears instantly

NOTE: No falling tree animation currently implemented.

================================================================================
10. SIGNALS / EVENTS
================================================================================

TreeService uses BreakingService signals:
  - BreakingService.BreakableDestroyed → triggers log count increment
  - No tree-specific signals exposed to clients

BreakingService Client Signals (for tree logs):
  - BreakableRegistered (when tree spawns, logs become breakable)
  - BreakableUnregistered (when tree despawns)
  - BreakingStarted/Progress/Stopped (during chopping)
  - BreakableBroken (log destroyed)

================================================================================
11. ADDING A NEW TREE TYPE
================================================================================

To add a new tree type:

1. Add entry to src/shared/Data/TreeData.lua:
   {
     name = "NewTree",
     breakTime = 2.0,               -- Seconds per log
     modelPath = "Assets.Tree.NewTree",
     requiredTier = "Wood",         -- Or higher
     breakablePartName = "Log",     -- Name of breakable parts in model
     spawnWeight = 20,              -- Relative spawn chance
   }

2. Create tree model in ReplicatedStorage.Assets.Tree.NewTree:
   - Model with PrimaryPart set
   - Child parts/models named "Log" for breakable logs
   - Each Log must have a PrimaryPart if it's a Model

3. Optionally adjust TreeSpawnConfig for balance:
   - MaxTrees, SpawnInterval, RespawnDelay

No code changes needed in TreeService or BreakingService.

================================================================================
12. KEY TECHNICAL DETAILS
================================================================================

GROUND DETECTION:
  - Uses CollectionService tag "Ground" on terrain parts
  - Raycast starts 500 studs above boundary part
  - Only landing surfaces tagged "Ground" are valid

SEPARATION CHECK:
  - Euclidean distance between new position and ALL existing tree positions
  - Must exceed MinTreeSeparation (8 studs)
  - Up to 20 retries before giving up for that spawn attempt

GLOBAL BREAKABLE BEHAVIOR:
  - Any player can break any tree log (PlayerId = 0)
  - If multiple players break same log simultaneously:
    - First to complete gets the drop
    - Others get stopped (BreakingStopped signal)
  - Each log is independent (breaking one doesn't affect others)

================================================================================
END OF DOCUMENT
================================================================================
