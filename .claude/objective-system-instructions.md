================================================================================
                    OBJECTIVE SYSTEM ARCHITECTURE
                    Break & Build - Roblox Game
================================================================================

This document explains how objectives work: how they are defined, tracked,
claimed, pinned to the HUD, and how the tutorial is built on top of them.

================================================================================
1. OVERVIEW
================================================================================

Two kinds of objectives (src/shared/Data/ObjectiveData.lua):

  MAIN  = one ordered chain. Only the current one is active; it is ALWAYS shown
          in the HUD. Completing it activates the next one. The first main
          objectives are the tutorial (flagged `tutorial = true`).
  SIDE  = broad goals (Collect 250 Logs, Earn $1M...). They unlock when the
          main objective named in `unlockAfter` is completed (or at once if nil).
          They are listed in the Objectives frame and the player can PIN up to
          ObjectiveData.MaxPinned (3) of them to the HUD.

Lifecycle: Locked -> Active -> Complete -> Claimed
  - An objective COMPLETES by itself when its goal is met (the main chain moves on
    at once, so the tutorial never waits on a claim).
  - Its rewards (Dollars and/or items) wait until the player clicks CLAIM in the
    Objectives frame. CLAIM only exists there; the HUD "OBJECTIVES" title shows a
    red dot while any completed objective is unclaimed.

================================================================================
2. KEY FILES
================================================================================

SERVER:
  src/server/Services/ObjectiveService.lua
    - PlayerData.Objectives storage, counters, state goals, claim, pins
    - Fires ObjectivesUpdated(state) / ObjectiveClaimed(objectiveId)
    - Client methods: GetObjectivesState, ClaimObjective(id), SetPinned(id, bool)

  Event sources used by the counters:
    BreakingService.BreakableDestroyed(player, id, dropItem, pos, dropAmount, isGlobal)
    CraftingService.ItemCrafted(player, itemName, quantity)   -- every craft path
    ShopService.DollarsEarned(player, amount)                 -- ShopService:AddDollars

CLIENT:
  src/client/Controllers/ObjectiveController.lua
    - ClaimObjective(id), TogglePin(id), OpenObjectives(), CloseObjectives()
    - "Objective complete" / "Tutorial complete" notifications
  src/client/Modules/ObjectiveStatus/init.lua
    - Get(state, objective) -> status, current, required; number formatting
  src/client/Modules/Synchronization/Objective.lua
  src/client/Rodux/Reducers/ObjectiveReducer.lua (+ Actions/ObjectiveActions.lua)

  UI:
  src/client/Roact/Applications/HUD/Components/ObjectivesTracker/  (under SpawnButton)
    - Clickable "OBJECTIVES" title, then one line per task ("Collect 4 Logs  0/4  [icon]"):
      current main objective, the next UpcomingMainCount main ones greyed out,
      then the pinned side objectives (count turns green once complete).
      Red dot on the title while a reward is unclaimed.
  src/client/Roact/Components/Frames/HudPanel/  (shared title + content HUD panel,
    used by the ObjectivesTracker and the TutorialGuide)
  src/client/Roact/Applications/HUD/Components/ObjectiveRow/
  src/client/Roact/Applications/Objectives/   (CurrentFrame == "Objectives")
    Components/ObjectiveTabs, ObjectiveList, ObjectiveCard
  src/client/Roact/Components/Objectives/ObjectiveButton, ProgressBar  (shared)

================================================================================
3. OBJECTIVE DEFINITION FORMAT
================================================================================

{
  id = "Miner1",                      -- unique
  title = "Miner I",                  -- name in the Objectives frame
  task = "Collect 50 Stone",          -- HUD line text (falls back to title)
  icon = "Stone",                     -- optional item image (default: from the goal)
  description = "Collect 50 Stone.",
  goal = { type = "CollectItem", itemName = "Stone", amount = 50 },
  rewards = { Dollars = 100, Items = { { itemName = "Stone", quantity = 2 } } },
  unlockAfter = "CollectStone",       -- SIDE only: main objective id
  autoPin = true,                     -- SIDE only: pin once on unlock if room
  tutorial = true,                    -- MAIN only: guided by TutorialController
  ...                                 -- extra fields read by tutorial resolvers
}

GOAL TYPES:
  Counters (only count while the objective is ACTIVE, i.e. from its unlock):
    CollectItem       gather `amount` of `itemName` from WORLD breakables only
                      (trees, Breaking Area). Breaking own building blocks
                      does not count (isGlobal = false).
    CraftItem         craft `amount` of `itemName` (station or backpack)
    EarnDollars       earn `amount` Dollars (sales + objective rewards)
  States (checked against current data):
    GetBlueprint      own "<blueprintType>Blueprint" or have one placed
    PlaceBlueprint    have a `blueprintType` blueprint placed
    CompleteBlueprint have a completed `blueprintType` (progress = correct fills)

================================================================================
4. PERSISTENCE
================================================================================

PlayerData.Objectives:
  {
    MainIndex = 1,        -- index into ObjectiveData.Main (0 = not decided yet,
                          --  > #Main once the chain is finished)
    Progress = {},        -- [objectiveId] = counter value (active counters only)
    Completed = {},       -- [objectiveId] = true (goal met, latched)
    Claimed = {},         -- [objectiveId] = true (reward given)
    Pinned = {},          -- array of side ids
    AutoPinned = {},      -- [sideId] = true (autoPin applied once)
  }

FIRST LOAD (MainIndex == 0), migrating the old PlayerData.Tutorial:
  - Tutorial.Completed                 -> first non-tutorial main objective
  - Tutorial.CurrentTask >= 1          -> same index (tasks map 1:1)
  - existing blocks/blueprints/items   -> first non-tutorial main objective
  - otherwise (new player)             -> 1 (tutorial)

================================================================================
5. CLIENT STATE
================================================================================

ObjectiveReducer = {
  MainIndex = n,
  Progress = { [id] = { Current, Required } },  -- every ACTIVE objective
  Completed = { [id] = true },
  Claimed  = { [id] = true },
  Pinned   = { ids },
}

Status: Claimed > Completed (= "Complete", reward ready) > Progress entry (Active) > Locked.

================================================================================
6. TUTORIAL INTEGRATION
================================================================================

The tutorial = main objectives with `tutorial = true` (see
tutorial-system-instructions.md). TutorialController resolves the guidance for
the current one. The tutorial never involves the Objectives frame: completing a
tutorial objective moves on to the next step by itself, and its reward waits in
the frame (red dot). The step explanation is shown by the TutorialGuide panel
(top middle) and the Spotlight.

================================================================================
7. ADDING AN OBJECTIVE
================================================================================

1. Add an entry to ObjectiveData.Main (order = chain order) or ObjectiveData.Side
2. If the goal type is new:
   - counter: fire a server Signal where it happens and connect it to
     addCounterProgress(...) in ObjectiveService:KnitStart
   - state: add a branch in getGoalProgress and make sure something calls
     syncState when it can change
3. Reward items must exist in Items/ and have an image in Images/
4. A new tutorial objective also needs taskResolvers.<id> in TutorialController

================================================================================
END OF DOCUMENT
================================================================================
