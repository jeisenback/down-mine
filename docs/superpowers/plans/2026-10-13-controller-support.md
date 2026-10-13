# Controller Support Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Play the title, hub, a full run and the summary on a gamepad, with help text and prompts that name the pad's buttons.

**Architecture:** A gamepad is another source of the synthetic keys the touch controls already inject (`TouchKeys`), so `player.gd`, the mine, the events and the base do not change. A pure `GamepadMap` holds the layout and the tool cycle; a `GamepadControls` node (one in Main, one in Hub) forwards joypad events to named methods; `ControlScheme` decides whether text names keys, touch buttons or pad buttons.

**Tech Stack:** Godot 4.5 GDScript; headless tests (`/opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd`, run `--headless --import` first after adding a `class_name` file); playtest `tests/playtest.gd` under xvfb.

**Spec:** `docs/superpowers/specs/2026-10-13-controller-support-design.md`

## Global Constraints

- No change to `scripts/player.gd`, `scripts/mine.gd` or the events. The only gameplay-facing seam is `TouchKeys`.
- Pad key source id is `"pad"`; the existing touch default source is `"touch"`. Existing `TouchKeys.set_key(code, down)` callers and tests keep working unchanged.
- Tap buttons hold their key `TouchControls.TAP_HOLD_FRAMES` (3) physics frames; hold buttons hold it while the button is down.
- Thresholds: a trigger is pressed above `GamepadMap.TRIGGER_THRESHOLD` (0.5); the left stick goes through `TouchPad.keys_for(offset, 1.0)` (dead zone 0.3, stair zone 0.5).
- `GamepadControls` runs while the game is paused (`process_mode = PROCESS_MODE_ALWAYS`); menu mode is `get_tree().paused` (the HUD pauses for every overlay and the run summary).
- Layout (Xbox names; Godot `JOY_BUTTON_*` and `JOY_AXIS_*`):
  - Mine: left stick and d-pad = A / D / W / S (down plus a side digs stairs); A = W (hold, so a jump can be a short hop); X = Space (hold); B = E (tap); Y = the selected tool's keys (hold for Repair, tap otherwise); LB / RB = previous / next tool; RT = Shift (hold); Start = Esc (tap).
  - Hub: stick / d-pad = A / D / W; A = W (hold); B = E (tap); X / Y / RB = 1 / 2 / 3 (tap); Start = Esc.
  - Menu (tree paused): A = Enter, B = Esc, X = X (abandon), Start = Esc, all taps; directions are released.
- Help and prompts: scheme `"pad"` names `A` for Enter, `Start` for Esc, `B` for E, and `LB/RB then Y` for the tool and base keys (B, P, U, F, 1); in the hub (`keep_digits`) `1 2 3` read `X Y RB`.
- No emojis anywhere (user preference).

## Review Focus

1. **Pad unplugged or a pad button held across a pause**: every key a button pressed is released when the button is released or the pad disconnects, even if the mode changed in between (X held for dig, an overlay opens, X lifted in the menu: Space is released, no stray X).
2. **The pad's own synthetic keys must not flip the scheme back to keys**: a key event is real only when `TouchKeys` is not already holding that key.
3. **Stick noise and diagonals**: below the dead zone nothing is pressed; a drift off a straight line does not start a stair; stick and d-pad together never leave a direction stuck.
4. **Tool cycle edges**: an empty list (no crash, Y does nothing), the selected tool disappearing (Repair selected, the base left behind: fall back to the first), wrap in both directions.
5. **Two key sources**: touch and pad holding the same key, one releasing; a key stays down until both let go.

---

## Phase 1 (one PR)

### Task 1: `TouchKeys` knows its sources

**Files:**
- Modify: `scripts/touch_keys.gd`
- Test: `tests/test_touch.gd`

**Interfaces:**
- Produces: `TouchKeys.set_key(code: int, down: bool, source: String = "touch") -> void` (a key is down while any source holds it; an event is sent only when the key's overall state changes); `TouchKeys.release_all(source: String = "") -> void` (that source's keys only, or every source when empty); `TouchKeys.is_down(code: int) -> bool` unchanged in meaning; `sent_count` unchanged.

