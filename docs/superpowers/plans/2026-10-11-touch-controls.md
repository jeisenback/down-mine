# Touch Controls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the game playable on a phone with on-screen controls that press the same keys the keyboard does.

**Architecture:** A `TouchControls` layer owns a set of named widgets (one pad, many buttons), dispatches multi-touch events to them by finger index, and sends synthetic key events through `TouchKeys`. Because the player, base, HUD and hub already poll or listen to keys, none of them change. `Main` and `Hub` each instance the layer and set its mode.

**Tech Stack:** Godot 4.5 GDScript, procedural drawing in a `Control._draw`, the in-repo test runner and playtest.

**Spec:** `docs/superpowers/specs/2026-10-11-touch-controls-design.md`

## Global Constraints

- Touch sends the same keys the keyboard does; no gameplay change, no new actions.
- Landscape only. Portrait shows a "rotate your phone" line and hides the controls.
- Shown on `DisplayServer.is_touchscreen_available()`, on the first finger touch, or with `?touch` / `--touch`; hidden otherwise.
- Pad dead zone `TouchPad.DEAD_ZONE := 0.3` of the pad radius; tap buttons hold their key `TouchControls.TAP_HOLD_FRAMES := 3` physics frames after release.
- Buttons are at least 56 px square at the 648 px reference height.
- Display: stretch mode `canvas_items`, aspect `expand`, base size 1152 by 648; `input_devices/pointing/emulate_touch_from_mouse=true`.
- Every action is a named method (`touch`, `drag`, `set_mode`, `set_base_nearby`, `release_all`); `_input` only forwards events to them.
- No emojis anywhere (code, text, docs, commits).
- Tests that add `Main` or `Hub` set `Progress.path_override = TEST_SAVE_PATH` first and clear it after, and call `TouchKeys.release_all()` and reset `TouchControls.force` / `TouchControls.seen_touch` when done.

## Review Focus

- Two fingers at once (pad and Dig): both stay held; lifting one leaves the other.
- Esc tapped while the pad is held: every key is released, none stuck.
- A tap shorter than one physics frame still registers (the key is held `TAP_HOLD_FRAMES`).
- A finger that starts on the pad and slides onto Dig does not press Dig.
- A portrait screen and a desktop with a keyboard: no widgets show and no key is sent; a mouse click on a hidden control does nothing.

---

## File Structure

- `scripts/touch_keys.gd` (new): synthetic key state, change-only sending.
- `scripts/touch_pad.gd` (new): the pad's pure direction rule.
- `scripts/touch_controls.gd`, `scenes/TouchControls.tscn` (new): layout, widgets, dispatch, modes, drawing.
- `scripts/main.gd`, `scripts/hub.gd` (modify): instance the layer and set its mode.
- `project.godot` (modify): stretch and touch emulation.
- `README.md`, `ROADMAP.md` (modify).
- Tests: `tests/test_touch.gd` (new), `tests/playtest.gd` (modify).

---

### Task 1: `TouchKeys` and `TouchPad`

**Files:**
- Create: `scripts/touch_keys.gd`, `scripts/touch_pad.gd`
- Test: `tests/test_touch.gd` (create)

**Interfaces:**
- Produces `TouchKeys` (`class_name TouchKeys extends RefCounted`, all static):
  - `static func set_key(code: int, down: bool) -> void`: sends an `InputEventKey` (`physical_keycode` and `keycode` both `code`, `pressed = down`) through `Input.parse_input_event` only when the stored state for `code` changes.
  - `static func is_down(code: int) -> bool`
  - `static var sent_count: int` (events sent so far, for tests)
  - `static func release_all() -> void`: sends a release for every key held.
- Produces `TouchPad` (`class_name TouchPad extends RefCounted`):
  - `const DEAD_ZONE := 0.3`
  - `static func keys_for(offset: Vector2, radius: float) -> Array`: offset is the finger's position minus the pad's centre. Returns `KEY_D` when `offset.x > DEAD_ZONE * radius`, `KEY_A` when `< -DEAD_ZONE * radius`, `KEY_W` when `offset.y < -DEAD_ZONE * radius`, `KEY_S` when `> DEAD_ZONE * radius`; diagonals return two keys; inside the dead zone returns `[]`.

- [ ] **Step 1: Write the failing tests** in `tests/test_touch.gd` (extends `TestCase`): `test_pad_directions` (right, left, up, down each return exactly their one key at 0.8 of the radius), `test_pad_diagonals_return_two_keys` (down-right returns `[KEY_D, KEY_S]` in any order), `test_pad_dead_zone_returns_nothing` (offset 0.2 of the radius in each axis), `test_set_key_only_changes_state` (`set_key(KEY_SPACE, true)` twice raises `sent_count` by one; `is_down` is true; `release_all` raises it by one more and `is_down` is false).
- [ ] **Step 2: Run** `timeout 250 /opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd`. Expected: `test_touch.gd does not compile` (classes missing).
- [ ] **Step 3: Implement** both classes. `TouchKeys` keeps a static `Dictionary` of held codes; `set_key` returns early when the state is unchanged.
- [ ] **Step 4: Run** the suite. Expected: all PASS.
- [ ] **Step 5: Commit** `Touch: key state and the pad's direction rule`.

