# Break & Build - System Documentation

This folder contains documentation for the core systems of the game. Use these files to quickly understand how each system works.

## Documentation Files

| File | Description |
|------|-------------|
| [BuildingSystem.md](BuildingSystem.md) | Block placement, grid snapping, validation, and persistence |
| [BreakingSystem.md](BreakingSystem.md) | Resource gathering, tools, materials, and respawning |
| [BlueprintSystem.md](BlueprintSystem.md) | Multi-block structure templates and completion tracking |
| [UISystem.md](UISystem.md) | Roact/Rodux architecture, components, and state management |

## Quick Reference

### Key Services (Server)
- `BuildingService` - Block placement/removal
- `BreakingService` - Breaking state and validation
- `BlueprintService` - Blueprint placement and tracking
- `InventoryService` - Item management
- `DataService` - Player data persistence

### Key Controllers (Client)
- `BuildingController` - Placement preview and input
- `BreakingController` - Breaking input and VFX
- `BlueprintPlacementController` - Blueprint preview and placement
- `InventoryController` - Hotbar/backpack interaction

### Data Locations
- Items: `src/shared/Data/Items/`
- Blueprints: `src/shared/Data/Blueprints/`
- Player Data Template: `src/server/Constants/DataTemplate.lua`

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│                        CLIENT                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │ Controllers │  │    Roact    │  │    Rodux    │     │
│  │  (Input)    │──│    (UI)     │──│   (State)   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
│         │                                   │           │
│         └───────────── Knit ───────────────┘           │
└─────────────────────────┬───────────────────────────────┘
                          │ RemoteEvents/Functions
┌─────────────────────────┴───────────────────────────────┐
│                        SERVER                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐     │
│  │  Services   │  │   Classes   │  │    Data     │     │
│  │ (Logic)     │──│ (Blueprints)│──│ (Persist)   │     │
│  └─────────────┘  └─────────────┘  └─────────────┘     │
└─────────────────────────────────────────────────────────┘
```
