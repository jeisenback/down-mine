# Hub as a Kingdom Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hub's text menu with a walkable, drawn settlement (four buildings, drawn miners, a mine entrance) that spends banked ore through the existing `Progress` rules.

**Architecture:** A new `Hub.tscn` scene becomes the project's main scene; `Main.tscn` stays the run. `Hub` builds `HubBuilding` and `HubMiner` nodes from `Progress`, reuses `Player` (no mine, light frozen) and `HUD`. Every action is a named method; key handling only calls them. `Progress` rules, prices and the save format do not change.

**Tech Stack:** Godot 4.5 GDScript, procedural art (`GearArt` through `ArtSprite`), the in-repo test runner and playtest.

**Spec:** `docs/superpowers/specs/2026-10-11-hub-as-kingdom-design.md`

## Global Constraints

- Prices, levels, effects and the save format stay as in `Progress.UPGRADES` and `Progress.load_saved`.
- Nothing in the hub can be lost, damaged or attacked; no timers, creatures, noise, light decay or darkness run there.
- Four buildings only: `lamp_shop`, `smithy`, `bunkhouse`, `notice_board`; plus the `entrance`. No building levels, no second currency, no wandering miners, no touch input.
- Every hub action is a method on a hub node (`HubBuilding.buy`, `HubBuilding.toggle`, `HubMiner.toggle_crew`, `Hub.enter_mine`); key handling only calls them.
- No emojis anywhere (code, text, docs, commits).
- Crew full: joining does nothing and the prompt says "Crew full"; taking someone off always works.
- Tests that add a scene set `Progress.path_override = TEST_SAVE_PATH` first and clear it after, like `test_main.gd`.

## Review Focus

- Walking into the hub's edges and pressing Space, S or Q with no mine: no script error, nothing dug (the player has `mine == null`).
- A brand-new save (0 ore, empty roster): the hub loads, prompts read sensibly, nothing errors.
- Ten rostered miners: ten figures drawn, the nearest one is picked, and the crew limit is respected.
- The player's lantern must not burn or drain health while standing in the hub for a long time.
- The summary's Enter and the entrance both leave through one injectable scene-change callable, so tests never swap the test runner's scene.

---

## File Structure

- `scripts/gear_art.gd`, `scripts/art_sprite.gd` (modify): five new gears.
- `scripts/hub_building.gd` (new): one building: offers, range, prompt, buy, board toggle and text.
- `scripts/hub_miner.gd` (new): one rostered miner's figure and crew toggle.
- `scripts/hub.gd`, `scenes/Hub.tscn` (new): the settlement scene.
- `scripts/progress.gd` (modify): two text helpers (`member_summary`, `stranded_line`).
- `scripts/hud.gd`, `scenes/HUD.tscn` (modify): hub mode; summary loses the hub menu.
- `scripts/main.gd` (modify): leave for the hub instead of reloading; drop the hub purchase handlers.
- `project.godot`, `README.md`, `ROADMAP.md` (modify).
- Tests: `tests/test_hub.gd` (new), `tests/test_art_sprite.gd`, `tests/test_main.gd`, `tests/playtest.gd` (modify).

---

### Task 1: Five drawn gears (with a preview checkpoint)

**Files:**
- Modify: `scripts/gear_art.gd` (enum, `_draw` match, five `_draw_*`), `scripts/art_sprite.gd` (`GEAR_KINDS`), `tools/preview_gear.gd` (add rows)
- Test: `tests/test_art_sprite.gd`

**Interfaces:**
- Produces: gear names `"lamp_shop"`, `"smithy"`, `"bunkhouse"`, `"notice_board"`, `"entrance"` for `ArtSprite.kind` and `GearArt.gear`. For `lamp_shop` and `smithy`, `pose` 0.0 is unlit and 1.0 is lit (the "owned" cue). Origin is the feet, centre of the building; each fits in a 48 by 48 cell except the bunkhouse and entrance, which are drawn up to 40 px wide and 32 px tall.

