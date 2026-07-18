================================================================================
                    BREAKING SYSTEM ARCHITECTURE
                    Break & Build - Roblox Game
================================================================================

This document explains how the breaking system works in this project.
Read this to understand how blocks, trees, ores, and structures are broken
by players using tools or bare hands.

================================================================================
1. OVERVIEW
================================================================================

The breaking system allows players to:
- Break blocks in their BuildingArea (personal)
- Break trees in the Outside zone (global/shared)
- Break rocks in the GlobalBreakingArea (global/shared, cyclic reset)
- Break completed structures with tools

Two categories of breakables:
  1. Per-Player Breakables = Only visible/breakable by one player (building blocks)
  2. Global Breakables    = Shared world objects anyone can break (trees, rocks)

================================================================================
2. KEY FILES
================================================================================

SERVER:
  src/server/Services/BreakingService.lua
    - Central hub for ALL breaking mechanics
    - Validates tool tier vs material tier
    - Tracks breaking progress per-player (Heartbeat loop)
    - Gives drops to inventory on completion
    - Fires signals to clients

  src/server/Services/GlobalBreakingAreaService.lua
    - Procedurally generated shared mining zone
    - 50x50 grid, 4x4x4 blocks, cyclic 8-minute reset
    - Perlin noise terrain with biomes
    - Underground layer reveal system

CLIENT:
  src/client/Controllers/BreakingController.lua
    - Raycast detection of breakables under cursor
    - Preview highlight and billboard label
    - Mining animation, shake effect, particle VFX
    - Break burst particles on completion

SHARED:
  src/shared/Config/BreakingConfig.lua
    - BreakRange, BareHandBreakSpeed, BareHandToolTier

  src/shared/Config/GlobalBreakingConfig.lua
    - GridSize, BlockSize, CycleDuration, MaxDepth, BatchSize

  src/shared/Data/MaterialData.lua
    - Material definitions (breakTime, requiredTier, color, rarity)
    - Tool tier hierarchy
    - Spawn weights for random generation

================================================================================
3. DAMAGE CALCULATION
================================================================================

FORMULA:
  breakTime = baseBreakTime / toolBreakSpeed

Where:
  - baseBreakTime = Material's breakTime property (from MaterialData)
  - toolBreakSpeed = Tool's breakSpeed multiplier

EXAMPLES:
  Stone (2.0s base) with Bare Hand (0.25 speed) = 2.0 / 0.25 = 8 seconds
  Stone (2.0s base) with WoodenPickaxe (1.0 speed) = 2.0 / 1.0 = 2 seconds
  Diamond (4.0s base) with IronPickaxe (2.0 speed) = 4.0 / 2.0 = 2 seconds

TOOL TIER HIERARCHY:
  Hand (0) < Wood (1) < Stone (2) < Iron (3) < Gold (4) < Diamond (5)

  Tool must have tier >= material's requiredTier to break it.

BARE HAND DEFAULTS:
  toolTier = "Hand"
  breakSpeed = 0.25 (4x slower than normal tools)

================================================================================
4. MATERIAL PROPERTIES
================================================================================

Each material in MaterialData has:
  {
    displayName = "Stone",
    rarity = "Common",           -- Common/Uncommon/Rare/Very Rare/Crafted
    color = Color3.new(...),     -- Particle color
    breakTime = 2.0,             -- Base seconds to break
    requiredTier = "Hand",       -- Minimum tool tier
    unbreakable = false,         -- Optional, makes permanently unbreakable
  }

MATERIAL BREAK TIMES:
  Sand: 0.8s | Dirt: 1.0s | Log: 1.5s | Stone: 2.0s | Structure: 2.0s
  RawGold: 2.5s | RawIron: 3.0s | RawDiamond: 4.0s | Bedrock: unbreakable

SPAWN WEIGHTS (GlobalBreakingArea random generation):
  Dirt: 25% | Stone: 25% | Sand: 15% | Log: 15%
  RawIron: 10% | RawGold: 7% | RawDiamond: 3%

================================================================================
5. BREAKING FLOW
================================================================================

CLIENT SIDE (BreakingController):
  1. Raycast from camera through mouse (1000 studs, excludes character)
  2. Find instance with BreakableId + PlayerId StringValues
  3. Check range <= 24 studs (BreakRange)
  4. Show white outline highlight + billboard with material name
  5. On mouse down: call BreakingService:StartBreaking(breakableId)
  6. On mouse up or out of range: call BreakingService:StopBreaking()

SERVER SIDE (BreakingService):
  1. StartBreaking(breakableId) receives request
  2. Look up breakable (per-player OR global table)
  3. Validate tool tier >= material requiredTier
  4. Calculate breakTime (formula above)
  5. Create BreakingState entry, fire BreakingStarted signal
  6. Every Heartbeat, update progress:
     elapsed = currentTime - startTime
     progress = clamp(elapsed / totalBreakTime, 0, 1)
  7. Per-frame validation: player valid, breakable exists, tool still equipped
  8. If any validation fails: stop breaking
  9. When progress >= 1:
     - Destroy part
     - Give item via InventoryService:AddItem()
     - Call optional onBroken callback
     - Fire BreakableDestroyed (server) and BreakableBroken (client)

