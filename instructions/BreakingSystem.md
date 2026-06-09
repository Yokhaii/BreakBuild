# Breaking System

## Overview
The breaking system handles resource gathering by allowing players to break objects (blocks, logs, etc.) to collect materials. It's a unified system where any spawner can register breakables.

## Key Components

### Server
- **BreakingService** (`src/server/Services/BreakingService.lua`): Central service managing break state, validation, and completion
- **BreakingAreaService** (`src/server/Services/BreakingAreaService.lua`): Spawns random blocks in BreakingZone
- **TreeService** (`src/server/Services/TreeService.lua`): Spawns trees with breakable logs

### Client
- **BreakingController** (`src/client/Controllers/BreakingController.lua`): Handles raycasting, input, visual feedback, and animations

## Breaking Zone
- **Location**: `Workspace.BreakingZone`
- **Grid**: 16x16 blocks on 2-stud spacing
- **Floors**: 3 levels at Y positions +2, +6, +10
- **Capacity**: Up to 768 blocks total

## Material & Tool System

### Tool Properties
```lua
{
    isBreakingTool = true,
    breakSpeed = 1.5,        -- Multiplier (higher = faster)
    toolTier = "Stone",      -- Determines what can be broken
    canBreakAll = false      -- Bypass tier check (for testing)
}
```

### Material Tiers (lowest to highest)
1. **Hand** - Bare hands can break
2. **Wood** - Requires wooden tools or better
3. **Stone** - Requires stone tools or better
4. **Iron** - Requires iron tools or better
5. **Gold** / **Diamond** - Higher tiers

### Break Time Calculation
```
actualBreakTime = baseBreakTime / toolBreakSpeed
```

## Breakable Registration
Spawner services register objects with BreakingService:
```lua
BreakingService:RegisterBreakable({
    materialType = "Stone",
    dropItem = "Stone",
    dropAmount = 1,
    position = Vector3,
    part = BasePart,
    customBreakTime = 2.0  -- Optional
})
```

## Breaking Flow
1. **Detection**: Client raycasts to find breakable (looks for `BreakableId` attribute)
2. **Validation**: Must be within range (24 studs), correct mode (Break), valid tool tier
3. **Start**: Client sends `StartBreaking(breakableId)` to server
4. **Progress**: Server updates progress each heartbeat, client shows visual feedback
5. **Completion**:
   - Part destroyed
   - Item added to inventory
   - `BreakableDestroyed` event fired
   - Spawner handles respawn

## Visual Feedback
- **Hover**: White outline highlight + material name billboard
- **Breaking**: Mining animation, shake effect (intensifies with progress), particle VFX
- **Complete**: Burst particle effect at break position

## Respawning
- **Breaking Blocks**: Spawn every 5 seconds, random material from pool
- **Trees**: Full respawn when all logs broken, partial respawn takes 10x longer