---

### Task 2: `TouchControls` core: widgets, multi-touch, key output

**Files:**
- Create: `scripts/touch_controls.gd`, `scenes/TouchControls.tscn` (root `CanvasLayer` named `TouchControls` with the script, `layer = 10`, `process_mode = Node.PROCESS_MODE_ALWAYS`)
- Test: `tests/test_touch.gd`

**Interfaces:**
- Consumes: `TouchKeys.set_key`, `TouchKeys.release_all`, `TouchPad.keys_for`.
- Produces `TouchControls` (`class_name TouchControls extends CanvasLayer`):
  - `const TAP_HOLD_FRAMES := 3`, `static var force: bool = false`, `static var seen_touch: bool = false`
  - `const WIDGETS` describing each named widget: `{keys: Array, hold: bool, modes: Array}` for `dig` (Space, hold, mine), `flare` (Shift, hold, mine), `use` (E, tap, mine and hub), `esc` (Escape, tap, always), `continue` (Enter, tap, paused), `buy1`, `buy2`, `buy3` (`KEY_1`, `KEY_2`, `KEY_3`, tap, hub), `tool_rope` R, `tool_ladder` T, `tool_anchor` G, `tool_lamp` L, `tool_beam` `KEY_1`, `tool_grapple` Q (tap, mine, only while the Tools row is open), `base_plant` P (tap), `base_repair` F (hold), `base_fortify` B (tap), `base_grow` U (tap) (mine, only while the base is nearby), `tools` (no key; toggles the row), and `pad` (the four direction keys by `TouchPad.keys_for`).
  - `static func layout_for(size: Vector2) -> Dictionary`: widget name to `Rect2` in screen pixels for a viewport of `size`; the pad is a square at the bottom left, `dig` large at the bottom right with `flare`, `use` and `tools` around it, the tool row above `tools`, the base cluster to the left of the right-hand buttons, `esc` top right below the HUD hint, `continue` centred low. Every rect is at least `56 * size.y / 648` square, inside `size`, and no two rects visible together overlap.
  - `func touch(index: int, position: Vector2, pressed: bool) -> void`: on press, assigns the finger to the topmost visible widget whose rect contains `position` and presses it; on release, frees that finger's widget and releases it. A second finger on a widget already held is ignored.
  - `func drag(index: int, position: Vector2) -> void`: for the pad only, updates the held direction keys from `TouchPad.keys_for(position - centre, radius)`; for any other widget does nothing (a finger sliding off a button keeps holding it until lifted; a finger that started on the pad never presses another widget).
  - `func release_all() -> void`: frees every finger and calls `TouchKeys.release_all()`.
  - `_input(event)` forwards `InputEventScreenTouch` and `InputEventScreenDrag` to `touch` / `drag` and sets `seen_touch = true` on a touch.
  - Tap widgets keep their key down for `TAP_HOLD_FRAMES` physics frames after the finger lifts (counted in `_physics_process`).