- [ ] **Step 1: Write failing tests** in `tests/test_touch.gd`:
  - `test_two_sources_hold_a_key_between_them`: `TouchKeys.release_all()`; before = `sent_count`; `set_key(KEY_W, true, "touch")`, `set_key(KEY_W, true, "pad")` -> `sent_count == before + 1` and `is_down(KEY_W)`; `set_key(KEY_W, false, "touch")` -> still down, `sent_count == before + 1`; `set_key(KEY_W, false, "pad")` -> not down, `sent_count == before + 2`.
  - `test_release_all_for_one_source_leaves_the_other`: touch and pad both hold `KEY_A`, pad holds `KEY_D` alone; `release_all("pad")` -> `KEY_A` still down (touch), `KEY_D` up; `release_all()` -> both up.
- [ ] **Step 2:** Run the suite. Expected: FAIL (`set_key` has no third parameter, so `test_touch.gd` does not compile).
- [ ] **Step 3: Implement** the signatures above in `scripts/touch_keys.gd`: replace `_down` by a `Dictionary` mapping a key code to an `Array` of source names; the existing single-source behavior is the `"touch"` source.
- [ ] **Step 4:** Run the suite. Expected: all pass (the existing touch tests unchanged).
- [ ] **Step 5:** Commit `TouchKeys: keys held by sources (no behaviour change)`.

### Task 2: `GamepadMap` and `ControlScheme` (pure)

**Files:**
- Create: `scripts/gamepad_map.gd`, `scripts/control_scheme.gd`, `tests/test_gamepad.gd`
- Modify: `tests/test_hooks.gd` (reset `ControlScheme.pad_last`, list it in `RESET`)

**Interfaces:**
- Produces `GamepadMap` (`class_name`, RefCounted, static only):
  - `const TRIGGER_THRESHOLD := 0.5`
  - `static func stick_keys(offset: Vector2) -> Array` = `TouchPad.keys_for(offset, 1.0)`
  - `static func cycle_list(tools_available: Array, can_plant: bool, base_nearby: bool) -> Array` = `tools_available` then `"base_plant"` when `can_plant`, then `"base_repair"`, `"base_fortify"`, `"base_grow"` when `base_nearby` (names are `TouchControls.WIDGETS` keys)
  - `static func cycle(list: Array, current: String, step: int) -> String` (next or previous, wrapping; `current` not in the list gives the first; an empty list gives `""`)
  - `static func tool_label(name: String) -> String` (`"tool_rope"` -> `"Rope"`, `"base_plant"` -> `"Plant"`, `"base_repair"` -> `"Repair"`, `"base_fortify"` -> `"Fortify"`, `"base_grow"` -> `"Grow"`, and the other `tool_*` names capitalized)
  - `static func tool_keys(name: String) -> Array` and `static func tool_holds(name: String) -> bool` from `TouchControls.WIDGETS[name]` (`keys`, `hold`)
- Produces `ControlScheme` (`class_name`, RefCounted): `static var pad_last: bool = false`; `static func current() -> String` (`"pad"` when `pad_last`, else `"touch"` when `TouchControls.wanted()`, else `"keys"`); `static func note_joypad() -> void` (sets `pad_last`); `static func note_key(event: InputEventKey) -> void` (clears `pad_last` only for a pressed event whose `physical_keycode` is not currently held by `TouchKeys`).

