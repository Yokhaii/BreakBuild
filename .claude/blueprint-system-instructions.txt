================================================================================
                    BLUEPRINT SYSTEM ARCHITECTURE
                    Break & Build - Roblox Game
================================================================================

This document explains how the blueprint system works in this project.
Read this to understand how blueprints are defined, placed, filled,
completed, and how they become functional crafting stations.

================================================================================
1. OVERVIEW
================================================================================

The blueprint system allows players to:
- Place ghost structure outlines in the BuildingArea
- Fill ghost slots with specific block types
- Complete blueprints to create functional crafting stations
- Break completed structures back into items

Blueprint lifecycle:
  1. Player equips Blueprint item → placement mode
  2. Ghost model placed in BuildingArea → UncompletedBlueprint
  3. Player fills slots with correct blocks → progress
  4. All slots filled → CompletedBlueprint (functional station)
  5. Station can be broken → returns Structure item

================================================================================
2. KEY FILES
================================================================================

SERVER:
  src/server/Services/BlueprintService.lua
    - PlaceBlueprint, PlaceStructure
    - OnBlockPlacedInBlueprint (checks if block fills a slot)
    - Blueprint completion and model swap
    - Load/save blueprints, crafting integration

  src/server/Classes/Blueprints/BaseBlueprint.lua
    - Server-side blueprint class
    - Ghost/completed model creation
    - Block filling logic and validation
    - Placement animation (wave effect)
    - Highlight proxy for transparent parts

  src/server/Classes/Blueprints/Workbench.lua (+ Furnace, StoneCutter, LogCutter)
    - Station-specific server behavior overrides

CLIENT:
  src/client/Controllers/BlueprintPlacementController.lua
    - Placement preview and validation
    - Raycast + grid snapping for blueprint position
    - Active blueprint management (visual state)

  src/client/Classes/Blueprints/BaseBlueprint.lua
    - Client-side blueprint class
    - Hover labels, wrong-block highlights
    - Crafting progress billboard
    - Flash effects for block placement

  src/client/Classes/Blueprints/Workbench.lua (+ Furnace, StoneCutter, LogCutter)
    - Station-specific client animations

  src/client/Modules/Synchronization/Blueprint.lua
    - Connects signals to Rodux store

SHARED:
  src/shared/Data/Blueprints/init.lua
    - Blueprint registry, GetBounds(), GetDefinition()

  src/shared/Data/Blueprints/Workbench.lua
  src/shared/Data/Blueprints/Furnace.lua
  src/shared/Data/Blueprints/StoneCutter.lua
  src/shared/Data/Blueprints/LogCutter.lua

================================================================================
3. BLUEPRINT DEFINITION FORMAT
================================================================================

{
  id = "Workbench",
  name = "Workbench",
  displayName = "Workbench",
  description = "Craft tools and equipment.",

  blocks = {
    { offset = Vector3.new(0, 0, 0), blockType = "SprucePlank" },  -- ANCHOR
    { offset = Vector3.new(0, 0, 6), blockType = "SprucePlank" },
    { offset = Vector3.new(6, 0, 0), blockType = "SprucePlank" },
    ...
  },

  modelPath = "ReplicatedStorage.Assets.Blueprints.Workbench",
  completedModelPath = "ReplicatedStorage.Assets.CompletedBlueprints.Workbench",
  completedItemName = "CompletedWorkbench",
  clientClass = "Workbench",          -- Optional: custom client class
  serverClass = "Workbench",          -- Optional: custom server class
  maxQuantity = 1,                    -- Max per player
  requiredRebirth = 0,                -- Gate requirement
  ghostTransparency = 0.55,           -- Visual transparency of ghost
}

OFFSET SYSTEM:
  - The model's PrimaryPart = ANCHOR point
  - offset (0,0,0) = the anchor block itself
  - All other offsets are RELATIVE to the anchor's world position
  - Offsets can be NEGATIVE (blocks behind/below/left of anchor)
  - Supports MIXED BLOCK SIZES:
    - 4x4x4 blocks use even offsets (0, 2, 4, 6...)
    - 2x2x2 blocks use odd offsets (-1, -3, 1, 3...)

================================================================================
4. ALL CURRENT BLUEPRINTS
================================================================================

WORKBENCH:
  - 12 SprucePlank blocks (all 2x2x2, offset spacing of 6 studs)
  - Pattern: 4x1x3 arrangement

FURNACE:
  - 24 HalfStone blocks (all 2x2x2)
  - Pattern: rectangular enclosure

STONECUTTER:
  - 1 Stone (4x4x4) as anchor at (0,0,0)
  - 4 SprucePlank (2x2x2) at odd offsets like (-1,-1,-3)
  - Mixed block sizes example

LOGCUTTER:
  - 0 blocks (special case: always immediately complete)
  - Pre-completed structure, no filling required

================================================================================
5. GetBounds() FUNCTION
================================================================================

Location: src/shared/Data/Blueprints/init.lua

