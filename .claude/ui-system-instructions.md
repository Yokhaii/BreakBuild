================================================================================
                    UI SYSTEM ARCHITECTURE
                    Break & Build - Roblox Game
================================================================================

This document explains how the UI system works in this project.
Read this to understand how Roact components, Rodux state, controllers,
and UI interactions are structured.

================================================================================
1. OVERVIEW
================================================================================

The UI system uses:
- ROACT for declarative component rendering (React-like)
- RODUX for centralized state management (Redux-like)
- ROACT HOOKS for functional components (useState, useEffect, useSelector)
- KNIT CONTROLLERS for input handling and service communication

Key principles:
  - Server owns data, client owns presentation
  - State flows: Server → Signals → Synchronization → Rodux → Components
  - Components are purely reactive (re-render on state change)
  - Controllers handle user input and dispatch state changes

================================================================================
2. KEY FILES
================================================================================

ROOT:
  src/client/Roact/Root/Application.lua
    - Entry point, mounts ScreenGui
    - Wraps with ContextStack
    - Renders HUD, Blueprint, Backpack applications

STATE:
  src/client/Rodux/Store.lua
    - Combines all reducers into single store

  src/client/Rodux/Actions/
    - UIActions.lua, InventoryActions.lua, BlueprintActions.lua,
      CraftingActions.lua, TemplateActions.lua

  src/client/Rodux/Reducers/
    - UIReducer.lua, InventoryReducer.lua, BlueprintReducer.lua,
      CraftingReducer.lua, TemplateReducer.lua

CONTROLLERS:
  src/client/Controllers/UIController.lua
    - SetCurrentFrame(), GetCurrentFrame(), ShowHUD(), RemoveHUD()

  src/client/Controllers/InventoryController.lua
    - Keybinds, drag-and-drop, backpack toggle

  src/client/Controllers/KeybindController.lua
    - Keybind registration system

  src/client/Controllers/CraftingController.lua
    - Session management, craft requests

SYNCHRONIZATION:
  src/client/Modules/Synchronization/Inventory.lua
  src/client/Modules/Synchronization/Blueprint.lua
  src/client/Modules/Synchronization/Crafting.lua

CONTEXTS:
  src/client/Roact/Contexts/ContextStack.lua
  src/client/Roact/Contexts/AllowedApplicationsContext.lua

================================================================================
3. COMPONENT ARCHITECTURE
================================================================================

FOLDER STRUCTURE (mandatory pattern):
  ComponentName/
  ├── init.lua       -- Component implementation
  └── Config.lua     -- All sizing, positioning, colors, constants

COMPONENT TEMPLATE (init.lua):
  local Roact = require(...)
  local RoactHooks = require(...)
  local RoduxHooks = require(...)

  local function ComponentName(props, hooks)
    local state = RoduxHooks.useSelector(hooks, function(state)
      return state.SomeReducer
    end)

    local localState, setLocalState = hooks.useState(defaultValue)

    hooks.useEffect(function()
      -- side effects, listeners, timers
      return function() -- cleanup end
    end, { dependencies })

    return Roact.createElement("Frame", { ... }, {
      Child = Roact.createElement(ChildComponent, { ... }),
    })
  end

  return RoactHooks.new(Roact)(ComponentName)

CONFIG TEMPLATE (Config.lua):
  return {
    BackgroundColor = Color3.fromRGB(40, 40, 50),
    StrokeColor = Color3.fromRGB(80, 80, 100),
    CornerRadius = UDim.new(0, 8),
    Size = UDim2.fromScale(0.4, 0.6),
    Position = UDim2.fromScale(0.5, 0.5),
    Padding = UDim.new(0, 8),
    -- etc.
  }

================================================================================
4. APPLICATION HIERARCHY
================================================================================

ScreenGui (IgnoreGuiInset, ZIndexBehavior = Global)
└── ContextStack (providers)
    ├── HUD (always visible when CurrentFrame == "HUD")
    │   ├── Hotbar (7 slots + hammer)
    │   ├── HotbarSlot (per slot)
    │   ├── InventoryButton
    │   ├── HammerSlot
    │   └── CycleTimer (day/night)
    │
    ├── Backpack (visible when BackpackOpen == true)
    │   ├── DarkOverlay (click to close)
    │   ├── BackpackGrid (21 slots, 7 columns × 3 rows)
    │   ├── HotbarGrid (7 slots, 1 row)
    │   ├── ItemTooltip (hover info)
    │   └── [Crafting UI child if active]
    │       ├── Workbench / Furnace / StoneCutter / LogCutter
    │       └── (PanelFrame + TopPanelFrame layout)
    │
    └── Blueprint (blueprint selection UI)
        ├── BlueprintList
        ├── BlueprintCard / UnlockedBlueprintCard / LockedBlueprintCard
        ├── BlueprintMaterialList
        └── BlueprintViewport (3D preview)

================================================================================
5. RODUX STORE STRUCTURE
================================================================================