- [ ] **Step 1: Write failing tests** in `tests/test_gamepad.gd` (`extends TestCase`):
  - `test_stick_keys_follow_the_touch_pad_rule`: `stick_keys(Vector2(0.9, 0)) == [KEY_D]`, `Vector2(-0.9, 0) == [KEY_A]`, `Vector2(0, -0.9) == [KEY_W]`, `Vector2(0.2, 0.2) == []`, `Vector2(0.7, 0.7)` has `KEY_D` and `KEY_S` and size 2.
  - `test_cycle_list_adds_base_actions_only_when_they_apply`: with `["tool_rope", "tool_grapple"]`: `(false, false)` gives those two; `(true, false)` adds `"base_plant"`; `(false, true)` adds `"base_repair"`, `"base_fortify"`, `"base_grow"`; `(true, true)` adds all four in that order.
  - `test_cycle_wraps_and_survives_edges`: `cycle(["a","b","c"], "c", 1) == "a"`, `cycle(["a","b","c"], "a", -1) == "c"`, `cycle(["a","b"], "zzz", 1) == "a"`, `cycle([], "a", 1) == ""`.
  - `test_tool_labels_and_keys`: `tool_label("tool_rope") == "Rope"`, `tool_label("base_repair") == "Repair"`, `tool_keys("tool_rope") == [KEY_R]`, `tool_holds("base_repair")` true, `tool_holds("tool_rope")` false.
  - `test_the_scheme_follows_the_last_input`: `ControlScheme.pad_last = false`; `TouchControls.force = false`; `current() == "keys"`; `note_joypad()`; `current() == "pad"`; a pressed `InputEventKey` for `KEY_Z` through `note_key` -> `current()` is no longer `"pad"`; with `TouchKeys.set_key(KEY_Z, true, "pad")` held, `note_joypad()` then `note_key` of a pressed `KEY_Z` leaves `"pad"` (the key is the pad's own); release the key afterwards; `TouchControls.force = true` gives `"touch"` once `pad_last` is false.
- [ ] **Step 2:** Run `--headless --import`, then the suite. Expected: FAIL (the classes do not exist).
- [ ] **Step 3: Implement** the signatures above. Add `"ControlScheme.pad_last"` to `TestHooks.RESET` and `ControlScheme.pad_last = false` to `TestHooks.reset`.
- [ ] **Step 4:** Run the suite. Expected: pass.
- [ ] **Step 5:** Commit `GamepadMap and ControlScheme`.

### Task 3: `GamepadControls`

**Files:**
- Create: `scripts/gamepad_controls.gd`
- Test: `tests/test_gamepad.gd`

**Interfaces:**
- Consumes: `TouchKeys` sources (Task 1); `GamepadMap`, `ControlScheme` (Task 2).
- Produces `GamepadControls` (`class_name`, extends Node, `process_mode = PROCESS_MODE_ALWAYS` set in `_init`): `var mode: String = "mine"`; `func set_mode(new_mode: String) -> void` (`"mine"` or `"hub"`; releases everything); `func set_tools_available(names: Array) -> void`; `func set_base_nearby(near: bool) -> void`; `func set_can_plant(allowed: bool) -> void`; `func button(index: int, pressed: bool) -> void`; `func axis(axis: int, value: float) -> void`; `func release_all() -> void` (releases every key held by source `"pad"`); `func selected_tool() -> String`; `_input(event)` forwards `InputEventJoypadButton` and `InputEventJoypadMotion` to `button` / `axis` and calls `ControlScheme.note_joypad()`, and passes `InputEventKey` to `ControlScheme.note_key`; it connects `Input.joy_connection_changed` and releases everything on a disconnect; `_physics_process` ends tap holds after 3 frames. Every key a button presses is remembered per button, so the same keys are released when that button is released.

- [ ] **Step 1: Write failing tests** in `tests/test_gamepad.gd` (drive the named methods on `GamepadControls.new()` added with `add(...)`; read `TouchKeys.is_down`; call `release_all()` at the end of each test):
  - `test_the_stick_and_dpad_make_the_direction_keys`: `axis(JOY_AXIS_LEFT_X, 0.9)` -> `KEY_D` down, back to 0 -> up; `axis(JOY_AXIS_LEFT_Y, 0.9)` and `axis(JOY_AXIS_LEFT_X, 0.8)` -> `KEY_S` and `KEY_D` (a stair); `button(JOY_BUTTON_DPAD_LEFT, true)` -> `KEY_A`; with stick right and d-pad left both held, `KEY_A` and `KEY_D` are both down and releasing the d-pad leaves `KEY_D`.
  - `test_a_is_jump_x_is_dig_rt_is_flare_in_the_mine`: `button(JOY_BUTTON_A, true)` -> `KEY_W` down and up on release; `button(JOY_BUTTON_X, ...)` -> `KEY_SPACE` held; `axis(JOY_AXIS_TRIGGER_RIGHT, 0.4)` -> `KEY_SHIFT` up, `0.6` -> down.
  - `test_b_uses_and_taps_hold_their_key_three_frames`: `button(JOY_BUTTON_B, true)` -> `KEY_E` down; `button(JOY_BUTTON_B, false)` -> still down; after three `_physics_process(0.0)` calls -> up.
  - `test_the_tool_cycle_and_y`: `set_tools_available(["tool_rope", "tool_grapple", "tool_beam"])`; `selected_tool() == "tool_rope"`; RB (`JOY_BUTTON_RIGHT_SHOULDER`) -> `"tool_grapple"`; LB twice -> `"tool_beam"` (wraps); Y -> `KEY_R`... with Rope selected Y presses `KEY_R` (tap), with Grapple `KEY_Q`; with `set_base_nearby(true)` and Repair selected, Y holds `KEY_F` while held and releases on lift.
  - `test_the_selected_tool_falls_back_when_it_leaves_the_list`: select Repair (base nearby), then `set_base_nearby(false)` -> `selected_tool()` is the first tool; an empty list gives `""` and Y presses nothing.
  - `test_hub_buttons`: `set_mode("hub")`: X -> `KEY_1` (tap), Y -> `KEY_2`, RB -> `KEY_3`, B -> `KEY_E`; X does not dig.
  - `test_menu_mode_remaps_the_buttons_while_paused`: `tree.paused = true` (restore it after): A -> `KEY_ENTER`, B -> `KEY_ESCAPE`, X -> `KEY_X`, Start (`JOY_BUTTON_START`) -> `KEY_ESCAPE`; the stick presses no direction.
  - `test_a_button_releases_what_it_pressed_even_after_the_mode_changed`: X down in the mine (`KEY_SPACE` held), `tree.paused = true`, X up -> `KEY_SPACE` is up and `KEY_X` was never pressed.
  - `test_release_all_and_disconnect_let_go`: hold X, A and the stick, `release_all()` -> no `"pad"` key is down; hold again, then emit `Input.joy_connection_changed` with `connected == false` (call the handler directly: `_on_joy_connection_changed(0, false)`) -> none down.
  - `test_pad_and_touch_share_a_key`: touch holds `KEY_D`, pad stick presses and releases `KEY_D` -> still down; touch releases -> up.
- [ ] **Step 2:** Run the suite. Expected: FAIL (the class does not exist).
- [ ] **Step 3: Implement** `GamepadControls` per the Interfaces block. Directions are the union of the stick's keys, the d-pad buttons and A (as `KEY_W`), applied each time any of them changes; Start, A, B, X in menu mode and the hub's X / Y / RB are taps; the mode table in Global Constraints is the whole mapping.
- [ ] **Step 4:** Run the suite. Expected: pass.
- [ ] **Step 5:** Commit `GamepadControls: a gamepad becomes the same keys`.

### Task 4: Wire it into Main and Hub; the tool line

**Files:**
- Modify: `scripts/main.gd` (near `touch_controls`, lines about 196-199 and 406-409), `scripts/hub.gd` (near line 60), `scripts/hud.gd` (`update_tools`)
- Test: `tests/test_main.gd`, `tests/test_gamepad.gd`

**Interfaces:**
- Consumes: `GamepadControls` (Task 3).
- Produces: `Main.gamepad_controls: GamepadControls` (created beside `touch_controls`, `set_mode("mine")`, fed every frame with `set_tools_available(_touch_tools())`, `set_base_nearby(_near_base())`, `set_can_plant(_can_plant())`); `Hub.gamepad_controls` (`set_mode("hub")`); `HUD.pad_tool_text: String` (empty by default) appended to the tool line by `update_tools` as `"Tool: <text>"` when non-empty, and Main sets it each frame to `GamepadMap.tool_label(gamepad_controls.selected_tool())` only while `ControlScheme.current() == "pad"` (otherwise `""`).

- [ ] **Step 1: Write failing tests**:
  - `test_main_builds_a_gamepad_controls_in_mine_mode` in `tests/test_main.gd`: `main.gamepad_controls` is a `GamepadControls`, `mode == "mine"`; after `physics_frames(3)`, `main.gamepad_controls.selected_tool()` is `"tool_rope"` (the first of `_touch_tools()`).
  - `test_the_tool_line_names_the_selected_tool_on_the_pad` in `tests/test_gamepad.gd`: with a `HUD` scene instance, `pad_tool_text = "Rope"` then `update_tools({}, false)` -> `lamp_label.text == "Tool: Rope"` and visible; with `""` the line is as before.
  - `test_the_hub_has_a_gamepad_controls_in_hub_mode` in the hub test file (where `Hub` is instantiated; use the file that already builds it): `hub.gamepad_controls.mode == "hub"`.
- [ ] **Step 2:** Run the suite. Expected: FAIL.
- [ ] **Step 3: Implement** the wiring and the HUD line.
- [ ] **Step 4:** Run the suite. Expected: pass.
- [ ] **Step 5:** Commit `Wire the gamepad into Main, Hub and the tool line`.

### Task 5: Text for the pad scheme

**Files:**
- Modify: `scripts/key_hint.gd`, `scripts/hud.gd` (`_touch()` and its 7 call sites, the overlay texts, `esc_hint`)
- Test: `tests/test_touch.gd`, `tests/test_gamepad.gd`

**Interfaces:**
- Produces: `KeyHint.label(key: String, scheme)` and `KeyHint.prompt(text: String, scheme, keep_digits: bool = false)`, where `scheme` is `"keys"`, `"touch"` or `"pad"` (a `bool` still works: `true` is `"touch"`, `false` is `"keys"`, so the existing call sites and tests are unchanged); `KeyHint.PAD_BUTTONS := {"E": "B", "B": "LB/RB then Y", "P": "LB/RB then Y", "U": "LB/RB then Y", "F": "LB/RB then Y", "1": "LB/RB then Y", "Enter": "A", "Esc": "Start"}`; `KeyHint.PAD_HUB_DIGITS := {"1": "X", "2": "Y", "3": "RB"}`; `HUD._scheme() -> String` (returns `ControlScheme.current()`); `HUD.GAMEPAD_CONTROLS_TEXT`, `HUD.GAMEPAD_HUB_CONTROLS_TEXT`, `HUD.GAMEPAD_ABANDON_ASK` (the abandon prompt with `X` and `B` named as the pad buttons), and the controls overlay and the title text choose by scheme. On the pad scheme `esc_hint` reads `Start: controls` and stays visible.

- [ ] **Step 1: Write failing tests**:
  - `test_key_hints_name_the_pads_buttons` in `tests/test_gamepad.gd`: `KeyHint.label("E", "pad") == "B"`, `label("Enter", "pad") == "A"`, `label("Esc", "pad") == "Start"`, `label("P", "pad") == "LB/RB then Y"`, `label("Z", "pad") == "Z"`; `KeyHint.prompt("E: extract", "pad") == "B: extract"`; `prompt("P: plant base here", "pad") == "LB/RB then Y: plant base here"`; hub digits: `prompt("1: buy", "pad", true) == "X: buy"`, `"3: buy"` -> `"RB: buy"`; `prompt("1: buy", "keys", true) == "1: buy"`; the bool forms still give the old answers (`label("E", true) == "Use"`).
  - `test_the_overlays_name_the_pad_when_it_was_used_last`: with a `HUD` instance and `ControlScheme.pad_last = true` (reset after), the controls overlay text contains `"Start"` and `"LB / RB"` and not `"Space"`; the hub variant (`_hub_mode = true`) contains `"X / Y / RB"` and `"buy"`; the title text names `A` and `Start`; `esc_hint.text` is `"Start: controls"` and it is visible.
- [ ] **Step 2:** Run the suite. Expected: FAIL.
- [ ] **Step 3: Implement.** Texts: `GAMEPAD_CONTROLS_TEXT` lists, one line each: `Stick / D-pad  move (up: jump)   A  jump   X  dig (hold; stick up: dig up)`, `Stick down  dig down (with a side: stairs)`, `RT  flare the light   B  use a camp, lift, outpost, vault or relic - or extract`, `LB / RB  pick a tool (rope, grapple, beam, ladder, lamp, anchor; at the base: repair, fortify, grow; plant)   Y  use it (hold to repair)`, `Start  close this`; `GAMEPAD_HUB_CONTROLS_TEXT`: `Stick / D-pad  walk   A  jump`, `X / Y / RB  buy at the building you stand beside (1 2 3)`, `B  join or leave the crew beside a miner, open the notice board, or go down the mine`.
- [ ] **Step 4:** Run the suite. Expected: pass (the existing touch and keyboard text tests unchanged).
- [ ] **Step 5:** Commit `Help and prompts name the pad's buttons`.

### Task 6: Playtest scenario, docs, PR

**Files:**
- Modify: `tests/playtest.gd`, `ROADMAP.md`, `README.md` (controls section, if it lists the controls)

- [ ] **Step 1:** Add the scenario `gamepad_play` to `tests/playtest.gd`: start the mine (`_in_shaft()`); set `ControlScheme.pad_last = true`; drive `main.gamepad_controls` through its named methods only: stick right for 30 frames (the player's x increases), `button(JOY_BUTTON_X, true)` for 20 frames facing rock (a cell is dug or the player advances), cycle with RB and press Y (a rope appears: `get_nodes_in_group(Groups.ROPES)` grows, or the group constant that Rope uses), press Start (`get_tree().paused` true, overlay text contains `Start`), `shot("pad_controls")`, press B (closed); take `shot("pad_tool_line")` with the tool line showing. Reset `ControlScheme.pad_last` at the end.
- [ ] **Step 2:** Run the scenario alone under xvfb (a throwaway copy of the playtest filtered to it, as earlier scenarios were run) and then the whole playtest; both pass.
- [ ] **Step 3:** ROADMAP M83 (what was built, the layout, what was and was not tested: no real hardware) and a README line under the controls if it lists them. Run the full unit suite. Commit, push, open the PR with: the layout table, the tests, the screenshots (CI artifact), the note that the layout and the tool cycle need a hand play with a real controller, and the open fallback (a dedicated Rope button) from the spec. Subscribe to the PR; wait for CI.

---

## Self-review

- **Spec coverage:** `TouchKeys` sources (T1); `GamepadMap` and `ControlScheme` (T2); `GamepadControls` with the mine, hub and menu tables, tool cycle, thresholds, tap frames, disconnect (T3); Main/Hub wiring and the tool line (T4); `KeyHint`, the HUD texts and `esc_hint` (T5); the playtest and docs (T6); real hardware stays untested and is said so (T6). Out-of-scope items appear in no task.
- **Decisions the spec left open and this plan fixes:** menu mode is `get_tree().paused` (the spec said Main calls `set_menu`; the HUD already pauses for every overlay and the summary, so no extra call is needed); A is a hold key so a jump can be a short hop; the base actions read `LB/RB then Y` in prompts; `KeyHint` accepts a bool or a scheme string so no existing call site or test changes.
- **Type consistency:** the scheme is the String `"keys" | "touch" | "pad"` everywhere; the source ids are `"touch"` and `"pad"`; widget names (`tool_rope`, `base_plant`, ...) are `TouchControls.WIDGETS` keys in `GamepadMap`, `GamepadControls` and `Main`.
- **Proportion:** six tasks, no function bodies except where a rule had to be decided.
