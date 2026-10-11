# Hub as a kingdom: a settlement you walk through between runs

2026-10-11. Design for planning issue #38 (piece 4 of 4: workers and jobs #35, rhythm of threat #36 and run base as a settlement #37 are done). Agreed in conversation.

## Why

The hub is a text menu on the run summary. You press 1 to 6 to spend banked ore, A to J to pick crew and L for the run log. Nothing in it is a place, and the rescued miners are lines of text. Kingdoms Two Crowns is the inspiration: a persistent settlement you see, walk through and build up with what you bring home.

The PRD keeps its two rules. The hub grants capabilities that are never lost, and a separate base-defence phase between runs is out of scope. Both hold here: the hub only spends banked ore, nothing in it can be attacked, damaged or lost, and no timer or threat runs there.

## Decisions

1. **A place you see.** The hub becomes a walkable scene, not a menu and not a picture behind a menu.
2. **You walk it as the miner.** The existing `Player` walks a flat strip in the mine's drawn style. Actions happen with a key press next to a building or a miner.
3. **Four buildings, one per job.** Lamp shop, smithy, bunkhouse and notice board map onto what the hub already does. Upgrades, prices and capabilities are unchanged.
4. **Miners are drawn.** Each rostered miner is a figure by the bunkhouse. Crew is picked by standing next to a figure.
5. **Ore only.** No second currency. Relics stay a one-off payout in the mine (rejected for now: relics as a currency).
6. **Summary first, then the hub.** A run still ends on the summary. Enter goes to the hub, and the hub's mine entrance starts the next run.
7. **Mobile is out of scope.** The game has no touch input yet. The hub follows one rule so a touch layer can be added later: every action is a named function, and key handling only calls it.

## The flow

- A run ends. The summary shows the result, the ore banked or lost, the depth and the notes. It no longer lists upgrades, crew, stranded miners or the run log.
- Enter on the summary changes scene to `Hub`.
- The hub's mine entrance changes scene to `Main`, a fresh run. `Main` stays loadable on its own, so the tests and the playtest that start it directly keep working.
- The project's main scene becomes `Hub`, so every launch opens in the settlement. A new game has 0 ore, an empty roster and an empty bunkhouse.
- `Progress` is the only state that survives between scenes, through the save file, as it does now. No save format change.

## The hub scene

A flat strip, left to right: lamp shop, smithy, bunkhouse, notice board, mine entrance. The player walks it with the same movement. There is a camera with limits at both ends and the HUD's banked ore line. Nothing runs over time: no light decay, noise, clock or creatures.

## Buildings and keys

| Building | Offers | Keys beside it |
| --- | --- | --- |
| Lamp shop | Lantern tank (3 levels), Lamps unlock | `1` lantern, `2` lamps |
| Smithy | Hard hat (2 levels), Ladders unlock, Anchors unlock | `1` hard hat, `2` ladders, `3` anchors |
| Bunkhouse | Crew bunk (3 levels); the crew picker | `1` crew bunk; `E` beside a miner |
| Notice board | Run log, journal page, stranded miners | `E` shows or hides it |

- A key calls `Progress.try_buy(id)`. Prices, levels and effects are the ones in `Progress.UPGRADES`.
- The prompt line (the same one the mine uses) names the offer, its level and its cost: "1: Lantern tank Lv 1/3, 60 ore", or "OWNED" or "MAX" as today. When short of ore it says what is needed.
- **Crew.** Beside a miner's figure the prompt shows their name, rank, job and quirk. `E` joins them to the crew or takes them off, up to `Progress.crew_slots()`. At the limit it says "Crew full". Crew members have a lantern drawn at their feet, which replaces the `[CREW]` marker.
- **Stranded miners** are not drawn. The board shows the same text as today: which layer each is in, and what happens if they are not rescued.

## Art

All drawn in code in `GearArt`, shown through `ArtSprite`, like the other props.

