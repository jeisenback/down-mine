extends Node
class_name GamepadControls

## A gamepad as another source of the keys the game already reads (controller support). Like the
## touch controls it presses keys through TouchKeys, so the player, base, HUD and hub need no
## changes. Every action is a named method (button, axis, release_all); _input only forwards the
## engine's joypad events to them. Where the buttons go depends on the mode: in the mine, in the
## hub, and in a menu (any time the game is paused: the HUD pauses for every overlay).

const SOURCE := "pad"
## Tap buttons keep their key down this many physics frames, as the touch buttons do.
const TAP_HOLD_FRAMES := TouchControls.TAP_HOLD_FRAMES
## The right trigger is tracked like a button, under an id no real button uses.
const TRIGGER_ID := 1000
## A stick pushed less than this is not "a pad being used" (it drifts at rest).
const NOTICE_ZONE := 0.5

const DIRECTION_KEYS := [KEY_A, KEY_D, KEY_W, KEY_S]
## Buttons that are directions: the d-pad, and A as the jump (W), held so a jump can be a hop.
const DIRECTION_BUTTONS := {
	JOY_BUTTON_DPAD_UP: KEY_W, JOY_BUTTON_DPAD_DOWN: KEY_S,
	JOY_BUTTON_DPAD_LEFT: KEY_A, JOY_BUTTON_DPAD_RIGHT: KEY_D, JOY_BUTTON_A: KEY_W,
}
const MINE_ACTIONS := {
	JOY_BUTTON_X: {"keys": [KEY_SPACE], "hold": true},
	JOY_BUTTON_B: {"keys": [KEY_E], "hold": false},
	JOY_BUTTON_START: {"keys": [KEY_ESCAPE], "hold": false},
}
const HUB_ACTIONS := {
	JOY_BUTTON_X: {"keys": [KEY_1], "hold": false},
	JOY_BUTTON_Y: {"keys": [KEY_2], "hold": false},
	JOY_BUTTON_RIGHT_SHOULDER: {"keys": [KEY_3], "hold": false},
	JOY_BUTTON_B: {"keys": [KEY_E], "hold": false},
	JOY_BUTTON_START: {"keys": [KEY_ESCAPE], "hold": false},
}
const MENU_ACTIONS := {
	JOY_BUTTON_A: {"keys": [KEY_ENTER], "hold": false},
	JOY_BUTTON_B: {"keys": [KEY_ESCAPE], "hold": false},
	JOY_BUTTON_X: {"keys": [KEY_X], "hold": false},
	JOY_BUTTON_START: {"keys": [KEY_ESCAPE], "hold": false},
}

## "mine" or "hub".
var mode: String = "mine"

var _tools_available: Array = []
var _can_plant: bool = false
var _base_nearby: bool = false
var _selected: String = ""
var _stick: Vector2 = Vector2.ZERO
var _trigger_down: bool = false
var _directions: Dictionary = {} # button index -> the direction key it holds
var _held: Dictionary = {} # input id -> the keys a hold action keeps down
var _tap_frames: Dictionary = {} # key -> physics frames left holding it

func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _ready() -> void:
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func _exit_tree() -> void:
	release_all()

func set_mode(new_mode: String) -> void:
	mode = new_mode
	release_all()

func set_tools_available(names: Array) -> void:
	_tools_available = names.duplicate()

func set_base_nearby(near: bool) -> void:
	_base_nearby = near

func set_can_plant(allowed: bool) -> void:
	_can_plant = allowed

## The tool Y would use: the one the bumpers picked, or the first when it is no longer on offer.
func selected_tool() -> String:
	var list := GamepadMap.cycle_list(_tools_available, _can_plant, _base_nearby)
	if not list.has(_selected):
		_selected = list[0] if not list.is_empty() else ""
	return _selected

## Whether the game is paused (an overlay or the run summary is up): the buttons mean menu things.
func _in_menu() -> bool:
	return is_inside_tree() and get_tree().paused

func button(index: int, pressed: bool) -> void:
	if not pressed:
		_lift(index)
		return
	if _in_menu():
		_press_action(index, MENU_ACTIONS.get(index))
		return
	if DIRECTION_BUTTONS.has(index):
		_directions[index] = DIRECTION_BUTTONS[index]
		_apply_directions()
		return
	if mode == "hub":
		_press_action(index, HUB_ACTIONS.get(index))
		return
	match index:
		JOY_BUTTON_LEFT_SHOULDER:
			_cycle(-1)
		JOY_BUTTON_RIGHT_SHOULDER:
			_cycle(1)
		JOY_BUTTON_Y:
			var tool := selected_tool()
			if tool != "":
				_press_action(index, {"keys": GamepadMap.tool_keys(tool), "hold": GamepadMap.tool_holds(tool)})
		_:
			_press_action(index, MINE_ACTIONS.get(index))

func axis(axis_index: int, value: float) -> void:
	match axis_index:
		JOY_AXIS_LEFT_X:
			_stick.x = value
			_apply_directions()
		JOY_AXIS_LEFT_Y:
			_stick.y = value
			_apply_directions()
		JOY_AXIS_TRIGGER_RIGHT:
			var pulled := value > GamepadMap.TRIGGER_THRESHOLD
			if pulled == _trigger_down:
				return
			_trigger_down = pulled
			if not pulled:
				_lift(TRIGGER_ID)
			elif mode == "mine" and not _in_menu():
				_press_action(TRIGGER_ID, {"keys": [KEY_SHIFT], "hold": true}) # flare

## Lets go of every key the pad holds.
func release_all() -> void:
	_stick = Vector2.ZERO
	_trigger_down = false
	_directions.clear()
	_held.clear()
	_tap_frames.clear()
	TouchKeys.release_all(SOURCE)

func _cycle(step: int) -> void:
	_selected = GamepadMap.cycle(GamepadMap.cycle_list(_tools_available, _can_plant, _base_nearby), selected_tool(), step)

## Presses an action's keys: held ones stay down until the input lifts, taps for a few frames.
func _press_action(id: int, action) -> void:
	if action == null:
		return
	for key in action.keys:
		TouchKeys.set_key(key, true, SOURCE)
		if not action.hold:
			_tap_frames[key] = TAP_HOLD_FRAMES
	if action.hold:
		_held[id] = action.keys

## An input lifted: let go of whatever it pressed, whatever the mode is now.
func _lift(id: int) -> void:
	if _directions.erase(id):
		_apply_directions()
	if _held.has(id):
		for key in _held[id]:
			TouchKeys.set_key(key, false, SOURCE)
		_held.erase(id)

## The direction keys wanted now: the stick, the d-pad and A together; none in a menu.
func _apply_directions() -> void:
	var wanted: Array = [] if _in_menu() else GamepadMap.stick_keys(_stick) + _directions.values()
	for key in DIRECTION_KEYS:
		TouchKeys.set_key(key, wanted.has(key), SOURCE)

func _physics_process(_delta: float) -> void:
	_apply_directions() # an overlay opening or closing changes what the stick means
	for key in _tap_frames.keys():
		_tap_frames[key] -= 1
		if _tap_frames[key] <= 0:
			_tap_frames.erase(key)
			TouchKeys.set_key(key, false, SOURCE)

func _on_joy_connection_changed(_device: int, connected: bool) -> void:
	if not connected:
		release_all()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		ControlScheme.note_joypad()
		button(event.button_index, event.pressed)
	elif event is InputEventJoypadMotion:
		if absf(event.axis_value) > NOTICE_ZONE:
			ControlScheme.note_joypad()
		axis(event.axis, event.axis_value)
	elif event is InputEventKey:
		ControlScheme.note_key(event)