- [ ] **Step 1: Write the failing test** in `tests/test_art_sprite.gd`: `test_the_hub_gears_build_gear_art` loops the five names, builds an `ArtSprite` with `kind` set, adds it, awaits one `process_frame`, and asserts `art.art is GearArt` and `art.art.gear == name`.
- [ ] **Step 2: Run** `timeout 250 /opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd`. Expected: the new test FAILS (kind not in `GEAR_KINDS`, `art` is null).
- [ ] **Step 3: Implement** the five gears. Add the names to `GearArt`'s `@export_enum`, its `_draw` match and `ArtSprite.GEAR_KINDS`. Draw in the existing style (`GPAL` palettes, `_glow`, `_blob`): lamp shop is a small wooden shop with a window that glows when `pose` is 1.0; smithy is a stone forge with a chimney and a fire that glows at `pose` 1.0; bunkhouse is a long low timber house with three doors; notice board is a post with a board and pinned paper; entrance is a timbered mine mouth with a dark opening and a lantern. Animation uses `t` like the others.
- [ ] **Step 4: Preview.** Add the five gears (lamp_shop and smithy at pose 0.0 and 1.0) to `tools/preview_gear.gd` ROWS, run `xvfb-run -a /opt/godot/godot --fixed-fps 60 -s tools/preview_gear.gd`, and show the sheet to the user. Do not continue to Task 2 until the user approves the look; redraw on feedback.
- [ ] **Step 5: Run** the unit suite; expect all PASS. **Commit** `Hub art: lamp shop, smithy, bunkhouse, notice board, entrance`.

---

### Task 2: `Progress` text helpers, `HubBuilding`, `HubMiner`

**Files:**
- Modify: `scripts/progress.gd`
- Create: `scripts/hub_building.gd`, `scripts/hub_miner.gd`
- Test: `tests/test_hub.gd` (create; later tasks add to it)

**Interfaces:**
- Produces on `Progress`:
  - `func member_summary(member: Dictionary) -> String`: `"<Rank> <Type label>: <effect_text> (<N run(s)>, from <layer>[; <Quirk name>])"`, exactly the pieces `HUD.refresh_hub` builds today.
  - `func stranded_line(npc: Dictionary) -> String`: `"Stranded: <name> in the <layer> - <fate>"`, the same text `refresh_hub` builds today.
- Produces `HubBuilding extends Node2D, class_name HubBuilding`:
  - `const OFFERS := {"lamp_shop": ["lantern", "lamps"], "smithy": ["hard_hat", "ladders", "anchors"], "bunkhouse": ["crew_bunk"], "notice_board": []}`; `const RANGE := 28.0`
  - `var kind: String`, `var progress: Progress`, `var board_open: bool = false`
  - `func offers() -> Array`; `func in_range(pos: Vector2) -> bool` (distance on x only, below `RANGE`)
  - `func buy(slot: int) -> bool`: `slot` is 1-based into `offers()`; calls `progress.try_buy`; false on a bad slot, short ore or maxed.
  - `func prompt() -> String`: offers joined by five spaces, each `"<slot>: <name> Lv <level>/<max>, <cost> ore"`, `"... OWNED"` for a one-level unlock already bought, `"... MAX"` for a maxed level upgrade, and `" (need <n> more)"` appended when `banked_ore` is below the cost. The bunkhouse adds nothing about miners. The notice board returns `"E: notice board"`.
  - `func toggle() -> void` (notice board: flips `board_open`); `func board_text() -> String`: `"RECENT RUNS (newest first)"` plus `Progress.run_log_line` per entry (or `"No runs logged yet"`), the latest journal page (`Progress.JOURNAL[journal_read - 1]`, only when `journal_read > 0`), then each `stranded_line`.
  - `func owned_cue() -> float`: 1.0 when the building's first offer (lamp shop, smithy) has level 1 or more, else 0.0; used as the art `pose`.
