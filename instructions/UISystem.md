# UI System

## Overview
The UI uses a React-like architecture with Roact for rendering and Rodux for state management. Components are functional and use hooks for local state.

## Framework Stack
- **Roact**: Declarative UI framework (React-like)
- **Rodux**: Centralized state management (Redux-like)
- **RoactHooks**: Hooks for functional components (useState, useMemo, etc.)
- **RoduxHooks**: Connect Roact to Rodux (useSelector, useDispatch)
- **Knit**: Service/controller framework for lifecycle management

## File Structure
```
src/client/
├── Roact/
│   ├── Root/Application.lua         -- Root component wrapping all apps
│   ├── Applications/
│   │   ├── HUD/Application.lua      -- Main game HUD
│   │   └── Blueprint/Application.lua -- Blueprint selection menu
│   ├── Components/
│   │   ├── Inventory/               -- Hotbar, Backpack, Slots
│   │   ├── Blueprint/               -- Blueprint cards & list
│   │   ├── Frames/                  -- BaseFrame template
│   │   └── Global/                  -- Reusable elements
│   └── Contexts/                    -- Roact contexts
├── Rodux/
│   ├── Store.lua                    -- Combined store
│   ├── Actions/                     -- Action creators
│   └── Reducers/                    -- State reducers
└── Controllers/                     -- Input & logic controllers
```

## Rodux Store Structure
```lua
Store = {
    UIReducer = {
        CurrentFrame = "HUD"  -- "HUD", "Blueprint", "None"
    },
    InventoryReducer = {
        BreakHotbar = {},     -- 6 slots for Break mode
        BuildHotbar = {},     -- 6 slots for Build mode
        Backpack = {},        -- All items
        CurrentMode = "Break", -- "Break" or "Build"
        EquippedSlot = nil,   -- Currently equipped slot number
        BackpackOpen = false,
        SearchQuery = ""
    },
    BlueprintReducer = {
        AvailableBlueprints = {},  -- Blueprints player can place
        PlacedBlueprints = {}      -- Currently placed blueprints
    }
}
```

## Main UI Components

### HUD Application
The main in-game interface containing:
- **Hotbar**: 6 slots showing equipped items (mode-aware)
- **ModeToggle**: Switch between Break/Build modes
- **Backpack**: Expandable inventory grid with search

### Hotbar System
- Separate hotbars for Break and Build modes
- Slot 1 in Build mode is locked (reserved for blueprint tool)
- Supports drag-and-drop between slots
- Visual feedback for equipped state

### Backpack
- Scrollable grid of all inventory items
- Search/filter functionality
- Items can be dragged to hotbar slots

## Data Flow
```
User Input → Controller → Dispatch Action → Reducer → State Update → Component Re-render
```

Example:
1. Player clicks hotbar slot
2. `InventoryController:ToggleEquipSlot()` called
3. Server equips item, broadcasts update
4. `Store:dispatch(InventoryActions.setEquippedSlot(slot))`
5. Components using `useSelector` re-render

## State Synchronization
- **InventorySync** (`src/client/Modules/Synchronization/Inventory.lua`): Syncs server inventory to Rodux
- **BlueprintSync** (`src/client/Modules/Synchronization/Blueprint.lua`): Syncs blueprint events to Rodux

## Key Patterns
- **Functional Components**: All components use hooks
- **Selector Pattern**: `useSelector(state => state.InventoryReducer.EquippedSlot)`
- **Memoization**: `useMemo` for expensive computations (e.g., filtered backpack)
- **Dual-Mode UI**: Hotbar content changes based on Break/Build mode
