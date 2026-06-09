# Building System

## Overview
The building system allows players to place blocks in a designated BuildingZone. It uses a grid-based placement system with support for multiple block sizes.

## Key Components

### Server
- **BuildingService** (`src/server/Services/BuildingService.lua`): Handles block placement validation, persistence, and world creation

### Client
- **BuildingController** (`src/client/Controllers/BuildingController.lua`): Handles placement preview, raycasting, and user input

## Grid System
- **Grid Size**: 2 studs
- **Block Sizes**: Supports both 4x4x4 and 2x2x2 blocks
- **Snapping**: Blocks snap differently based on size:
  - 4x4x4 blocks snap to even positions (2, 4, 6...)
  - 2x2x2 blocks snap to odd positions (1, 3, 5...)

## Building Area
- **Location**: `Workspace.BuildingZone.BuildingArea`
- **Size**: 64x64x64 studs
- **Bounds**: X/Z from -32 to +32, Y from 0 to 64 (relative to area origin)
- **Origin**: Floor level is at `BuildingArea.Position.Y - 32`

## Placement Validation
1. **Bounds Check**: Block must fit entirely within building area
2. **Collision Check**: No overlap with existing blocks
3. **Support Check**: Block must have proper support underneath OR be adjacent to another block with ground connection
4. **Inventory Check**: Player must have the item equipped

## Data Storage
Blocks are stored with **relative positions** (relative to building area origin):
```lua
{
    id = "playerId_block_N",
    itemName = "SprucePlank",
    relativePosition = { x = 0, y = 2, z = 4 },
    size = { x = 2, y = 2, z = 2 },
    buildingAreaId = "playerId"
}
```

## Block Placement Flow
1. Client raycasts to find placement position (blueprints/ghost models are excluded from raycast so blocks can be placed through them)
2. Client shows preview model with highlight (green=valid, red=invalid)
3. Placement is blocked only when hovering over a **completed structure** (not ghost blueprints)
4. On click, client calls `BuildingService:PlaceBlock()`
4. Server validates placement
5. Server consumes item from inventory
6. Server creates block in world
7. Server saves to player data
8. Server notifies client via `BlockPlaced` signal
9. **If inside blueprint**: Server notifies `BlueprintService:OnBlockPlacedInBlueprint()`

## Block Removal Flow
1. Player breaks block (via breaking system or direct removal)
2. Server validates ownership
3. Server destroys block model
4. Server removes from saved data
5. Server adds item back to inventory
6. **If inside blueprint**: Server notifies `BlueprintService:OnBlockRemovedFromBlueprint()`

## Integration with Blueprint System
When a block is placed, BuildingService checks if it's inside a blueprint bounds:
- Calls `BlueprintService:GetBlueprintAtPosition()` to find matching blueprint
- If found, calls `OnBlockPlacedInBlueprint()` to track progress
- Blueprint system validates correct block type and tracks completion