- Produces `HubMiner extends Node2D, class_name HubMiner`:
  - `const RANGE := 8.0`; `var member: Dictionary`, `var progress: Progress`
  - `func on_crew() -> bool`; `func toggle_crew() -> bool` (leaving always works; joining fails when `progress.crew().size() >= progress.crew_slots()`; calls `progress.toggle_crew(member.name)` only when it acts)
  - `func prompt() -> String`: `"E: <display_name> - <member_summary>"` followed by `" - join crew"`, `" - leave crew"`, or `" - Crew full"`.

- [ ] **Step 1: Write failing tests** in `tests/test_hub.gd` (use `Progress.load_saved(TEST_SAVE_PATH)`-style setup like `test_rules.gd`'s `_progress()`):
  - `test_each_building_offers_its_upgrades`: `OFFERS` values per kind.
  - `test_buying_takes_the_exact_ore_and_raises_the_level`: 100 ore, lamp shop slot 1 buys lantern level 1 for 30; ore 70, level 1.
  - `test_a_short_or_maxed_buy_changes_nothing`: 10 ore buy returns false, ore 10; a bad slot 9 returns false.
  - `test_prompt_wording`: `"1: Lantern tank Lv 0/3, 30 ore"` with enough ore; with 10 ore it ends `"(need 20 more)"`; unlock bought shows `OWNED`; third hard hat level shows `MAX`.
  - `test_a_new_save_has_sensible_text`: 0 ore, empty roster: the board text contains `"No runs logged yet"` and no journal line.
  - `test_board_text_shows_log_journal_and_stranded`.
  - `test_crew_toggle_respects_the_slots`: one slot, two roster miners; second `toggle_crew()` returns false and the prompt ends `"Crew full"`; the on-crew miner leaves, then the other can join.
- [ ] **Step 2: Run** the suite: new tests FAIL (classes missing).
- [ ] **Step 3: Implement** the helpers and the two classes. `HubBuilding.prompt` and `HubMiner.prompt` read live `Progress` state, with no caching. Move the exact strings out of `HUD.refresh_hub` into the two `Progress` helpers (the HUD copy is deleted in Task 4).
- [ ] **Step 4: Run** the suite: PASS. **Commit** `Hub: buildings and miners as small units over Progress`.

---

### Task 3: The `Hub` scene

**Files:**
- Create: `scripts/hub.gd`, `scenes/Hub.tscn`
- Modify: `scripts/hud.gd`, `scenes/HUD.tscn` (hub mode only here)
- Test: `tests/test_hub.gd`

**Interfaces:**
- Consumes: `HubBuilding`, `HubMiner`, `ArtSprite` kinds from Task 1, `Progress.load_saved()`, `Player`, `HUD`.
- Produces `HUD.set_hub_mode() -> void`: hides the Fuel, Health, Layer, Noise, NoiseBar, Ore, Base, Wave, Lamp and Escort rows and the compass, keeps Banked, and sets the Esc overlay text to `HUB_CONTROLS_TEXT` (new constant: walk with A / D, `1`-`3` buy at a building, `E` use, Esc closes). `CONTROLS_TEXT` loses its "At the hub" line.
- Produces `Hub extends Node2D, class_name Hub`:
  - `const STRIP_WIDTH := 720.0`; building x positions `lamp_shop 100, smithy 200, bunkhouse 300, notice_board 540, entrance 640`; miner figures from x 340 in steps of 14 (ten fit before the board).
  - `var progress: Progress`, `var player: Player`, `var hud: HUD`, `var buildings: Array[HubBuilding]`, `var miners: Array[HubMiner]`
  - `var change_scene: Callable` defaults to `func(path): get_tree().change_scene_to_file(path)`
  - `func nearest_building() -> HubBuilding` (null if none in range); `func nearest_miner() -> HubMiner` (null if none within `HubMiner.RANGE`)
  - `func press_number(n: int) -> bool` (buy slot `n` at the nearest building); `func press_use() -> bool` (miner toggle, else board toggle, else entrance); `func enter_mine() -> void` (calls `change_scene.call("res://scenes/Main.tscn")`); `func at_entrance() -> bool`
  - `_unhandled_input` maps keys 1 to 3 to `press_number` and E to `press_use`. `_process` updates `hud.update_prompts` and `hud.update_banked`, and keeps each lamp shop and smithy art `pose` at `owned_cue()`.

- [ ] **Step 1: Write failing tests** in `tests/test_hub.gd` (build with `load("res://scenes/Hub.tscn").instantiate()`, `add()`, `physics_frames`):
  - `test_the_hub_loads_with_a_new_save`: no errors, four buildings, no miners, banked label reads `Banked: 0`.
  - `test_one_figure_per_rostered_miner_up_to_ten`: ten roster entries give ten `HubMiner` nodes at distinct x.
  - `test_pressing_a_number_buys_at_the_nearest_building`: player placed at the lamp shop, 100 ore, `press_number(1)` buys the lantern; at the smithy `press_number(3)` buys anchors only with enough ore; away from any building it returns false.
  - `test_use_toggles_the_nearest_miner_or_the_board`: beside a miner it toggles crew; beside the board it flips `board_open`.
  - `test_the_entrance_changes_scene`: replace `change_scene` with a lambda recording the path, put the player at the entrance, `press_use()`; the path is `"res://scenes/Main.tscn"`; away from the entrance it is not called.
  - `test_keys_call_the_named_functions`: send an `InputEventKey` for KEY_1 and KEY_E through `_unhandled_input`; effects match the named calls.
  - `test_the_lantern_does_not_burn_in_the_hub`: after 120 physics frames the player's `light.fuel` equals `max_fuel` and health is unchanged.
  - `test_space_s_and_q_do_nothing_in_the_hub`: parse those key presses for 30 frames; no script errors, no change in the player's state beyond position.
- [ ] **Step 2: Run** the suite: new tests FAIL.
- [ ] **Step 3: Implement** `Hub` and `Hub.tscn` (a backdrop `ColorRect`, a ground `StaticBody2D` with one rectangle shape spanning the strip, the `Player` instance with `mine` left null and `light.set_process(false)`, camera limits `0` to `STRIP_WIDTH`, no `CanvasModulate`, the `HUD` instance added last with `set_hub_mode()`, and a small panel `Label` for `board_text()` shown while `board_open`). Buildings and miners are built in `_ready` from the loaded `Progress`; each building is a `HubBuilding` with an `ArtSprite` child named `Art` of its kind; each miner is a `HubMiner` with an `ArtSprite` of kind `"player"` whose `coat` comes from `Main.MINER_COLORS.get(name, Color(1, 1, 1)).darkened(0.2)` and a lantern (kind `"lamp"`) child shown only while on crew.
- [ ] **Step 4: Run** the suite: PASS. **Commit** `Hub: the settlement scene you walk through`.

---

### Task 4: Wire the flow, trim the summary, retire the menu

**Files:**
- Modify: `scripts/main.gd`, `scripts/hud.gd`, `scenes/HUD.tscn` (nothing to add), `project.godot`
- Test: `tests/test_main.gd`, `tests/test_hub.gd`

**Interfaces:**
- Consumes: `Hub` scene path `res://scenes/Hub.tscn`.
- Produces on `Main`: `var change_scene: Callable` (same default as `Hub`); `_start_new_run` is renamed `_go_to_hub` and calls `get_tree().paused = false` then `change_scene.call("res://scenes/Hub.tscn")`.
- `HUD` loses `upgrade_requested`, `crew_toggle_requested`, `ROSTER_KEYS`, `showing_run_log`, `_progress`, `refresh_hub`, `_show_run_log` and the key handling for L, digits and letters. `show_run_summary(title, success, currency, depth, progress, notes)` keeps its signature and shows the header lines plus `"Enter: go to the hub"`. `new_run_requested` stays and is emitted on Enter.

- [ ] **Step 1: Write failing tests:**
  - In `test_main.gd`, replace `test_run_log_records_runs_and_causes`'s hub assertions: the summary text contains `"Enter: go to the hub"` and `"Died (Stalker)"` (death cause comes from the run log entry, still recorded); the log entry assertions stay; the pressing-L assertions are removed.
  - `test_enter_on_the_summary_leaves_for_the_hub` in `test_main.gd`: replace `main.change_scene` with a recorder, end the run, emit Enter through `hud._unhandled_input`; the recorded path is `"res://scenes/Hub.tscn"` and the tree is unpaused.
  - `test_main_has_no_hub_purchase_handlers`: `main.has_method("_on_upgrade_requested")` and `"_on_crew_toggle_requested"` are false.
- [ ] **Step 2: Run** the suite: the three tests FAIL.
- [ ] **Step 3: Implement** the changes above, delete the dead HUD code and the two Main handlers, drop the hub keys from `CONTROLS_TEXT`'s last line, and set `run/main_scene="res://scenes/Hub.tscn"` in `project.godot`.
- [ ] **Step 4: Update `tests/playtest.gd`:** the `_heart_run` scenario's final `L` step (run log on the summary) is replaced by asserting the summary mentions the win and `"Enter: go to the hub"`. Run the suite (PASS).
- [ ] **Step 5: Commit** `Hub: runs end in the hub; the menu comes out of the summary`.

---

### Task 5: Playtest scenario and docs

**Files:**
- Modify: `tests/playtest.gd`, `README.md`, `ROADMAP.md`
- Test: `tests/playtest.gd`

- [ ] **Step 1: Add scenario `hub_buy_crew_and_descend`** to the playtest list. It saves a roster of two miners and 100 banked ore to the playtest save, loads `Hub.tscn` as the scene, and with real keys: walks to the lamp shop and taps `1` (lantern level 1, ore 70, checked on `Progress`), walks to the first miner and taps `E` (crew toggled), checks the prompt text for the nearest building and miner at each stop and takes a screenshot at each (`shot`), walks to the entrance, replaces `change_scene` with a recorder, taps `E`, and asserts the path is `Main.tscn`. Check that no `RunBase`, creature or mine node exists in the hub.
- [ ] **Step 2: Run** `xvfb-run -a /opt/godot/godot --fixed-fps 60 -s tests/playtest.gd`. Expected: all scenarios ok, the new one included; screenshots show four buildings, the figures and the prompt.
- [ ] **Step 3: Docs.** README: controls section replaces the hub keys (1 to 6, A to J, L) with the hub controls and describes the flow (summary, then hub, then the entrance); ROADMAP: add the milestone entry (M57) listing the hub as a kingdom (#38) done, mobile still open. Fix README line 8 ("No crew, hub, or stranding yet").
- [ ] **Step 4: Run** the full unit suite and the playtest once more; both green. **Commit** `Hub: playtest scenario and docs`.

---

## Self-review notes

- Spec coverage: flow (Task 4), scene (Task 3), buildings and keys (Task 2 and 3), crew picking and "Crew full" (Task 2), board (Task 2), art (Task 1), named-function rule (Task 2 and 3 interfaces, keys test in Task 3), edge cases (new save, ten miners, short ore in Task 2 and 3 tests; lantern and dig keys in Task 3), testing (all tasks), docs (Task 5). Old saves need no code: nothing in the save changes.
- Behaviour change to note in the PR: joining a full crew now does nothing, where the old picker bumped the longest-serving member off.
- Deferred by design: building levels, relics as a currency, touch input, drawing stranded miners.
