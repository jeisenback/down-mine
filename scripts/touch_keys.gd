extends RefCounted
class_name TouchKeys

## Synthetic key presses for the on-screen controls (milestone 58) and the gamepad. The game
## polls and listens to physical keys, so touch and the pad press the same keys. An event is
## sent only when a key's state changes: a key is down while any source holds it, so a thumb
## and a pad can never let go of each other's keys.

const DEFAULT_SOURCE := "touch"

## key code -> the sources holding it (only keys held by someone are listed).
static var _down: Dictionary = {}
## Events sent so far, for tests.
static var sent_count: int = 0

static func set_key(code: int, down: bool, source: String = DEFAULT_SOURCE) -> void:
	var holders: Array = _down.get(code, [])
	var was_down := not holders.is_empty()
	if down and not holders.has(source):
		holders.append(source)
	elif not down:
		holders.erase(source)
	if holders.is_empty():
		_down.erase(code)
	else:
		_down[code] = holders
	var now_down := not holders.is_empty()
	if now_down == was_down:
		return
	sent_count += 1
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = now_down
	Input.parse_input_event(event)

static func is_down(code: int) -> bool:
	return _down.has(code)

## Lets go of every key held by `source`, or by every source when none is named, so none can
## stay stuck down.
static func release_all(source: String = "") -> void:
	for code in _down.keys():
		for holder in (_down[code] as Array).duplicate():
			if source == "" or holder == source:
				set_key(code, false, holder)
