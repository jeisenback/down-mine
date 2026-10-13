extends RefCounted
class_name ControlScheme

## Which controls the player is using, so help and prompts name the right things: `"keys"`
## (a keyboard), `"touch"` (the on-screen buttons) or `"pad"` (a gamepad). The pad wins once a
## joypad event arrives and loses to the first real key press.

## Whether the last input was a joypad's. Tests reset it (TestHooks).
static var pad_last: bool = false

static func current() -> String:
	if pad_last:
		return "pad"
	return "touch" if TouchControls.wanted() else "keys"

static func note_joypad() -> void:
	pad_last = true

## A pressed key that no synthetic source is holding is the player's own. The pad's keys are
## injected as key events too (TouchKeys sets its state before sending), so they are skipped.
static func note_key(event: InputEventKey) -> void:
	if event.pressed and not TouchKeys.is_down(event.physical_keycode):
		pad_last = false
