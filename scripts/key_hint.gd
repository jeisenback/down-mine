class_name KeyHint

## What to call a key in on-screen text (milestone 62). A touch player has no keyboard and a pad
## player has none either: the prompts name the button that does the same thing instead. The
## scheme is "keys", "touch" or "pad" (a bool still works: true is touch, false is keys).

const TOUCH_BUTTONS := {
	"E": "Use", "B": "Tools", "P": "Tools", "U": "Tools", "F": "Tools", "1": "Tools",
	"Enter": "Continue", "Esc": "Help",
}
## The tools and base actions are picked with the bumpers, then used with Y.
const PAD_BUTTONS := {
	"E": "B", "B": "LB/RB then Y", "P": "LB/RB then Y", "U": "LB/RB then Y", "F": "LB/RB then Y",
	"1": "LB/RB then Y", "Enter": "A", "Esc": "Start",
}
## In the hub the buy keys are 1, 2, 3: the pad buys with X, Y and RB.
const PAD_HUB_DIGITS := {"1": "X", "2": "Y", "3": "RB"}

static func _scheme_name(scheme) -> String:
	if scheme is bool:
		return "touch" if scheme else "keys"
	return scheme

static func label(key: String, scheme) -> String:
	match _scheme_name(scheme):
		"touch":
			return TOUCH_BUTTONS.get(key, key)
		"pad":
			return PAD_BUTTONS.get(key, key)
	return key

## "E: extract" -> "Use: extract" on touch, "B: extract" on a pad. Text that does not start with a
## "key: " (or whose key has no button) is returned as it is.
static func prompt(text: String, scheme, keep_digits: bool = false) -> String:
	var kind := _scheme_name(scheme)
	var split := text.find(": ")
	if kind == "keys" or split < 1:
		return text
	var key := text.substr(0, split)
	var rest := text.substr(split + 2)
	if kind == "pad" and keep_digits and PAD_HUB_DIGITS.has(key):
		return "%s: %s" % [PAD_HUB_DIGITS[key], rest]
	if kind == "touch" and keep_digits and key.is_valid_int():
		return text # the hub's buy buttons are labelled 1 2 3
	if label(key, kind) == key:
		return text
	return "%s: %s" % [label(key, kind), rest]
