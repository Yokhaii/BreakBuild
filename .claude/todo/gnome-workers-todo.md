# TODO — Gnome Workers

Status: **design agreed, not implemented.** Comes after the station upgrades (`station-upgrades-todo.md`).

## Concept

Players hire **gnomes** (small Roblox rigs) to do tasks for them, including while they're offline. Gnomes are paid with **food**. If they go unfed too long, they **go on strike**.

## Hiring

- Costs a lot of in-game money.
- 3 worker slots, unlocked progressively through the game.
- 4th worker slot bought with **Robux**.

## Tasks

- Stations (Tier 4) handle crafting and smelting. Gnomes handle the rest:
  - Harvest crops (Crop Field)
  - Collect (Bird Nest, etc.)
  - Move items between Chests / blueprints
  - Sell items from a Chest (watch the economy: consider a sell cap per hour)
  - Kill mobs (once mobs exist)
- Gnomes keep working offline. Don't run their AI offline: compute the results ("X wheat per hour") and only show walking rigs while the player is online.
- The player collects the loot only after reconnecting.

## Gnome house & food box

- A small **gnome house** sits **near the building area but not on it**. It holds the **food box**.
- The food box has **one slot per hired gnome** (4 gnomes = 4 slots). The whole crew eats from the box, so more gnomes eat faster but also add a slot.
- Each food has its own **stack limit** in a box slot to push variety (e.g. 10 Bread, 20 Carrot, 3 Melon, 1 Carrot Cake).
- Max duration is about **7 days** with good food, less with poor food.
- Food can only be added **while the player is online**.
- The food box **UI** shows how long the food will last, based on the foods, quantities and number of workers.
- Balance idea: a full slot of better food lasts longer than a full slot of cheap food, plus a variety bonus (e.g. 4 different foods → +20% duration), so players don't fill everything with the cheapest food.

## Strike

- Food runs out → gnomes stop working (hungry: sit down, look sad).
- After some time hungry (a few days), they **go on strike**: when the player loads back in, all gnomes stand in front of the base with picket signs ("WE WANT CARROTS", "NO MELON NO WORK"...).
- Feeding them ends the strike: they cheer, throw away their signs and go back to work.
- The strike is a funny scene, **not a punishment**: no item loss, no gnome leaving.

## Boosts (potions)

- A per-gnome boost makes one gnome work faster for **12 hours**.
- Boosts are **potions** from a separate **potion system** shared with the player (strength, mining speed, run speed...). Design that system separately.
- Main potions are earnable in game; maybe one Robux boost later (e.g. "Golden" potion).

## Open questions

- [ ] Food duration formula (food value × quantity ÷ number of gnomes, variety bonus).
- [ ] Food values and stack limits per food.
- [ ] Time from hungry to strike.
- [ ] Hire cost and how the 3 slots unlock.
- [ ] How the player assigns tasks (UI) and how a task targets a blueprint/Chest.
- [ ] Gnome house: fixed spot per plot, or placed by the player outside the build area?
- [ ] Sell task limits.

## Tasks

- [ ] Gnome rig model + animations (idle, walk, work, hungry, strike, cheer).
- [ ] Gnome house model + picket sign models.
- [ ] Data: worker config, food values, stack limits, task definitions.
- [ ] Server: hire / slots / Robux 4th slot.
- [ ] Server: task system (online simulation + offline computation).
- [ ] Server: food consumption, hungry and strike states, saved with the player data.
- [ ] Client: food box UI with time remaining, task assignment UI, strike scene on join.
- [ ] Potion system (separate design) → gnome boosts.
- [ ] Playtest in Studio.