Complete state tree:
  {
    UIReducer = {
      CurrentFrame = "HUD",           -- "HUD" | "None" | station names
    },

    InventoryReducer = {
      Hotbar = { [1..7] = item? },
      Backpack = { [1..21] = item? },
      EquippedSlot = nil | 0 | 1-7,
      HammerAvailable = false,
      BackpackOpen = false,
      DevPickerOpen = false,
    },

    BlueprintReducer = {
      AvailableBlueprints = { ... },
      PlacedBlueprints = { [id] = data },
    },

    CraftingReducer = {
      ActiveSession = nil | {
        blueprintId = "id",
        stationType = "Workbench",
        recipes = { ... },
      },
      CurrentCraft = nil | {
        recipeId = "id",
        startedAt = os.clock(),
        craftTime = 9,
      },
    },

    TemplateReducer = { ... },
  }

================================================================================
6. UI STATE MANAGEMENT (UIReducer)
================================================================================

SINGLE STATE: CurrentFrame (string)
  Default: "HUD"
  Possible values: "HUD", "None", "Workbench", "StoneCutter", "Furnace", "LogCutter"

ACTION:
  UIActions.setCurrentFrame(frameName)

USAGE:
  UIController:SetCurrentFrame("Workbench")  -- Show workbench crafting
  UIController:ShowHUD()                      -- Back to game
  UIController:RemoveHUD()                    -- Hide everything

================================================================================
7. FRAME COMPONENTS
================================================================================

Three reusable frame templates:

BASEFRAME (src/client/Roact/Components/Frames/BaseFrame/):
  - Full modal window with title bar and close button
  - Props: Visible, Position, Size, Title, OnClose, ZIndex, colors
  - Contains: UICorner, UIStroke, StudBackground, Title, CloseButton, Content

PANELFRAME (src/client/Roact/Components/Frames/PanelFrame/):
  - Grey outer frame + dark inner content area
  - Used for recipe lists (left side of crafting UIs)
  - Title positioned top-left outside frame
  - ContentPosition: (0.5, 0.52), ContentSize: (0.9, 0.88)

TOPPANELFRAME (src/client/Roact/Components/Frames/TopPanelFrame/):
  - Symmetric to PanelFrame but narrower
  - Used for crafting area (inputs, output, craft button)
  - Sits above the backpack grid

================================================================================
8. GLOBAL COMPONENTS
================================================================================

ITEMSLOT (src/client/Roact/Components/Global/ItemSlot/):
  Universal reusable square slot. Props:
    Image, ItemName, Quantity, OnClick, OnHoverStart, OnHoverEnd,
    LayoutOrder, Size, ZIndex, BackgroundColor, StrokeColor,
    StrokeThickness, CornerRadius
  Features:
    - 1:1 aspect ratio constraint
    - StudBackground tiled texture
    - Centered image (75% scale)
    - Quantity label (bottom-right, white + black stroke)
    - Interactive button layer with hover

STUDBACKGROUND:
  - Responsive tiled background
  - Scales tile size based on viewport width
  - Optional UICorner and UIStroke

DARKOVERLAY:
  - Full-screen semi-transparent backdrop
  - Closes UI on click
  - Container for modals

FANCYTEXT:
  - Text with stroke effect

CLOSEBUTTON:
  - X button for closing panels

ITEMTOOLTIP:
  - Hover tooltip showing item name/description

VIEWPORTITEM:
  - 3D model preview in UI frame

================================================================================
9. KEYBIND SYSTEM
================================================================================

KeybindController (src/client/Controllers/KeybindController.lua):

REGISTRATION:
  local unregister = KeybindController:Register(
    id,                          -- Unique string
    Enum.KeyCode.X,              -- Key to listen
    callback,                    -- Function to call
    { condition = function() end } -- Optional gate
  )

ACTIVE KEYBINDS:
  1-7: Toggle equip hotbar slots (condition: backpack closed)
  Backquote/B: Toggle backpack
  H: Toggle hammer equip (condition: in BuildingArea)
  G: Drop equipped item

================================================================================
10. CRAFTING UI FLOW
================================================================================

How crafting UIs open from proximity to structures:

  1. Player approaches completed structure
  2. ProximityPrompt triggers or direct interaction
  3. CraftingController:StartSession(blueprintId)
  4. Server validates access, returns recipes
  5. Client dispatches CraftingActions.setSession({ blueprintId, stationType, recipes })
  6. CraftingReducer.ActiveSession populated
  7. UIActions.setCurrentFrame(stationType) dispatched
  8. Backpack opens with crafting UI embedded
  9. Appropriate application renders (Workbench/Furnace/StoneCutter/LogCutter)

CRAFTING UI LAYOUT:
  ┌──────────────────────────────────────────────┐
  │  [PanelFrame: Recipe List]  [TopPanelFrame]  │
  │  ┌─────────────────────┐   ┌─────────────┐  │
  │  │ RecipeCard 1        │   │  Input Slots │  │
  │  │ RecipeCard 2        │   │    → Output  │  │
  │  │ RecipeCard 3        │   │ [Craft Btn]  │  │
  │  │ ...                 │   │ [Progress]   │  │
  │  └─────────────────────┘   └─────────────┘  │
  │                                              │
  │  ┌────────────────────────────────────────┐  │
  │  │         Backpack Grid (21 slots)       │  │
  │  │         Hotbar Grid (7 slots)          │  │
  │  └────────────────────────────────────────┘  │
  └──────────────────────────────────────────────┘

