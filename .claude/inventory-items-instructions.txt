================================================================================
                    INVENTORY & ITEMS SYSTEM ARCHITECTURE
                    Break & Build - Roblox Game
================================================================================

This document explains how the inventory system and item instantiation work.
Read this to understand how items are defined, stored, moved, equipped,
and persisted.

================================================================================
1. OVERVIEW
================================================================================

The inventory system manages:
- Item definitions (types, properties, models)
- Storage (7 hotbar slots + 21 backpack slots = 28 total)
- Stacking (stackable items combine, tools don't stack)
- Equipping (hold items in hand with welded models)
- Dropping (spawn item in world for pickup)
- Persistence (ProfileService saves/loads)
- Client sync (server → Rodux via signals)

================================================================================
2. KEY FILES
================================================================================

SERVER:
  src/server/Services/InventoryService.lua
    - AddItem, RemoveItem, MoveHotbarSlot, MoveToHotbar, MoveToBackpack
    - EquipItem, UnequipItem, DropEquippedItem
    - Serialization and sync to client
    - Migrations and cleanup on load

  src/server/Services/DataService.lua
    - ProfileService integration
    - LoadData, SaveData, GetData
    - Profile locking and reconciliation

  src/server/Constants/DataTemplate.lua
    - New player data structure template

CLIENT:
  src/client/Controllers/InventoryController.lua
    - Keybind handling (1-7, B, H, G)
    - Drag-and-drop with drop zone registry
    - Backpack toggle, hammer equip

  src/client/Modules/Synchronization/Inventory.lua
    - Converts server signals to Rodux dispatches
    - String-key to numeric-key conversion

SHARED:
  src/shared/Data/Items/init.lua       -- Central registry
  src/shared/Data/Items/Blocks.lua     -- Block items
  src/shared/Data/Items/Ores.lua       -- Ore/material items
  src/shared/Data/Items/Tools.lua      -- Tool items
  src/shared/Data/Items/Blueprints.lua -- Blueprint items
  src/shared/Data/Items/Structures.lua -- Completed structure items
  src/shared/Utils/ItemCategorization.lua -- Hotbar vs backpack routing

================================================================================
3. ITEM DEFINITION FORMAT
================================================================================

BASE PROPERTIES (all items):
  {
    name = "ItemName",              -- Internal identifier (unique)
    displayName = "Display Name",   -- UI display text
    type = "Block",                 -- Category: Block/Ore/Tool/Blueprint/Structure
    stackable = true,               -- Can items combine in one slot
    maxStack = 64,                  -- Max quantity per stack
    dropable = true,                -- Can be dropped when equipped
    description = "...",            -- Tooltip text
    modelPath = "Assets.Items.X",   -- Dot-path to model in ReplicatedStorage
  }

BLOCK-SPECIFIC:
  {
    type = "Block",
    blockSize = Vector3.new(4, 4, 4),  -- Or (2, 2, 2) for half-blocks
    buildingPartPath = "Assets.BuildingBlocks.SandBlock",  -- Clone for placement
  }

TOOL-SPECIFIC (Breaking Tools):
  {
    type = "Tool",
    stackable = false,
    maxStack = 1,
    isBreakingTool = true,
    breakSpeed = 1.0,              -- Multiplier (higher = faster)
    toolTier = "Wood",             -- Hand/Wood/Stone/Iron/Gold/Diamond
    canBreakAll = false,           -- Bypass tier check if true
  }

TOOL-SPECIFIC (Combat):
  {
    type = "Tool",
    isCombatTool = true,
    damage = 10,
    attackSpeed = 1.0,
  }

TOOL-SPECIFIC (Hammer):
  {
    type = "Tool",
    isRemovalTool = true,
    dropable = false,              -- Cannot be dropped
  }

BLUEPRINT-SPECIFIC:
  {
    type = "Blueprint",
    stackable = false,
    isBlueprintTool = true,
    blueprintType = "Workbench",   -- Links to blueprint definition
  }

STRUCTURE-SPECIFIC:
  {
    type = "Structure",
    isStructure = true,
    blueprintType = "Workbench",   -- Links back to blueprint
    placementModelPath = "Assets.CompletedBlueprints.Workbench",
  }

================================================================================
4. ALL CURRENT ITEMS
================================================================================

BLOCKS:
  Dirt (4x4x4) | Grass (4x4x4) | Stone (4x4x4) | Sand (4x4x4)
  Log (4x4x4) | SprucePlank (2x2x2) | HalfStone (2x2x2) | Bedrock (4x4x4)

ORES:
  StoneShard | IronOre | RawGold | RawDiamond | IronIngot
  All stackable (max 64)

TOOLS (Breaking):
  WoodenPickaxe (speed 1.0, tier Wood)
  StonePickaxe (speed 1.5, tier Stone)
  IronPickaxe (speed 2.0, tier Iron)
  WoodenAxe / StoneAxe / IronAxe
  WoodenShovel / StoneShovel / IronShovel

TOOLS (Combat):
  WoodenSword / StoneSword / IronSword

TOOLS (Special):
  Hammer (slot 0, removal tool, non-droppable)

BLUEPRINTS:
  WorkbenchBlueprint | FurnaceBlueprint | StoneCutterBlueprint

STRUCTURES:
  CompletedWorkbench | CompletedFurnace | CompletedStoneCutter | CompletedLogCutter

================================================================================
5. INVENTORY DATA STRUCTURE
================================================================================

IN-MEMORY (PlayerData.Inventory):
  {
    Hotbar = {
      [1] = { id = "123_1", itemName = "WoodenPickaxe", quantity = 1 },
      [2] = nil,
      ...
      [7] = nil,
    },
    Backpack = {
      ["1"] = { id = "123_2", itemName = "Stone", quantity = 32 },
      ["2"] = nil,
      ...
      ["21"] = nil,
    },
    EquippedSlot = nil,    -- nil (nothing), 0 (Hammer), or 1-7
    NextItemId = 3,        -- Counter for unique item IDs
  }

NOTE: Backpack uses STRING keys ("1" to "21") for JSON/ProfileService
compatibility. Hotbar uses numeric keys [1] to [7].

ITEM ID FORMAT:
  "{UserId}_{NextItemId}"   -- e.g., "12345678_42"
  Special: "woodenpickaxe_starter" for the initial pickaxe

CONSTANTS:
  HOTBAR_SIZE = 7
  BACKPACK_SIZE = 21
  Total capacity = 28 slots

================================================================================
6. ADDING ITEMS (InventoryService:AddItem)
================================================================================

AddItem(player, itemName, quantity):
  1. Validate item exists via ItemData.GetItem(itemName)
  2. Determine target: hotbar or backpack (ItemCategorization)
  3. If stackable:
     a. Search existing stacks of same item (hotbar first, then backpack)
     b. Add to existing stack if below maxStack
     c. Overflow to new slots if needed
  4. If non-stackable:
     a. Create new item with unique ID
     b. Place in first empty slot (hotbar → backpack)
  5. Return false if no space available
  6. Fire InventoryUpdated signal to client

ITEM CATEGORIZATION:
  - Tools, Blueprints, Structures → prefer Hotbar
  - Blocks, Ores → prefer Backpack
  - If preferred target is full, overflow to other

================================================================================
7. REMOVING ITEMS (InventoryService:RemoveItem)
================================================================================

RemoveItem(player, itemId, quantity):
  1. Search hotbar slots [1-7] for matching ID
  2. Search backpack slots ["1"-"21"] for matching ID
  3. If quantity >= item.quantity: remove item entirely (set slot to nil)
  4. Else: reduce item.quantity by amount
  5. Return false if item not found
  6. Fire InventoryUpdated signal

================================================================================
8. MOVING ITEMS
================================================================================

MoveHotbarSlot(player, fromSlot, toSlot):
  - Swaps two hotbar positions
  - Handles equip state transfer

MoveToHotbar(player, itemId, targetSlot):
  - Moves item from backpack to specific hotbar slot
  - Swaps if target slot is occupied

MoveToBackpack(player, slot):
  - Moves hotbar item to first empty backpack slot
  - Unequips if that slot was equipped

SwapGridSlots (client-side):
  - Grid indices 1-21 = backpack slots
  - Grid indices 22-28 = hotbar slots 1-7
  - Optimistic update: Rodux swaps immediately, server confirms async

================================================================================
9. EQUIP/UNEQUIP SYSTEM
================================================================================

EQUIP (InventoryService:EquipItem):
  For Hammer (slot 0):
    1. Validate player is in BuildingArea
    2. Unequip any previous item
    3. Clone Hammer model from Assets.Items.Hammer
    4. Position at RightGripAttachment
    5. WeldConstraint: Part0=RightHand, Part1=Hammer PrimaryPart
    6. Set EquippedSlot = 0
    7. Fire ItemEquipped(player, 0, "Hammer")

  For regular items (slot 1-7):
    1. Validate hotbar slot contains item
    2. Unequip any previous item
    3. Clone item model from modelPath
    4. Position at RightGripAttachment
    5. WeldConstraint: Part0=RightHand, Part1=PrimaryPart
    6. Set EquippedSlot = slot
    7. Fire ItemEquipped(player, slot, itemName)

UNEQUIP (InventoryService:UnequipItem):
  1. Destroy equipped model
  2. Destroy weld constraint
  3. Set EquippedSlot = nil
  4. Fire ItemUnequipped signal

DROP (InventoryService:DropEquippedItem):
  1. Get equipped item from Hotbar[slot]
  2. Validate item.dropable == true (Hammer cannot be dropped)
  3. Create dropped model at player position + lookVector * 5
  4. Remove from inventory
  5. Unequip
  6. Fire ItemDropped signal

DROPPED ITEM IN WORLD:
  Model named "{itemName}_Dropped" with:
    IntValue "Quantity"
    StringValue "ItemName"
  Can be picked up by any player

================================================================================
10. KEYBINDS (InventoryController)
================================================================================

  1-7: Toggle equip hotbar slot (only when backpack closed)
  Backquote (`) or B: Toggle backpack open/close
  H: Equip/unequip Hammer (only in BuildingArea)
  G: Drop equipped item

================================================================================
11. DATA PERSISTENCE
================================================================================

PROFILESERVICE INTEGRATION (DataService):
  Store: ProfileService.GetProfileStore("DataTest_1_16", ProfileTemplate)
  Key format: "Player_" .. player.UserId

LOAD FLOW:
  1. ProfileStore:LoadProfileAsync("Player_" .. UserId)
  2. profile:Reconcile() -- fills missing template keys
  3. Cached in DataService.Profiles[player]
  4. Returns profile.Data (direct mutable reference)

SAVE FLOW:
  1. PlayerRemoving event triggers
  2. profile:Release() -- writes to DataStore
  3. Removed from cache

DATA ACCESS:
  DataService:GetData(player) -- yields until loaded, returns profile.Data

================================================================================
12. DATA TEMPLATE (New Player)
================================================================================

  Inventory = {
    Hotbar = {},
    Backpack = {},
    EquippedSlot = nil,
    NextItemId = 1,
  }
  Building = {
    PlacedBlocks = {},
    NextBlockId = 1,
    BuildingAreaId = nil,
  }
  Crafting = {
    ActiveCraft = {},
  }
  Blueprints = {
    HasReceivedLogCutter = false,
    PlacedBlueprints = {},
    NextBlueprintId = 1,
  }
  Tree = {
    SelectedTreeType = "Spruce",
    State = nil,
    SpawnStartedAt = 0,
    RespawnStartedAt = 0,
    RespawnDuration = 0,
    BrokenLogs = {},
    TotalLogs = 0,
  }

================================================================================
13. CLIENT-SERVER SYNCHRONIZATION
================================================================================

SERVER → CLIENT FLOW:
  1. Server modifies inventory data
  2. Server serializes (string-keyed backpack)
  3. Fires InventoryUpdated(player, serializedInventory)
  4. Client Synchronization module receives
  5. Converts string keys to numeric indices
  6. Dispatches InventoryActions.setInventory() to Rodux
  7. UI components re-render reactively

RODUX INVENTORY STATE:
  {
    Hotbar = { [1..7] = item or nil },
    Backpack = { [1..21] = item or nil },
    EquippedSlot = nil/0/1-7,
    HammerAvailable = bool,
    BackpackOpen = bool,
    DevPickerOpen = bool,
  }

================================================================================
14. SIGNALS / EVENTS
================================================================================

Server → Client:
  - InventoryUpdated(player, serializedInventory)
  - ItemEquipped(player, slot, itemName)
  - ItemUnequipped(player)
  - ItemDropped(player, itemName, quantity)

Rodux Actions:
  - setInventory(state)
  - setHotbar(hotbar)
  - setBackpack(backpack)
  - setEquippedSlot(slot)
  - setHammerAvailable(bool)
  - setBackpackOpen(bool)
  - swapGridSlots(fromGridIndex, toGridIndex)
  - removeGridSlot(gridIndex)

================================================================================
15. MIGRATIONS (on load)
================================================================================

InventoryService runs these on each player join:
  1. migrateToUnifiedHotbar() -- old dual-hotbar → single hotbar
  2. migrateBackpack() -- numeric keys → string keys
  3. removeHammerFromInventory() -- clear stray Hammer items
  4. cleanupInvalidItems() -- remove items whose name no longer exists
  5. ensureStarterPickaxe() -- add WoodenPickaxe if not present

================================================================================
16. ADDING A NEW ITEM
================================================================================

To add a new item:

1. Add definition to appropriate file in src/shared/Data/Items/:
   - Blocks.lua, Ores.lua, Tools.lua, Blueprints.lua, or Structures.lua

2. Follow the format for that item type (see section 3)

3. Add image entry in src/shared/Data/Images/ (matching category file)

4. Add model to ReplicatedStorage.Assets at the specified modelPath

5. For blocks: add building part model at buildingPartPath

6. The item will automatically be available in the inventory system
   (no changes needed to InventoryService or controllers)

================================================================================
END OF DOCUMENT
================================================================================