GLOBAL BREAKABLE SPECIAL CASE:
  - When one player finishes breaking a global block, ALL other players
    currently breaking it get stopped
  - Only the finishing player receives the drop

================================================================================
6. DATA STRUCTURES
================================================================================

RuntimeBreakable:
  {
    id = "global_5_2_3",          -- Unique identifier
    materialType = "Stone",       -- For tier/time lookup
    dropItem = "Stone",           -- Item name given on break
    dropAmount = 1,               -- Quantity dropped
    position = Vector3,           -- World position
    part = Instance,              -- Part/Model to destroy
    customBreakTime = nil,        -- Optional override (trees use this)
    onBroken = nil,               -- Optional callback (trees use this)
  }

BreakingState (per-player):
  {
    breakableId = "global_5_2_3",
    startTime = os.clock(),
    totalBreakTime = 2.0,
    toolConfig = { breakSpeed, toolTier, ... },
  }

Breakable Part Structure (in workspace):
  Part/Model with child values:
    BreakableId (StringValue)     -- Unique identifier
    PlayerId (IntValue)           -- Owner (0 = global, any player can break)
    MaterialType (StringValue)    -- Material name

================================================================================
7. REGISTERING BREAKABLES
================================================================================

Per-Player (used by BuildingService for structures):
  BreakingService:RegisterBreakable(player, breakableId, {
    materialType, dropItem, dropAmount, position, part,
    customBreakTime?, onBroken?
  })

Global (used by TreeService, GlobalBreakingAreaService):
  BreakingService:RegisterGlobalBreakable(breakableId, {
    materialType, dropItem, dropAmount, position, part,
    customBreakTime?, onBroken?
  })

Unregistering:
  BreakingService:UnregisterBreakable(player, breakableId)
  BreakingService:UnregisterGlobalBreakable(breakableId)

================================================================================
8. GLOBAL BREAKING AREA
================================================================================

GRID SYSTEM:
  - 50x50 blocks (GridSizeX, GridSizeZ)
  - Block size: 4x4x4 studs
  - Total area: 200x200 studs
  - Underground: up to 10 layers deep

BLOCK ID FORMAT:
  "global_" .. x .. "_" .. y .. "_" .. z
  Parsing: string.match(rest, "^(%-?%d+)_(%-?%d+)_(%-?%d+)$")

TERRAIN GENERATION:
  - Perlin noise heightmap (scale 0.13, amplitude 10)
  - Random biome selection per cycle
  - Material layering based on BiomeData
  - Edge fade (5 blocks from boundary)

UNDERGROUND REVEAL:
  - Starts with 3 layers placed
  - When block at lowestRevealedY is broken → reveal next layer below
  - Max depth: 10 layers
  - Bedrock floor (unbreakable) at bottom

CYCLE RESET:
  - Every 480 seconds (8 minutes)
  - Destroys all blocks, generates new terrain with new seed
  - Random biome, timer broadcast to all players

PERFORMANCE:
  - Batch placement: 400 blocks per heartbeat (prevents frame freezes)
  - Queue system for gradual generation

================================================================================
9. CLIENT VISUAL EFFECTS
================================================================================

PREVIEW HIGHLIGHT (hovering):
  - White outline (FillTransparency=1, OutlineTransparency=0.7)
  - Billboard above object showing material name

MINING ANIMATION:
  - Plays "Humanoid_Mining" animation while mouse down + can break
  - Stops when released or can't break

SHAKE EFFECT:
  - Y-axis shake: amplitude ±0.05 studs
  - Frequency: 2 Hz base → 10 Hz as progress increases
  - Formula: frequency = 2 + (10 - 2) * progress

BREAKING PARTICLES (during):
  - Cloned from ReplicatedStorage.Assets.VFX.Breaking.4x4
  - Emitters: Emit_50, Square_50, Square_200
  - Color matches material's color property
  - Rate scales from 1/5 base to full based on progress

BREAK BURST (on completion):
  - Invisible 3x3x3 part at break position
  - 50 particle burst using Emit_50 template
  - Cleanup after 2 seconds

================================================================================
10. SIGNALS / EVENTS
================================================================================

Client Signals (from BreakingService):
  - BreakablesInitialized(allBreakableData)
  - BreakableRegistered(breakableData)
  - BreakableUnregistered(breakableId)
  - BreakingStarted(breakableId)
  - BreakingProgress(breakableId, progress)   -- Fired every heartbeat
  - BreakingStopped(breakableId)
  - BreakableBroken(breakableId, dropItem, position)

Server Signal:
  - BreakingService.BreakableDestroyed:Fire(player, breakableId, dropItem, position)
    Listened to by GlobalBreakingAreaService and TreeService

Global Breaking Area Signals:
  - CycleReset (all clients)
  - CycleTimeRemaining(secondsRemaining)

================================================================================
11. TOOL DETECTION
================================================================================

BreakingService:getEquippedToolConfig(player):
  1. Check slot 0 (Hammer) first
  2. Check hotbar slots for equipped tool
  3. Fall back to bare hand config if nothing equipped

Tool Config Properties:
  {
    breakSpeed = 1.0,         -- Multiplier (higher = faster)
    toolTier = "Stone",       -- Tier level
    isBreakingTool = true,    -- Must be true
    canBreakAll = false,      -- Bypass tier check if true
  }

================================================================================
END OF DOCUMENT
================================================================================
