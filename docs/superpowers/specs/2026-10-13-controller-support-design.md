# Controller support

## Goal

Let a player finish a run, and shop in the hub, on a gamepad, with no change to how the player, the mine or the events work.

Success looks like: plug in (or pair) a standard gamepad, press any button, and the title screen, the hub, a full run and the end-of-run summary can all be played without touching the keyboard. The on-screen help and prompts then name the pad's buttons, not keys.

## What exists (read from the code)

- The game polls physical keys (`Input.is_physical_key_pressed`) and listens to key events. There are no `InputMap` actions.
- The touch controls already work through a seam: `TouchKeys.set_key(code, down)` sends a synthetic `InputEventKey`, so the player, base, HUD and hub need no changes (milestone 58). `TouchControls` states the rule: "every action is a named method; `_input` only forwards the engine's events to them".
- `TouchPad.keys_for(offset, radius)` already turns a thumb offset into A / D / W / S, with a dead zone and a stair zone (down and a side together digs stairs).
- `TouchControls` is told by Main what is available (`set_tools_available`, `set_base_nearby`, `set_can_plant`) and by mode (`mine`, `hub`).
- Help text and prompts name keys or touch buttons: `HUD.CONTROLS_TEXT`, `TOUCH_CONTROLS_TEXT`, `KeyHint.label(key, touch)`, `KeyHint.prompt(text, touch)`.
- About 20 actions: move A/D, jump W, dig Space (hold; with W digs up), dig down S, flare Shift (hold), use E, rope R, grapple Q, ladder T, anchor G, lamp L, beam 1, plant P, repair F (hold), fortify B, grow U; hub buys 1 / 2 / 3; menus Enter, Esc, X (abandon).

## Design

A gamepad is another source of the same synthetic keys. Nothing in `player.gd`, `mine.gd`, the events or the base changes.

### Units

- **`GamepadMap`** (new, `scripts/gamepad_map.gd`, RefCounted, pure data and functions). The layout below as constants, and `stick_keys(offset: Vector2) -> Array` (calls `TouchPad.keys_for(offset, 1.0)`: the same dead zone and stair zone as the touch pad).
- **`GamepadControls`** (new, `scripts/gamepad_controls.gd`, Node). One per scene that has `TouchControls` (Main and Hub). `_input` only forwards joypad events to named methods: `button(index: int, pressed: bool)`, `axis(axis: int, value: float)`, `release_all()`. It owns the tool cycle. It is told what is available with the same calls Main already makes on `TouchControls` (`set_mode`, `set_tools_available`, `set_base_nearby`, `set_can_plant`) plus `set_menu(open: bool)`.
- **`TouchKeys`** (changed). A key is held by sources: `set_key(code, down, source := "touch")`. A key is down while any source holds it, so a thumb and a pad can never release each other's keys. Existing callers and tests keep their signature (the default source). `release_all(source := "")` releases one source's keys or all of them.
- **`ControlScheme`** (new, small): `"keys"`, `"touch"` or `"pad"`, static. It becomes `"pad"` on the first joypad event and returns to `"keys"` on a real key press; `"touch"` keeps its present rule (`TouchControls.wanted()`). `HUD` asks it instead of `_touch()`.
- **`KeyHint`** (changed). `label` and `prompt` take the scheme (a String) instead of a bool, and gain a table of pad button names next to `TOUCH_BUTTONS`. About 6 call sites in `hud.gd` change.
- **`HUD`** (changed). `GAMEPAD_CONTROLS_TEXT` and `GAMEPAD_HUB_CONTROLS_TEXT` next to the touch ones, and one status line "Tool: Rope" (only on the pad scheme) so the player can see the selected tool.

### Default layout (Xbox names; other pads follow the engine's standard mapping)

In the mine:

| Input | Does |
|---|---|
| Left stick, d-pad | Move (A / D), up = jump (W), down = dig down (S); down and a side = stairs |
| A | Jump (W) |
| X (hold) | Dig forward (Space); with the stick up, dig up |
| B | Use (E): camp, lift, outpost, vault, relic, extract |
| Y | Use the selected tool; for repair, hold |
| LB / RB | Previous / next tool |
| RT (hold) | Flare (Shift) |
| Start | Controls overlay (Esc) |

The tool cycle is one list: `tools_available` (Rope, Grapple, Beam always; Ladder, Lamp, Anchor once the hub unlocks them) followed by the base actions that apply right now (Plant when `can_plant`; Repair, Fortify, Grow when `base_nearby`). It keeps its position when the list changes, and wraps. The selected tool is named in the HUD line.

In the hub: stick / d-pad walk, A jumps, B uses (join or leave the crew, the notice board, go down the mine), X / Y / RB buy at the building you stand beside (1 / 2 / 3), Start opens the controls.

In an overlay (title, controls, summary, "abandon this run?"): A = Enter (start / continue / confirm), B = Esc (close / cancel), X = abandon (only where the overlay offers it). Main tells the mapper when an overlay is open (`set_menu`), because the same buttons then mean something else.

### Rules

- Triggers and sticks are thresholded: a trigger counts as pressed above 0.5; the stick uses the touch pad's zones.
- Tap buttons hold their key for `TAP_HOLD_FRAMES` physics frames (the game polls at 60 Hz), as the touch buttons do.
- Disconnecting a pad (`Input.joy_connection_changed`) and leaving the scene release every key the pad holds.
- `player.assist_dig` (push into rock to dig) stays tied to touch. A pad has a dig button.
- No remapping screen, rumble, per-pad glyphs (PlayStation shapes) or analog walking speed.

## Testing

- `GamepadMap` and the tool cycle are pure: assert them directly (the cycle wraps, keeps its place when the list changes, includes the base actions only when they apply).
- `GamepadControls` tests drive the named methods and read `TouchKeys.is_down`: stick directions and stairs, the dead zone, each button's key, hold vs tap, trigger threshold, menu mode, hub mode, disconnect release.
- A `TouchKeys` test with two sources: both hold a key, one releases, the key stays down; both release, it is up. The existing touch tests pass unchanged.
- `ControlScheme`: a joypad event switches to the pad, a key press switches back; `KeyHint` labels and the HUD overlay text for the pad scheme (title, controls, abandon).
- One playtest scenario drives a short run through the named methods (walk, dig, use, a tool) and takes screenshots, so the pad's help text and tool line can be accepted from pictures.
- Not testable here: real hardware. The stick's feel, the tool cycle and the layout need a hand play with a controller. The PR says so.

## Out of scope

- Remapping, rumble, PlayStation / Switch glyphs, analog speed, aim assist.
- Changing the keyboard or touch controls beyond the shared `TouchKeys` change.
- A gamepad-driven menu cursor (the overlays and the hub buys are all reachable by the buttons above).

## Risks and open questions

- **Tool cycle versus a held modifier.** This spec picks the cycle (LB / RB, then Y): it needs no second layer to learn and reuses the touch menu's list. If it feels slow on a hand play (rope under pressure is the worst case), the fallback is to give Rope its own button (for example LB) and cycle only the rest. A one-constant change.
- **Layout is a proposal.** B for Use (not Cancel) and X for dig are choices for play, not facts.
- **Web and phones.** Pads work in Chrome and Firefox through the engine's Gamepad API; Safari and phone browsers are patchier. No export setting changes.
- **Two schemes at once.** A phone with touch controls and a paired pad shows both; the HUD text follows whichever was used last.