Blueprints.GetBounds(definition) → (minOffset, maxOffset)

  - Iterates all blocks in definition.blocks
  - Finds min/max X, Y, Z across all offsets
  - Returns two Vector3 values representing bounding box
  - Used for placement validation (all blocks must fit in BuildingArea)

================================================================================
6. PLACEMENT FLOW (Client)
================================================================================

BlueprintPlacementController:

  1. Player equips Blueprint/Structure item
     → startPlacementMode(blueprintType, forStructure, structureItemName)

  2. Creates transparent preview model from modelPath
     - Blue highlight = valid position
     - Red highlight = invalid position

  3. Every RenderStepped:
     a. Raycast from mouse to BuildingArea surface
     b. Snap anchor position to grid:
        - 4x4x4 anchor → even grid (0, 2, 4, 6...)
        - 2x2x2 anchor → odd grid (1, 3, 5, 7...)
     c. Check ALL blocks fit in BuildingArea bounds (not just anchor)
     d. Update isValidPlacement flag and highlight color

  4. On click (if valid):
     - For blueprints: BlueprintService:PlaceBlueprint(position, type)
     - For structures: BlueprintService:PlaceStructure(position, itemName)
     - On success: stop placement mode, unequip item

================================================================================
7. SERVER-SIDE BLUEPRINT CLASS
================================================================================

BaseBlueprint (Server) - Key Methods:

  FillBlock(offset, blockType, blockId) → (success, isCorrect)
    - Validates offset exists in definition
    - Validates slot not already filled
    - Records fill: { blockType, blockId }
    - Fires OnBlockFilled if correct type
    - Fires OnWrongBlock if incorrect type
    - Auto-checks IsComplete() after each fill
    - Sets CompletedAt = os.time() on completion

  RemoveFilledBlock(offset) → boolean
    - Removes a filled block from slot
    - If was complete → reverts: CompletedAt = 0, fires OnDestroyed

  CreateModel(buildingAreaOrigin) → Model
    - Clones ghost model from modelPath
    - Positions at: buildingAreaOrigin + self.RelativePosition
    - Applies ghost effect (transparency, non-collidable)
    - Creates highlight proxy (glass parts for outline rendering)
    - Adds metadata StringValues: BlueprintId, OwnerId, BlueprintType

  CreateCompletedModel(buildingAreaOrigin) → Model
    - Destroys ghost model
    - Clones from completedModelPath
    - Makes solid and collidable
    - Plays wave placement animation
    - Sets IsStructureComplete = true
    - Adds IsCompletedStructure BoolValue

  _CreateHighlightProxy(model) → Model
    - Creates glass-material parts matching visible parts
    - Required for Roblox Highlight on transparent objects
    - Adds permanent outline effect

  _PlayPlacementAnimation(model, center)
    - Parts offset upward (0.5 studs)
    - Animate back with bounce easing
    - Wave delay based on distance from center
    - Duration: 0.4 seconds

================================================================================
8. CLIENT-SIDE BLUEPRINT CLASS
================================================================================

BaseBlueprint (Client) - Key Methods:

  SetModel(model)
    - Stores reference to workspace model

  ShowHoverLabel(offset, buildingAreaOrigin)
    - Billboard above specific block: "Need: {requiredType}"
    - 150px wide, 40px tall, 50 stud max distance

  HideHoverLabel()
    - Destroys hover billboard

  CreateWrongBlockHighlight(blockModel, blockId)
    - Red outline on incorrectly placed block
    - Color: RGB(255, 50, 50)

  RemoveWrongBlockHighlight(blockId)
    - Removes specific wrong-block highlight

  UpdateVisuals()
    - Correct fills: Transparency = 1 (invisible, block shows through)
    - Wrong fills: Transparency = 0.5, red tint
    - Empty slots: Transparency = 0.6-0.7, blue tint

  FlashBlockSlot(offset, isCorrect)
    - 3 rapid flashes (green if correct, red if wrong)
    - Each flash: 0.1s color + 0.1s wait

  ShowCraftingProgress(progress, secsRemaining)
    - Progress billboard on structure (5.4 x 0.65 studs)
    - Shows fill bar and time label ("Xm:YYs" or "Ready!")
    - 60 stud max visible distance

  HideCraftingProgress()
    - Destroys crafting billboard

  OnCrafting(progress) -- Override in subclasses
  OnCraftReceived()    -- Override in subclasses

================================================================================
9. BLOCK FILLING FLOW
================================================================================

When a player places a block in the BuildingArea:

  1. BuildingService:PlaceBlock() succeeds
  2. BuildingService checks if block position is inside any blueprint
  3. Calls BlueprintService:OnBlockPlacedInBlueprint(player, blockPos, blockType, blockId)
  4. BlueprintService finds which blueprint and which offset the block is at
  5. Calls blueprint:FillBlock(offset, blockType, blockId)
  6. Server fires BlueprintBlockFilled signal to client:
     (blueprintId, offset, blockType, isCorrect)
  7. Client updates visuals: flash + highlight update

WRONG BLOCKS:
  - Wrong type blocks still fill the slot
  - Blueprint won't complete until ALL slots have CORRECT types
  - Client shows red highlight on wrong blocks
  - Player must remove wrong block and place correct one