- [ ] **Step 1: Write the failing tests** (instantiate `TouchControls.tscn`, `add()` it, set `TouchControls.force = true`; `mode` defaults to `"mine"`, and every widget is hit-testable in these tests regardless of visibility rules, which arrive in Task 3): `test_dig_touch_holds_space_until_lifted` (`touch` inside `dig`'s rect from `layout_for(Vector2(1152, 648))`, `TouchKeys.is_down(KEY_SPACE)` true; lift, advance `TAP_HOLD_FRAMES` is not applied to hold widgets, so false at once); `test_two_fingers_hold_two_widgets` (pad right with finger 0, dig with finger 1; lift finger 1; `KEY_D` still down, `KEY_SPACE` released); `test_tap_widget_holds_for_hold_frames` (`use` pressed and lifted in one call: `KEY_E` is down, still down after `TAP_HOLD_FRAMES - 1` physics frames, up after `TAP_HOLD_FRAMES`); `test_pad_drag_changes_direction` (touch right of centre then drag below it: `KEY_D` up, `KEY_S` down); `test_slide_from_pad_onto_dig_does_not_press_dig`; `test_second_finger_on_a_held_button_is_ignored`; `test_release_all_lets_go_of_everything`; `test_layout_rects_are_big_inside_and_do_not_overlap` (for sizes `Vector2(1152, 648)` and `Vector2(2400, 1080)`).
- [ ] **Step 2: Run** the suite. Expected: the new tests FAIL (class missing).
- [ ] **Step 3: Implement** `TouchControls`. Widgets are small objects (a `Dictionary` per widget is enough) holding name, keys, hold flag, finger index and a visible flag; `touch` hit-tests visible widgets in a fixed order (buttons before the pad). Drawing is Task 3.
- [ ] **Step 4: Run** the suite. Expected: PASS.
- [ ] **Step 5: Commit** `Touch: widgets, multi-touch dispatch and key output`.

---

### Task 3: Modes, pause rule, base cluster, detection, drawing (with a preview checkpoint)

**Files:**
- Modify: `scripts/touch_controls.gd`
- Test: `tests/test_touch.gd`

**Interfaces:**
- Consumes: Task 2's `WIDGETS`, `layout_for`, `touch`, `release_all`.
- Produces on `TouchControls`:
  - `var mode: String` (`"mine"` or `"hub"`), `func set_mode(new_mode: String) -> void` (calls `release_all()`; closes the Tools row)
  - `func set_base_nearby(near: bool) -> void` (releases a held `base_repair` when it hides)
  - `func set_tools_available(names: Array) -> void` (which of `TOOL_ROW` the menu lists; default all)
  - `var tools_open: bool`; the menu lists tool items (available ones) in a first column and, only when `base_nearby`, base items in a second column; menu items are packed upward from the Tools button in order.
  - `func visible_widgets() -> Array`: the names currently shown, per the rules below
  - `static func wanted() -> bool`: `force or seen_touch or DisplayServer.is_touchscreen_available() or LaunchOptions.has("touch")`
  - The layer's `visible` is `wanted()` and the screen is landscape; a `Label` named `RotateHint` ("Rotate your phone") shows instead when `wanted()` and the viewport is taller than wide.
- Visibility rules: while `get_tree().paused`, only `continue` and `esc`; otherwise by mode (mine: `pad dig flare use tools esc`, plus, only while the Tools menu is open, the available tool widgets and, when the base is nearby, the four base widgets; hub: `pad use buy1 buy2 buy3 esc`). Pausing, a mode change and the app losing focus (`NOTIFICATION_APPLICATION_FOCUS_OUT`) call `release_all()`. `tools` toggles the menu open; tapping any menu item presses its key and closes the menu (a held Repair keeps its key until the finger lifts). The layer redraws widgets as flat semi-transparent pixel shapes with a short label, brighter while held.

- [ ] **Step 1: Write the failing tests:** `test_mine_mode_shows_its_widgets_and_hub_mode_its_own` (`visible_widgets()` for each mode); `test_tools_menu_opens_and_closes` (tap `tools`: the available tool widgets listed; tap `tool_rope`: `KEY_R` pressed, menu closed); `test_tools_menu_lists_only_available_tools` (`set_tools_available(["tool_rope", "tool_grapple", "tool_beam"])` hides ladder, lamp and anchor); `test_base_items_are_in_the_menu_only_near_the_base` (hidden while the menu is open away from the base; shown after `set_base_nearby(true)`; a held `base_repair` is released when the base is left); `test_paused_shows_only_continue_and_esc` (set `get_tree().paused = true`, advance a frame, reset it after); `test_pausing_releases_held_keys` (pad held, pause, `KEY_D` up); `test_esc_tap_with_the_pad_held_leaves_no_key_stuck` (pad right held with finger 0, tap `esc` with finger 1, then set the tree paused as the overlay would and advance a frame: `TouchKeys.is_down(KEY_D)` is false; unpause after); `test_wanted_for_each_source` (`force`; `seen_touch` after `_input` of an `InputEventScreenTouch`; false by default in the test runner); `test_portrait_hides_controls_and_shows_the_hint` (the pure `static func is_portrait(size: Vector2) -> bool`; and with `var layout_size: Vector2` assigned a portrait size, `visible_widgets()` is empty and the `RotateHint` is visible; `layout_size` is refreshed from the viewport each frame in play); `test_hidden_controls_ignore_touches` (`force` false and no touchscreen: `touch` on `dig` presses nothing).
- [ ] **Step 2: Run** the suite. Expected: the new tests FAIL.
- [ ] **Step 3: Implement** the rules above, drawing in a child `Control` named `Canvas` (`mouse_filter = IGNORE`). Pixel style: filled rects with a 1 px darker outline, no textures.
- [ ] **Step 4: Run** the suite. Expected: PASS.
- [ ] **Step 5: Preview checkpoint.** Render the mine, hub and paused layouts at 1152 by 648 and at 2400 by 1080 over a mine screenshot (a scratch script in the scratchpad, not committed), send the images to the user and wait for approval of the look before Task 4. Adjust sizes and colours on feedback.
- [ ] **Step 6: Commit** `Touch: modes, the pause rule, the base cluster, detection and drawing`.

---

### Task 4: Wire it in, display settings, end to end

**Files:**
- Modify: `scripts/main.gd`, `scripts/hub.gd`, `project.godot`
- Test: `tests/test_touch.gd`

**Interfaces:**
- Consumes: `TouchControls` and its scene from Tasks 2 and 3.
- Produces: `Main.touch_controls: TouchControls` and `Hub.touch_controls: TouchControls`, each created in `_ready` from `preload("res://scenes/TouchControls.tscn")`, added as a child, with `set_mode("mine")` / `set_mode("hub")`. `Main` calls `touch_controls.set_base_nearby(_near_base())` in the same per-frame function that calls `hud.update_prompts`.
- `project.godot`: `[display]` `window/size/viewport_width=1152`, `window/size/viewport_height=648`, `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`; `[input_devices]` `pointing/emulate_touch_from_mouse=true`.

- [ ] **Step 1: Write the failing tests:** `test_project_has_the_phone_display_settings` (`ProjectSettings.get_setting` for the five values); `test_main_and_hub_each_have_touch_controls_in_their_mode` (instance each, check `touch_controls.mode`); `test_touching_dig_digs_a_tile_in_the_mine` (force on, `Main` over the test save, place the player on solid ground, `touch` on `dig` and on the pad's down, `physics_frames(40)`, assert a tile below the start is dug; release after); `test_the_pad_down_and_side_digs_a_stair`; `test_use_at_the_hub_entrance_changes_scene` (replace `hub.change_scene` with a recorder, put the player at `Hub.ENTRANCE_X`, tap `use`, advance frames: the path is `res://scenes/Main.tscn`); `test_continue_on_the_summary_leaves_for_the_hub` (end a run, `tree.paused` true, tap `continue`, advance frames: the recorded path is `res://scenes/Hub.tscn`); `test_base_items_appear_in_the_menu_only_near_the_base` (`Main`: far from the base the open menu has no base widgets, standing at the base it does) and `test_the_menu_lists_only_unlocked_tools` (a fresh save: no ladder, lamp or anchor).
- [ ] **Step 2: Run** the suite. Expected: the new tests FAIL.
- [ ] **Step 3: Implement** the wiring and the settings.
- [ ] **Step 4: Run** the unit suite and the playtest (`xvfb-run -a /opt/godot/godot --fixed-fps 60 -s tests/playtest.gd`). Expected: all green; if a screenshot comparison or position assumption in an existing scenario changes under the new stretch settings, fix the scenario, not the setting.
- [ ] **Step 5: Commit** `Touch: wire the controls into the mine and the hub; phone display settings`.

---

### Task 5: Playtest scenario and docs

**Files:**
- Modify: `tests/playtest.gd`, `README.md`, `ROADMAP.md`

- [ ] **Step 1: Add scenario `touch_controls_play`** to the playtest list: set `TouchControls.force = true`, start the game, then using only `touch` / `drag` calls on the layer: hold the pad down and Dig to dig a few tiles (assert depth increased), open Tools and tap Rope (assert a rope node appears), walk to the base and tap Plant (assert the base moved), tap Esc (assert the overlay shows and the tree paused), tap Continue/Esc to close; screenshots of the mine, the open tools row and the paused layouts. A second scenario step starts a `Hub` and taps `use` at the lamp shop with `buy1` (assert ore spent). Reset `TouchControls.force` and `TouchKeys.release_all()` at the end.
- [ ] **Step 2: Run** the playtest. Expected: all scenarios ok, the new one included.
- [ ] **Step 3: Docs.** README: a "Touch controls" paragraph (what shows when, the pad, the buttons, `?touch`, landscape only, the stretch change); ROADMAP: mark the Mobile item done with the milestone entry (M58), noting that real-device testing is the open follow-up.
- [ ] **Step 4: Run** the full unit suite and the playtest once more; both green. **Commit** `Touch: playtest scenario and docs`.

---

## Self-review notes

- Spec coverage: layout and buttons (Tasks 2, 3), hub and paused modes (Task 3), detection and `?touch` (Task 3), stretch and mouse emulation (Task 4), edge cases (Tasks 2 and 3 tests), end to end and playtest (Tasks 4 and 5), docs (Task 5).
- Fingers: one `TouchControls` dispatcher, not per-widget `Control` input, because Godot's `Control` input only follows one emulated mouse pointer; multi-touch needs the raw `InputEventScreenTouch` index.
- Risk to watch: the stretch change alters how the playtest's screenshots look and any pixel positions a scenario assumes; Task 4 step 4 checks this and fixes scenarios, not the setting.
- Deferred by design: analog stick, remapping, haptics, gestures, a settings toggle, auto-hide with a keyboard, real-device testing.
