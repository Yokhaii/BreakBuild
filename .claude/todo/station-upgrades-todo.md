# TODO — Station Upgrades (Workbench & Furnace)

Status: **design agreed, not implemented.**

Read first when picking this up: `blueprint-system-instructions.md`, `crafting-system-instructions.md`, `building-system-instructions.md`, and the root `CLAUDE.md` ("New item, end to end") for every new model.

## Concept

A Workbench or Furnace is upgraded by placing an **upgrade blueprint touching the existing station**. Each upgrade adds one tier, up to **Tier 4**.

## Rules

- The upgrade blueprint must be placed at a position that **touches** the station's blueprint.
- Upgrades are applied **in order**: you can't skip a tier.
- If the upgrade structure is removed, the station **goes back to Tier 1**, not to the previous tier.
- Show clear feedback when an upgrade applies (e.g. "Tier 2!" popup, particles, change on the station).

## Tier table

| Tier | Furnace | Workbench |
|---|---|---|
| 1 | Base: 1 item smelted at once | Base: crafts with 2 slots |
| 2 | **Anvil** → 2 items at once | **Tanning Rack** → 3 slots |
| 3 | **Lava Pool** (existing blueprint) → 3 items at once | TBD → 4 slots |
| 4 | **Welding Station** → unlocks Chest link + auto-smelt | **Hydraulic Press** → unlocks Chest link + auto-craft |

Upgrade structures don't need to be thematically coherent with their station. Two rules:
- Each one is a real furnace/workbench upgrade.
- Crafting them gets **increasingly expensive** per tier. The Tier 4 Welding Station needs special steel items (e.g. **Gears**) and other parts crafted at the lower-tier Workbench and Furnace.

## What a "slot" means

A slot is one **input ingredient** of a recipe, i.e. one entry of the recipe's `inputs` array (`Data/Recipes/*.lua`).
- The station UI shows as many input slots as its tier allows: Workbench Tier 1 shows **2 slots** today, Tier 2 shows 3, Tier 3 shows 4.
- The recipe list shows every recipe whose number of inputs fits in those slots, **including the smaller ones**. A 3-ingredient recipe only appears at Workbench Tier 2+, and 2-ingredient recipes stay available.
- **Furnace: fuel is its own slot and doesn't count.** Ingredient slots: Tier 1 = 1, Tier 2 = 2, Tier 3 = 3 (e.g. alloys).
  - New Furnace UI layout: ingredient slots in a row on top, the **fuel slot below them**, instead of everything side by side (approved):
    ```
     Furnace T1        Furnace T2          Furnace T3
       [ ]              [ ] [ ]            [ ] [ ] [ ]
       [🔥]  → [out]     [🔥]   → [out]       [🔥]    → [out]
    ```
  - Fuel inputs today are mixed into `inputs` as `{ fuelTier = 1, quantity = N }` (`Data/Recipes/Furnace.lua`). Only non-fuel inputs count toward the slot limit (or move fuel to its own recipe field).

## Tier 4: automation

- The station links to a Chest.
- The station **does not** use everything in the Chest freely. The player **sets a recipe** on the station.
  - 1 recipe slot by default, 2–3 with a Robux purchase.
- The recipe runs automatically whenever the Chest has all required ingredients, and the output goes into the Chest.
- **Works offline.** On rejoin, compute what was crafted while away (time away ÷ craft time, stopped when ingredients run out or the Chest is full). The player only gets the loot once they're back in the game.
- Show a "welcome back" summary of what was produced.

## End game

- Tier 4 stations craft the end-game blueprints: **Nuclear Plant**, **Demonic Hotel**.
- Idea: two branches, industrial (Workbench line → Nuclear Plant: Uranium, Concrete, Circuits...) and infernal (Furnace line / Lava Pool → Demonic Hotel).
- Glass tubes are dropped as a general system. Possible special case: the Nuclear Plant must be linked by tube to a water pool.

## Open questions

- [ ] Workbench Tier 3 upgrade structure (decide later).
- [ ] Welding Station and Hydraulic Press recipes: Gears + which other intermediate items, and where each is crafted.
- [ ] Recipes for each upgrade blueprint (Anvil, Tanning Rack, Lava Pool, Tier 3 structure).
- [ ] Which recipes are tier-gated (e.g. diamond gear only at Tier 3/4)?
- [ ] Can one upgrade structure touch and upgrade two stations at once?
- [ ] Tier stored on the station instance: how it's saved and restored.

## Tasks

- [ ] Data: add tier info and upgrade definitions to `Data/Blueprints/Workbench.lua` and `Furnace.lua`.
- [ ] Data: new upgrade blueprints (Anvil, Welding Station, Tanning Rack, Workbench Tier 3 structure, Hydraulic Press), with Lava Pool reused.
- [ ] Models + icons for each new blueprint (Blender → Roblox pipeline).
- [ ] Server: detect an upgrade blueprint touching a station on completion; apply the tier in order.
- [ ] Server: reset to Tier 1 when an upgrade structure is removed.
- [ ] Crafting: filter recipes by number of inputs ≤ the station's slot count (server validates too, not only the UI).
- [ ] UI: Workbench/Furnace crafting panel renders the slot count from the tier instead of a fixed 2.
- [ ] UI: Furnace redesign: ingredient slots on top (1/2/3 by tier), fuel slot underneath.
- [ ] Recipes: add 3- and 4-input Workbench recipes and 2- and 3-input Furnace recipes so the upgrades unlock something.
- [ ] UI: show the current tier and the next upgrade on the station.
- [ ] Tier 4: Chest link, set-recipe UI, auto-craft loop, offline computation, rejoin summary.
- [ ] Robux: extra auto-recipe slots.
- [ ] Playtest in Studio.