================================================================================
11. DRAG AND DROP
================================================================================

DROP ZONE REGISTRY (InventoryController):
  RegisterDropZone(id, gridIndex, guiObject) → unregisterFn

GRID INDEXING:
  1-21 = Backpack slots
  22-28 = Hotbar slots (maps to slot 1-7)
  -1 = Trash zone (removes item)

DRAG FLOW:
  1. Mouse down on item slot → create drag clone
  2. Clone parented to ScreenGui, ZIndex 1000
  3. Clone follows mouse (updated each RenderStepped)
  4. Mouse up → check which drop zone mouse is over
  5. Dispatch swapGridSlots(fromIndex, toIndex)
  6. Optimistic Rodux update (instant UI swap)
  7. Server operation async in background

================================================================================
12. SYNCHRONIZATION PATTERN
================================================================================

Server → Client data flow:

  SERVER:
    Modifies data → Fires Knit signal to client

  SYNCHRONIZATION MODULE:
    Listens to signal → Converts format → Dispatches Rodux action

  RODUX:
    Reducer processes action → Returns new state

  COMPONENT:
    useSelector detects state change → Re-renders

SPECIFIC MODULES:

  Inventory.lua:
    InventoryService.InventoryUpdated → InventoryActions.setInventory()
    InventoryService.ItemEquipped → InventoryActions.setEquippedSlot()
    InventoryService.ItemUnequipped → InventoryActions.setEquippedSlot(nil)

  Blueprint.lua:
    BlueprintService.BlueprintPlaced → BlueprintActions.addBlueprint()
    BlueprintService.BlueprintRemoved → BlueprintActions.removeBlueprint()
    BlueprintService.BlueprintCompleted → BlueprintActions.completeBlueprint()

  Crafting.lua:
    CraftingService.CraftStarted → CraftingActions.setCraftInProgress()
    CraftingService.CraftCompleted → CraftingActions.clearCraft()
    CraftingService.CraftFailed → CraftingActions.clearCraft()
    CraftingService.SessionEnded → CraftingActions.clearSession()
    BlueprintService.CraftingProgressUpdated → billboard update

================================================================================
13. ZINDEX MANAGEMENT
================================================================================

  Base components: ZIndex = 5
  Overlays (DarkOverlay): ZIndex = 10-11
  Modals/frames: ZIndex = 12-15
  Tooltips: ZIndex = 50
  Drag clones: ZIndex = 1000

Pattern: components use `zIndex + 1`, `zIndex + 2` for internal layering.

================================================================================
14. VISIBILITY CONTROL
================================================================================

Multiple mechanisms:

  1. UIReducer.CurrentFrame:
     - Determines which main screen is active
     - Components check: if CurrentFrame ~= "MyFrame" then return invisible

  2. InventoryReducer.BackpackOpen:
     - Controls backpack overlay visibility
     - Independent of CurrentFrame

  3. CraftingReducer.ActiveSession:
     - When set, crafting UI renders inside backpack
     - When nil, only inventory grid shows

  4. Conditional rendering:
     if not visible then
       return Roact.createElement("Frame", { Visible = false })
     end

================================================================================
15. CREATING A NEW UI APPLICATION
================================================================================

To create a new UI screen/panel:

1. Create folder: src/client/Roact/Applications/NewApp/
   ├── init.lua
   ├── Config.lua
   └── Components/
       └── SubComponent/
           ├── init.lua
           └── Config.lua

2. In init.lua:
   - Use RoactHooks.new(Roact)(ComponentFunction)
   - Read state via RoduxHooks.useSelector(hooks, selector)
   - Local state via hooks.useState()
   - Side effects via hooks.useEffect()

3. In Config.lua:
   - All positioning (UDim2 values)
   - All colors (Color3 values)
   - All sizing constants
   - No logic, only data

4. Mount in Application.lua or as child of existing application

5. If it needs Rodux state:
   - Create action in src/client/Rodux/Actions/
   - Create reducer in src/client/Rodux/Reducers/
   - Add reducer to Store.lua combineReducers
   - Create sync module in src/client/Modules/Synchronization/

================================================================================
16. KEY PATTERNS TO FOLLOW
================================================================================

DO:
  - Separate ALL visual constants into Config.lua
  - Use folder structure (init.lua + Config.lua) for every component
  - Use useSelector for Rodux state, useState for local UI state
  - Use useEffect for subscriptions/timers with cleanup returns
  - Let controllers handle input, components handle rendering
  - Use ItemSlot for any item display

DON'T:
  - Put hardcoded colors/sizes in init.lua
  - Create standalone .lua component files (always use folder)
  - Dispatch Rodux actions directly from components (use controllers)
  - Mix input handling with rendering logic

================================================================================
END OF DOCUMENT
================================================================================
