extends RefCounted
class_name TouchKeys

## Synthetic key presses for the on-screen controls (milestone 58). The game
## polls and listens to physical keys, so touch presses the same keys. An
## event is sent only when a key's state changes.

static var _down: Dictionary = {}
## Events sent so far, for tests.
static var sent_count: int = 0

static func set_key(code: int, down: bool) -> void:
	if _down.get(code, false) == down:
		return
	_down[code] = down
	sent_count += 1
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = down
	Input.parse_input_event(event)

static func is_down(code: int) -> bool:
	return _down.get(code, false)

## Lets go of every key held, so none can stay stuck down.
static func release_all() -> void:
	for code in _down.keys():
		set_key(code, false)
