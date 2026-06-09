# Blueprint System

## Overview
The blueprint system allows players to place blueprint templates that guide construction of multi-block structures. When all required blocks are placed correctly, the blueprint completes and activates special functionality.

## Key Components

### Server
- **BlueprintService** (`src/server/Services/BlueprintService.lua`): Handles placement, block tracking, and completion
- **ServerBaseBlueprint** (`src/server/Classes/Blueprints/BaseBlueprint.lua`): Server-side blueprint class with model creation
- **Workbench** (`src/server/Classes/Blueprints/Workbench.lua`): Example specific blueprint class

### Client
- **BlueprintPlacementController** (`src/client/Controllers/BlueprintPlacementController.lua`): Handles preview, placement input, and visual updates
- **ClientBaseBlueprint** (`src/client/Classes/Blueprints/BaseBlueprint.lua`): Client-side blueprint with billboard UI

### Shared
- **BaseBlueprint** (`src/shared/Classes/Blueprints/BaseBlueprint.lua`): Common logic (IsComplete, offsets, serialization)
- **Blueprint Definitions** (`src/shared/Data/Blueprints/`): Define each blueprint's requirements

## Blueprint Definition Structure
```lua
{
    id = "Workbench",
    name = "Workbench",
    size = Vector3.new(4, 4, 8),  -- Bounding box size

    blocks = {
        { offset = Vector3.new(0, 0, 0), blockType = "SprucePlank" },
        { offset = Vector3.new(2, 0, 0), blockType = "SprucePlank" },
        -- ... more blocks
    },

    modelPath = "ReplicatedStorage.Assets.Blueprints.Workbench",
    serverClass = "Workbench",  -- Custom server class
    clientClass = "Workbench",  -- Custom client class
    maxQuantity = 1,            -- Max per player
}
```

## Offset System
- Offsets are relative to the **anchor block** (first block, typically at 0,0,0)
- Use **2-stud spacing** for 2x2x2 blocks (e.g., 0, 2, 4, 6...)
- Use **4-stud spacing** for 4x4x4 blocks (e.g., 0, 4, 8...)
- The offset key format is `"X,Y,Z"` (e.g., `"2,0,4"`)

## Blueprint Placement Flow
1. Player equips blueprint item (`isBlueprintTool = true`)
2. Client shows preview model following mouse
3. On click, client calls `BlueprintService:PlaceBlueprint()`
4. Server validates bounds, collision, max quantity
5. Server creates ghost model in world
6. Server saves to player data
7. Client receives `BlueprintPlaced` signal, creates billboard UI

## Block Filling Flow
1. Player places block via BuildingService
2. BuildingService checks if block is inside a blueprint
3. If yes, calls `BlueprintService:OnBlockPlacedInBlueprint()`
4. BlueprintService calls `blueprint:FillBlock(offset, blockType, blockId)`
5. Blueprint validates correct block type
6. Blueprint checks `IsComplete()` after each block
7. If complete, fires `OnCompleted` signal

## Completion Check (`IsComplete`)
Iterates through all required blocks in definition:
- Checks if each offset has a filled block
- Checks if filled block type matches required type
- Returns true only if ALL blocks are correct

## Handling Already-Completed Blueprints
When loading from saved data, specific blueprint classes (like Workbench) check:
1. If `CompletedAt > 0` → Call completion handler
2. If `IsComplete()` returns true → Fix CompletedAt and call handler

## Signals
- `BlueprintPlaced(blueprintData)` - Blueprint created
- `BlueprintRemoved(blueprintId)` - Blueprint deleted
- `BlueprintBlockFilled(blueprintId, offset, blockType, isCorrect)` - Block placed in blueprint
- `BlueprintBlockRemoved(blueprintId, offset)` - Block removed from blueprint
- `BlueprintCompleted(blueprintId)` - All blocks placed correctly

## Creating New Blueprint Types
1. Add definition in `src/shared/Data/Blueprints/YourBlueprint.lua`
2. Register in `src/shared/Data/Blueprints/init.lua`
3. Create server class in `src/server/Classes/Blueprints/YourBlueprint.lua` (optional)
4. Create client class in `src/client/Classes/Blueprints/YourBlueprint.lua` (optional)
5. Create model in `ReplicatedStorage.Assets.Blueprints`
6. Create blueprint item in Items data
