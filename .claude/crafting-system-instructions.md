================================================================================
                    CRAFTING SYSTEM ARCHITECTURE
                    Break & Build - Roblox Game
================================================================================

This document explains how the crafting system works in this project.
Read this to understand how crafting stations, recipes, timers, and
item production function.

================================================================================
1. OVERVIEW
================================================================================

The crafting system allows players to:
- Use completed blueprint structures as crafting stations
- Select recipes from station-specific lists
- Craft items in batches with timed production
- Receive items automatically or on next station visit

Four crafting station types:
  1. Workbench    = Tools (pickaxes, axes, shovels, swords)
  2. Furnace      = Smelting (ore → ingot, dirt → sand)
  3. StoneCutter  = Stone processing (stone → shards/half-blocks)
  4. LogCutter    = Wood processing (log → planks)

================================================================================
2. KEY FILES
================================================================================

SERVER:
  src/server/Services/CraftingService.lua
    - Session management (start/end)
    - Recipe validation and item consumption
    - Timer-based crafting with progress broadcast
    - Delivery logic (immediate or deferred)
    - Persistence of active crafts across sessions

CLIENT:
  src/client/Controllers/CraftingController.lua
    - StartSession(blueprintId), EndSession(), CraftItem(recipeId, qty)
    - Bridges server calls to Rodux state

  src/client/Modules/Synchronization/Crafting.lua
    - Connects CraftingService signals to Rodux store
    - Updates billboard progress on structures

SHARED:
  src/shared/Data/Recipes/init.lua
    - Recipe registry: GetRecipe(id), GetRecipesForStation(type)
    - Aggregates all station recipe modules

  src/shared/Data/Recipes/Workbench.lua    (12 recipes)
  src/shared/Data/Recipes/Furnace.lua      (2 recipes)
  src/shared/Data/Recipes/StoneCutter.lua  (2 recipes)
  src/shared/Data/Recipes/LogCutter.lua    (1 recipe)

================================================================================
3. RECIPE DATA STRUCTURE
================================================================================

{
  id = "WoodenPickaxe",
  displayName = "Wooden Pickaxe",
  stationType = "Workbench",
  craftTime = 3,                    -- Seconds per unit
  order = 1,                        -- Display order in UI list
  inputs = {
    { itemName = "SprucePlank", quantity = 3 },
  },
  outputs = {
    { itemName = "WoodenPickaxe", quantity = 1 },
  },
}

RECIPE LOOKUP:
  Recipes.GetRecipe(recipeId)               -- Single recipe by ID
  Recipes.GetRecipesForStation(stationType) -- All recipes for station type
  Recipes.All                               -- Full table of all recipes

================================================================================
4. ALL CURRENT RECIPES
================================================================================

WORKBENCH (stationType = "Workbench"):
  Wooden tier (3s):  3 SprucePlank → 1 WoodenPickaxe/Axe/Shovel/Sword
  Stone tier (10s):  3 StoneShard + 2 SprucePlank → 1 StonePickaxe/Axe/Shovel/Sword
  Iron tier (5s):    3 IronIngot + 2 SprucePlank → 1 IronPickaxe/Axe/Shovel/Sword

FURNACE (stationType = "Furnace"):
  IronIngot (10s):   4 IronOre → 1 IronIngot
  Sand (4s):         1 Dirt → 1 Sand

STONECUTTER (stationType = "StoneCutter"):
  HalfStone (3s):    1 Stone → 4 HalfStone
  StoneShard (3s):   1 Stone → 4 StoneShard

LOGCUTTER (stationType = "LogCutter"):
  SprucePlank (2s):  1 Log → 4 SprucePlank

================================================================================
5. SESSION MANAGEMENT
================================================================================

SESSION LIFECYCLE:
  1. Player approaches completed structure (proximity)
  2. Client calls CraftingController:StartSession(blueprintId)
  3. Server validates blueprint access via CanPlayerUse(player.UserId)
  4. Server creates session: { blueprintId, stationType }
  5. Server returns recipes for that station type
  6. Client dispatches to Rodux: CraftingActions.setSession(...)
  7. UI renders recipe list for the station
  8. Player closes UI → CraftingController:EndSession()
  9. Active craft continues even after session ends

SESSION STATE (server):
  sessions[player] = {
    blueprintId = "id",
    stationType = "Workbench",
  }

================================================================================
6. CRAFTING EXECUTION FLOW
================================================================================

STEP 1 - VALIDATION (CraftItem):
  - Session exists for player
  - 0.3s cooldown since last craft (CRAFT_COOLDOWN)
  - Not already crafting
  - Recipe exists and matches station type
  - Station still accessible (CanPlayerUse)
  - Player has all required inputs (quantity * recipe inputs)
  - Quantity clamped to [1, 99]

STEP 2 - ZERO-TIME CRAFTS (craftTime <= 0):
  - Inputs consumed immediately
  - Outputs added immediately
  - CraftCompleted fired, no timer needed

STEP 3 - TIMED CRAFTS:
  - Total duration = recipe.craftTime * quantity
  - Active craft entry created and saved to persistent data
  - CraftStarted signal fired to client (recipeId, totalDuration, elapsed=0)
  - Progress broadcast loop starts (ticks every 0.1s)
  - Completion timer started via task.delay()