================================================================================
10. COMPLETION FLOW
================================================================================

  1. blueprint:FillBlock() detects IsComplete() == true
     (all offsets filled with correct blockType)
  2. Sets CompletedAt = os.time()
  3. Fires OnCompleted signal
  4. Server: All individual blocks removed (silent, no item return)
  5. Server: CreateCompletedModel() swaps ghost → solid
  6. Server: Fires BlueprintCompleted signal to all clients
  7. Client: Rodux updated (completeBlueprint action)
  8. Client: Wrong-block highlights cleared
  9. Structure is now functional (crafting station ready)
  10. Structure registered as breakable with BreakingService

================================================================================
11. PERSISTENCE
================================================================================

PlayerData.Blueprints:
  {
    HasReceivedLogCutter = false,
    PlacedBlueprints = { ... },
    NextBlueprintId = 1,
  }

SERIALIZED BLUEPRINT:
  {
    id = "blueprint_1",
    blueprintType = "Workbench",
    relativePosition = { x = 4, y = 0, z = 2 },
    rotation = 0,
    ownerId = 12345678,
    completedAt = 1234567890,          -- os.time() or 0
    filledBlocks = {
      ["0,0,0"] = { blockType = "SprucePlank", blockId = "123_5" },
      ["0,0,6"] = { blockType = "SprucePlank", blockId = "123_6" },
      ...
    },
  }

ON PLAYER JOIN:
  BlueprintService:LoadPlayerBlueprints() recreates all ghost/completed models

ON PLAYER LEAVE:
  All blueprint models destroyed (data persists in PlayerData)

================================================================================
12. RODUX STATE
================================================================================

BlueprintReducer state:
  {
    AvailableBlueprints = {
      {
        Id = "Workbench",
        Name = "Workbench",
        Description = "...",
        Image = "rbxassetid://...",
        Materials = {
          { Type = "SprucePlank", Amount = 12 },
        },
        IsUnlocked = true,
        RequiredRebirth = 0,
        MaxQuantity = 1,
      },
      ...
    },
    PlacedBlueprints = {
      ["blueprint_1"] = {
        id = "blueprint_1",
        blueprintType = "Workbench",
        completedAt = 1234567890,
      },
      ...
    },
  }

NOTE: AvailableBlueprints only includes blueprints with blocks > 0
(LogCutter excluded since it has 0 blocks and is always complete)

BlueprintActions:
  - addBlueprint(blueprintData)
  - removeBlueprint(blueprintId)
  - completeBlueprint(blueprintId)

================================================================================
13. IN-WORLD METADATA
================================================================================

On ghost models:
  BlueprintId (StringValue)       -- Unique ID
  OwnerId (IntValue)              -- Player UserId
  BlueprintType (StringValue)     -- "Workbench", "Furnace", etc.

On completed models (additionally):
  IsCompletedStructure (BoolValue) = true

================================================================================
14. SIGNALS / EVENTS
================================================================================

BlueprintService → Client:
  - BlueprintPlaced(blueprintData)
  - BlueprintRemoved(blueprintId)
  - BlueprintBlockFilled(blueprintId, offset, blockType, isCorrect)
  - BlueprintBlockRemoved(blueprintId, offset)
  - BlueprintCompleted(blueprintId)
  - StructurePlaced(structureData)
  - CraftingProgressUpdated(blueprintId, progress, secsRemaining)
  - CraftingProgressCleared(blueprintId)

Server-Side Signals:
  blueprint.OnCompleted
  blueprint.OnDestroyed
  blueprint.OnBlockFilled(offset, blockType, blockId)
  blueprint.OnWrongBlock(offset, blockType, requiredType)

================================================================================
15. ADDING A NEW BLUEPRINT
================================================================================

To add a new blueprint/crafting station:

1. Create definition: src/shared/Data/Blueprints/NewStation.lua
   Follow format in section 3. Key decisions:
   - Choose blocks array (types and offsets)
   - Set maxQuantity (usually 1)

2. Register in src/shared/Data/Blueprints/init.lua
   - Add require and insert into definitions table

3. Create models in ReplicatedStorage:
   - Ghost model at Assets.Blueprints.NewStation
   - Completed model at Assets.CompletedBlueprints.NewStation
   - Model PrimaryPart = anchor position

4. Create items in src/shared/Data/Items/:
   - Blueprint item in Blueprints.lua (isBlueprintTool, blueprintType)
   - Structure item in Structures.lua (isStructure, blueprintType)

5. Add images in src/shared/Data/Images/:
   - Blueprint image in Blueprints.lua
   - Structure image in Structures.lua

6. Optional: Create custom server/client classes
   - src/server/Classes/Blueprints/NewStation.lua
   - src/client/Classes/Blueprints/NewStation.lua
   - Set clientClass/serverClass in definition

7. If it's a crafting station: Create recipe file and UI
   (See crafting-system-instructions.txt)

================================================================================
END OF DOCUMENT
================================================================================
