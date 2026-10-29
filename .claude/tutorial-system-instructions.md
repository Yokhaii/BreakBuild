================================================================================
                    TUTORIAL SYSTEM ARCHITECTURE
                    Break & Build - Roblox Game
================================================================================

This document explains how the onboarding tutorial works: how tasks are
defined, how progress is tracked, and how the player is guided (world beam,
UI spotlight, hints).

================================================================================
1. OVERVIEW
================================================================================

The tutorial is an ordered list of TASKS. Each task has a GOAL checked by the
server. While a task is active, the client works out the current SUB-STEP
from the UI / inventory / crafting state and guides the player with:
  - a world Beam + outline Highlight from the player to a 3D target
  - a UI Spotlight (dark overlay with a hole around the element to click,
    pulsing ring, click icon, hint text)
  - a TaskTracker card (top-right): "TUTORIAL 1/6", task title + progress, hint

Sub-steps are recomputed every 0.1s from state, so guidance recovers if the
player closes a menu or does things out of order. A spotlight only blocks
input while its target is visible, so it can never soft-lock the player.

================================================================================
2. KEY FILES
================================================================================

SERVER:
  src/server/Services/TutorialService.lua
    - Stores progress in PlayerData.Tutorial { CurrentTask, Completed }
    - Evaluates the current goal on InventoryService.InventoryChanged and
      BlueprintService.BlueprintChanged (server-side Signals)
    - Advances through every task whose goal is already met
    - Fires TutorialUpdated({ CurrentTask, Completed, Current, Required })

CLIENT:
  src/client/Controllers/TutorialController.lua
    - taskResolvers[task.id](task, state) -> { Hint, Spotlight?, WorldTarget?, Highlight? }
    - Drives the world Beam/Highlight (local objects under the Camera)
    - Dispatches TutorialActions.setTutorialGuide(hint, spotlightTarget)
    - Shows "Task complete" notifications

  src/client/Modules/TutorialTargets/init.lua
    - Registry of spotlightable UI elements (see section 5)

  src/client/Roact/Applications/Tutorial/
    - TaskTracker, Spotlight, ClickIcon components
    - Mounted in its own ScreenGui (TutorialScreenGui, DisplayOrder 50)

  src/client/Rodux/Reducers/TutorialReducer.lua
  src/client/Modules/Synchronization/Tutorial.lua

SHARED:
  src/shared/Data/TutorialData.lua    -- Tasks, goals, hint texts
  src/shared/Config/TutorialConfig.lua -- Beam/highlight visuals, intervals

================================================================================
3. CURRENT TASKS
================================================================================

  1. CollectLogs           Own 4 Log           Beam to closest Log
  2. GetWorkbenchBlueprint Own WorkbenchBlueprint
                           Beam to Blueprint table -> spotlight Workbench card
                           -> spotlight GET button
  3. PlaceWorkbench        Workbench placed    Spotlight hotbar slot -> beam to
                                               BuildingArea if outside
  4. BuildWorkbench        Workbench completed Open backpack -> click recipe once
                           (progress = correct per Log until ALL Logs are in the
                           fills / 12)          pool -> CRAFT (4 Logs = 16 planks
                                               in one craft) -> equip planks ->
                                               beam to ghost blueprint
  5. CraftPickaxe          Own WoodenPickaxe   Beam to Workbench -> spotlight
                                               recipe -> CRAFT -> wait
                                               (uses the 4 leftover planks; only
                                               falls back to a plank craft if
                                               the player is short)
  6. CollectStone          Own 4 Stone         Equip pickaxe -> beam to closest
                                               Stone above the ground layer
                                               (grid y >= MinGridHeight),
                                               exposed ones first

GOAL TYPES: CollectItem, GetBlueprint, PlaceBlueprint, CompleteBlueprint
(see the header of TutorialData.lua).

================================================================================
4. WHO GETS THE TUTORIAL
================================================================================

PlayerData.Tutorial.CurrentTask = 0 means "not decided yet". On first load:
  - Player has placed blocks/blueprints or any inventory item -> Completed = true
  - Otherwise -> CurrentTask = 1
To test it again, use a fresh profile (e.g. bump the ProfileStore name in
DataService).

================================================================================
5. SPOTLIGHT TARGETS
================================================================================

Tag a UI element with a ref so the tutorial can spotlight it:
  [Roact.Ref] = TutorialTargets.Ref("SomeId")

TutorialTargets.Get(id) returns it only if it is mounted and visible.

IDS IN USE:
  InventoryButton                       HUD backpack button
  HotbarSlot_<1-7>                      HUD hotbar slots
  BlueprintCard_<BlueprintName>         Blueprint menu list card
  BlueprintGetButton_<BlueprintName>    GET button (id follows the selection)
  InventoryRecipe_<RecipeId>            Backpack crafting recipe card
  InventoryCraftButton_<RecipeId>       Backpack CRAFT button (matched recipe)
  WorkbenchRecipe_<RecipeId>            Workbench recipe card
  WorkbenchCraftButton_<RecipeId>       Workbench CRAFT button (matched recipe)

Ids that include the selected/matched recipe let the controller know WHAT
the button will do without lifting local component state into Rodux.

================================================================================
6. ADDING A TASK
================================================================================

1. Add the task to TutorialData.Tasks (id, title, goal, + any guide fields)
2. If the goal type is new, handle it in getGoalProgress (TutorialService)
   and make sure something fires a re-evaluation when it can change
3. Add taskResolvers.<id> in TutorialController
4. If it needs new UI targets, add TutorialTargets.Ref(...) to the component
5. Add hint texts to TutorialData.Hints

================================================================================
END OF DOCUMENT
================================================================================
