class_name KeyHint

## What to call a key in on-screen text (milestone 62). A touch player has no
## keyboard: the prompts name the button that does the same thing instead.

const TOUCH_BUTTONS := {
	"E": "Use", "B": "Tools", "P": "Tools", "U": "Tools", "F": "Tools", "1": "Tools",
	"Enter": "Continue", "Esc": "Help",
}

static func label(key: String, touch: bool) -> String:
	return TOUCH_BUTTONS.get(key, key) if touch else key

## "E: extract" -> "Use: extract" on touch. Text that does not start with a
## "key: " (or whose key has no touch button) is returned as it is.
static func prompt(text: String, touch: bool, keep_digits: bool = false) -> String:
	var split := text.find(": ")
	if not touch or split < 1:
		return text
	var key := text.substr(0, split)
	if keep_digits and key.is_valid_int():
		return text # the hub's buy buttons are labelled 1 2 3
	if not TOUCH_BUTTONS.has(key):
		return text
	return "%s: %s" % [label(key, true), text.substr(split + 2)]