PROGRESS BROADCAST (every 0.1s):
  progress = elapsed / duration (clamped 0-1)
  Fires: BlueprintService.Client.CraftingProgressUpdated(blueprintId, progress, secsRemaining)
  Updates in-world billboard on crafting station

================================================================================
7. COMPLETION & DELIVERY
================================================================================

TWO DELIVERY MODES:

Case 1 - Player IS watching (session open on same blueprint):
  - Timer expires
  - deliverCraft() called immediately
  - CraftCompleted signal fired
  - UI updates instantly

Case 2 - Player NOT watching (session closed or on different station):
  - Timer expires
  - craft.isReady = true
  - CraftReady signal fired to client
  - Billboard frozen at 100% with "Ready!" label
  - Delivery deferred until player opens that station UI again

DELIVERY PROCESS (deliverCraft):
  1. Verify station still accessible
  2. Verify inputs still available (double-check)
  3. Remove inputs via InventoryService:RemoveItem()
  4. Add outputs via InventoryService:AddItem()
  5. Clear active craft from memory and persistent data
  6. Clear progress billboard
  7. Call blueprint:OnCraftReceived() callback

IMPORTANT: Inputs are consumed at DELIVERY time, not at craft start.
This means if inputs are removed between start and delivery, craft fails.

================================================================================
8. ITEM CONSUMPTION LOGIC
================================================================================

findItemsByName(inventory, itemName):
  - Searches Hotbar[1..7] first, then Backpack["1".."21"]
  - Returns total quantity and list of sources with IDs

hasRequiredInputs(player, recipe, quantity):
  - For each recipe input: needed = input.quantity * quantity
  - Checks total found >= needed for all inputs
  - Returns error reason if insufficient

removeInputs(player, recipe, quantity):
  - Gets all sources for each input item
  - Removes from sources in order until needed amount reached
  - Calls InventoryService:RemoveItem(player, itemId, count) per stack

addOutputs(player, recipe, quantity):
  - For each recipe output: count = output.quantity * quantity
  - Calls InventoryService:AddItem(player, itemName, count)
  - Returns false if inventory full

================================================================================
9. PERSISTENCE
================================================================================

Active crafts survive logout/rejoin:

SAVED STATE (playerData.Crafting.ActiveCraft):
  {
    blueprintId = "id",
    recipeId = "id",
    quantity = 3,
    startedAt = os.time(),    -- Absolute timestamp
    duration = 9,             -- Total seconds
  }

ON PLAYER JOIN:
  ResumePlayerCraft(player) called:
  1. Loads saved craft from playerData
  2. Verifies recipe still exists
  3. Verifies blueprint still accessible
  4. Restarts execution with original timestamps
  5. Progress bar continues from saved time (not reset to 0)

ON PLAYER LEAVE:
  Active craft saved to playerData.Crafting.ActiveCraft

================================================================================
10. SIGNALS / EVENTS
================================================================================

CraftingService → Client Signals:
  - SessionStarted(recipes)                    -- Station opened
  - SessionEnded                               -- Station closed
  - CraftStarted(recipeId, totalDuration, elapsed) -- Timer started
  - CraftCompleted(recipeId, blueprintId)      -- Delivered successfully
  - CraftFailed(reason)                        -- Failed (inputs gone, full, etc.)
  - CraftReady(blueprintId, recipeId)          -- Ready but not delivered yet

BlueprintService → Client Signals:
  - CraftingProgressUpdated(blueprintId, progress, secsRemaining) -- Billboard
  - CraftingProgressCleared(blueprintId)       -- Hide billboard

Controller Methods:
  CraftingController:StartSession(blueprintId)
  CraftingController:EndSession()
  CraftingController:CraftItem(recipeId, quantity)
  CraftingController:HasActiveSession()

================================================================================
11. ADDING A NEW RECIPE
================================================================================

To add a new recipe:

1. Add recipe entry to the appropriate station file:
   src/shared/Data/Recipes/[StationType].lua

2. Follow this format:
   {
     id = "UniqueRecipeId",
     displayName = "Display Name",
     stationType = "StationType",
     craftTime = 5,
     order = nextOrder,
     inputs = { { itemName = "X", quantity = N }, ... },
     outputs = { { itemName = "Y", quantity = M }, ... },
   }

3. Ensure all input/output item names exist in src/shared/Data/Items/init.lua

4. Ensure input/output items have images in src/shared/Data/Images/

================================================================================
12. ADDING A NEW CRAFTING STATION
================================================================================

To add a new station type:

1. Create recipe file: src/shared/Data/Recipes/NewStation.lua
2. Add require to src/shared/Data/Recipes/init.lua
3. Create blueprint definition: src/shared/Data/Blueprints/NewStation.lua
4. Create server class: src/server/Classes/Blueprints/NewStation.lua
5. Create client class: src/client/Classes/Blueprints/NewStation.lua
6. Create UI application: src/client/Roact/Applications/NewStation/
   - init.lua (main component)
   - Components/RecipeList/ and Components/RecipeCard/
7. Add item definitions: Blueprint item + Structure item in Items/
8. Add images for new items

================================================================================
END OF DOCUMENT
================================================================================