- New gears: `"lamp_shop"`, `"smithy"`, `"bunkhouse"`, `"notice_board"` and `"entrance"`.
- Miner figures reuse the existing person art in their job's colours.
- A building shows one plain state cue that follows what you own (a lit lamp in the shop window, a lit forge in the smithy). It is a draw state, not a new level.

## Components

- **`Hub`** (new, `scripts/hub.gd`, `scenes/Hub.tscn`): builds the buildings, the miner figures and the entrance from `Progress`; owns the camera limits and the key handling. It holds no purchase rules.
- **`HubBuilding`** (new, `scripts/hub_building.gd`): one node per building. Knows its kind and its offers (a list of `Progress` upgrade ids), whether the player is in range and the prompt text. Exposes `buy(id) -> bool`, and `toggle()` for the board.
- **`HubMiner`** (new, `scripts/hub_miner.gd`): the figure for one rostered miner. Exposes `toggle_crew() -> bool`, the prompt text and whether the miner is on the crew.
- **`GearArt`** (modify): the five new gears.
- **`Main`** (modify): the summary's Enter and the run-end flow change scene to `Hub`. `_on_upgrade_requested` and `_on_crew_toggle_requested` are removed.
- **`HUD`** (modify, `scripts/hud.gd`, `scenes/HUD.tscn`): the summary keeps the result, ore, depth and notes plus an Enter prompt. `refresh_hub`, the run-log page and the `L` and A to J handling are removed from it. The controls text drops the hub line.
- **`project.godot`** (modify): the main scene is `Hub.tscn`.
- **`Progress`** (modify only if needed): no change to rules or the save. At most small read helpers for the board text.
- **Docs:** `README.md` controls and `ROADMAP.md` milestone entry.

## The named-function rule

Every hub action is a method on a hub node (`HubBuilding.buy`, `HubBuilding.toggle`, `HubMiner.toggle_crew`, `Hub.enter_mine`). The key handling in `Hub` reads the keys and calls them, and nothing else decides anything. A later touch layer can call the same methods. This is a rule for the code, not a feature.

## Edge cases

- Nothing in the hub can be lost, damaged or attacked. A bad run still costs only that run's ore and its miners (PRD).
- Short of ore: nothing is taken, and the prompt says what is needed.
- Crew full: `E` on a miner does nothing and the prompt says so. Taking someone off always works.
- The roster is capped at ten names today, so up to ten figures are drawn.
- Old saves open into the hub with their ore, upgrades, roster, crew and stranded miners. No migration.
- Esc pauses in the hub as in the mine.
- No mine state exists in the hub scene, so there is nothing to reset when a run starts.

## Out of scope

- Visible building levels, a second currency, new upgrades or capabilities.
- Miners that walk around, and any defence, threat or timer in the hub.
- Touch and mobile controls (the roadmap's open Mobile item).
- Drawing stranded miners, and any change to prices, the save format or the run.

## Testing

- **Unit (`tests/test_hub.gd`, built the way `test_main` builds `Main`):** each building offers the right upgrades; a buy takes the exact ore and raises the level; a short buy changes nothing; the figures match the roster; crew toggling respects the slot count; the prompt text in each case; the entrance changes scene; old-save roster and crew show correctly.
- **Existing tests:** `test_main` and the HUD tests change for the summary without a hub menu. All `Progress` tests stay as they are.
- **Playtest:** a scenario opens the hub, walks to the lamp shop, buys a lantern level with real keys, walks to a miner and toggles the crew, then walks to the entrance and checks that a run starts. It saves screenshots like the other scenarios. Playtest scenarios that used the summary's hub keys are updated.
- No balance probe change, because prices and capabilities do not change.

## Risks to watch

- Pause and unpause and the scene change after the summary.
- Playtest scenarios that start from `Main` and rely on the summary's old keys.
- Tests that read the old `refresh_hub` text.

## Open questions for the plan to settle, not the design

- The width of the strip and the spacing of the buildings so the prompts do not overlap.
- Where the figures stand, and in what order, so that ten fit by the bunkhouse.
- The exact wording of each prompt.
