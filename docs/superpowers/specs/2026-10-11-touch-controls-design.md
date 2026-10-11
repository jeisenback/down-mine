# Touch controls: playing on a phone

2026-10-11. Design for the roadmap's "Mobile" item. Agreed in conversation. Sizes are starting values to tune on a real device, not commitments.

## Why

The game is keyboard only. Every control is a physical key polled with `Input.is_physical_key_pressed` in `player.gd` and `main.gd`, or a key event in `hud.gd` and `hub.gd`. Nothing reads touch. The web build already loads on phones, so the one gap is input. The hub milestone (M57) made every hub action a named method so a touch layer could be added without touching its rules.

## Decisions

1. **Touch presses the same keys.** A touch layer sends synthetic key events. The player, base, HUD and hub work unchanged, and the keyboard stays the single source of truth. (Rejected: replacing every poll with named input actions, which touches the player, base, HUD, hub and every key test; and merging touch into each poll, which spreads touch knowledge through the player and Main.)
2. **A four-way pad on the left, action buttons on the right.** It maps one to one onto the keys the game already uses, so the stair dig (down and a side) and dig up (Dig with up) keep working.
3. **Shown automatically on touch devices.** No settings toggle.
4. **Landscape only.**
5. **No gameplay change.** No new actions, no changed rules.

## What is on screen

**In the mine:**

- **Pad (left thumb):** one touch area, not four buttons. The direction comes from where the thumb sits relative to the centre, with a dead zone, so one finger can make a diagonal. It presses A and D (move), W (jump) and S (dig down).
- **Dig** (right, large, held): Space. With the pad up it digs up; with the pad down it digs down.
- **Flare** (held): Shift.
- **Use** (tap): E (camp, lift, outpost, vault, relic, or extract at the surface).
- **Tools** (toggle): opens one compact menu above the button and closes when an item is picked. Its tool items are Rope `R`, Grapple `Q` and Beam `1` always, and Ladder `T`, Lamp `L` and Anchor `G` only once the hub has unlocked them. Tapping an item presses its key. Holding the pad down while tapping Rope gives the rope-down-over-an-edge combo.
- **Base items in the same menu**, only within reach of the run base: Plant `P`, Repair `F` (held: the menu closes but the key stays down until the finger lifts), Fortify `B`, Grow `U`, in a second column beside the tools.

Four buttons stay on screen (Dig, Flare, Use, Tools), plus the pad and a small Esc. Nothing else is permanent, so the prompt line at the bottom centre is not covered in the mine. (The first layout had a permanent tool column and base cluster; it was too busy.)

Buttons are at least 56 px square at the 648 px reference height, semi-transparent so they do not hide the mine, and drawn in the game's pixel style. Each button follows its own finger, so the pad, Dig and a tool can be held at once.

## Components

- **`TouchControls`** (new, `scripts/touch_controls.gd`, `scenes/TouchControls.tscn`): a `CanvasLayer` above the HUD, running while paused. API: `set_mode(mode: String)` (`"mine"` or `"hub"`), `set_base_nearby(near: bool)`, `set_tools_available(names: Array)` (which of the six tool items the menu lists; default all), `static func wanted() -> bool`, and `static var force: bool` (tests and the playtest set it to show the controls). Owns the layout, what shows in each mode and when paused.
- **`TouchPad`** (new, `scripts/touch_pad.gd`): follows one finger by its touch index. `static func keys_for(offset: Vector2, radius: float) -> Array` returns the keys down (A, D, W, S) with a dead zone, so it is testable without a screen.
- **`TouchButton`** (new, `scripts/touch_button.gd`): follows one finger; `key: int`; holds the key while touched. A tap button keeps its key down for at least `TAP_HOLD_FRAMES` (3) physics frames after the finger lifts, because the game polls at 60 Hz and a shorter press would be missed.
- **`TouchKeys`** (new, `scripts/touch_keys.gd`, static): `set_key(code: int, down: bool)` sends a synthetic key event (`Input.parse_input_event`) only when the state changes; `release_all()` lets go of every key it holds.
- **`Main`** and **`Hub`** (modify): each instances `TouchControls` and sets its mode; `Main` also calls `set_base_nearby(_near_base())` and `set_tools_available(...)` each frame (Ladder, Lamp and Anchor when unlocked or still carried).
- **`project.godot`** (modify): stretch mode `canvas_items`, aspect `expand`, base size 1152 by 648; emulate touch from mouse on. The stretch change is needed because with none the game renders at the phone's native pixels and looks tiny, and buttons and text cannot be sized sensibly. On a desktop the default window is unchanged; resizing it now scales the game instead of revealing more of the mine.
- **`README.md`, `ROADMAP.md`** (modify): the controls section and the Mobile item.

## Detecting touch

The controls show when `DisplayServer.is_touchscreen_available()` is true, or on the first finger touch (for browsers that do not report it), or with `?touch` in the URL or `--touch` on the command line (the existing `LaunchOptions`). A static flag remembers it, so the controls survive the hub to mine scene changes. Once shown they stay shown for the session; there is no auto-hide when a key is pressed.

With "emulate touch from mouse" on, a mouse click acts as a touch on a desktop, so everything can be tested and screenshotted without a phone. Nothing in the game uses the mouse today.

## Edge cases

- A second finger on an already-held button is ignored. Lifting a finger that slid off a button still releases it. A finger that slides from the pad onto another button does not trigger that button.
- The mode changing or the game pausing calls `release_all()`, so tapping Esc with a thumb on the pad cannot leave a key stuck down.
- The app losing focus (a call, a tab switch) calls `release_all()`.
- The run ending pauses the game, so the controls drop to Continue only and every key is released.
- The base items leave the menu when you leave the base, and a held Repair key is released when they go. Picking a tool or base item closes the menu.
- The hub's buy buttons show even away from a building; pressing them there does nothing, as with the keyboard.
- A portrait screen shows a "rotate your phone" line over the game and hides the controls; the game keeps running behind it.
- A desktop with a keyboard sees nothing different unless `?touch` is given.

## Out of scope

An analog stick, remappable or resizable controls, haptics, gestures (tap or swipe to dig), a settings toggle, auto-hide when a keyboard is used, and a real-device test (the first real check is trying the deployed build on a phone).

## Testing

- **Unit:** `TouchPad.keys_for` across the four directions, diagonals and the dead zone; `TouchKeys` sends an event only on a state change; a tap button holds its key for `TAP_HOLD_FRAMES` after release; `release_all` on a mode change and on pause; which buttons show in the mine, the hub and while paused; the Tools menu lists only the tools available and the base items appear in it only near the base; `wanted()` is true for each of a touchscreen available, a first touch, and `?touch`.
- **End to end:** a simulated screen touch on Dig makes `Input.is_physical_key_pressed(KEY_SPACE)` true and digs a tile; the pad's down-and-side digs a stair; Use at the hub's entrance changes scene; Continue on the summary leaves for the hub.
- **Playtest:** a scenario forces touch on (`TouchControls.force`), plays a short dig, tool and base sequence using touches only, and screenshots the mine, hub and paused layouts.
- Existing tests and playtest scenarios keep passing; the stretch setting does not change how they run.

## Open questions for the plan to settle, not the design

- Exact pad radius, dead zone and button spacing at the reference size.
- Where the Esc button and the rotate hint sit so they do not cover the HUD's top-left lines.
- The art style of the buttons (flat pixel shapes drawn in code, like the rest of the game).
