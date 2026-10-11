extends CanvasLayer
class_name TouchControls

## On-screen controls for phones (milestone 58). Widgets (a pad and buttons)
## are hit-tested here, one finger each, and press the same keys the keyboard
## does through TouchKeys, so the player, base, HUD and hub need no changes.
## Every action is a named method (touch, drag, release_all); _input only
## forwards the engine's touch events to them.

## Tap widgets keep their key down this many physics frames after the finger
## lifts: the game polls keys at 60 Hz and a shorter press would be missed.
const TAP_HOLD_FRAMES := 3
## Tests and the playtest set this to show the controls without a touch screen.
static var force: bool = false
## Set by the first finger touch, and kept across scene changes.
static var seen_touch: bool = false

## Hit-test order: buttons first, the pad last. keys are pressed while held
## (hold) or for TAP_HOLD_FRAMES after a tap; modes say where it shows.
const WIDGETS := {
	"dig": {"keys": [KEY_SPACE], "hold": true, "modes": ["mine"]},
	"flare": {"keys": [KEY_SHIFT], "hold": true, "modes": ["mine"]},
	"use": {"keys": [KEY_E], "hold": false, "modes": ["mine", "hub"]},
	"tools": {"keys": [], "hold": false, "modes": ["mine"]},
	"tool_rope": {"keys": [KEY_R], "hold": false, "modes": ["mine"]},
	"tool_ladder": {"keys": [KEY_T], "hold": false, "modes": ["mine"]},
	"tool_anchor": {"keys": [KEY_G], "hold": false, "modes": ["mine"]},
	"tool_lamp": {"keys": [KEY_L], "hold": false, "modes": ["mine"]},
	"tool_beam": {"keys": [KEY_1], "hold": false, "modes": ["mine"]},
	"tool_grapple": {"keys": [KEY_Q], "hold": false, "modes": ["mine"]},
	"base_plant": {"keys": [KEY_P], "hold": false, "modes": ["mine"]},
	"base_repair": {"keys": [KEY_F], "hold": true, "modes": ["mine"]},
	"base_fortify": {"keys": [KEY_B], "hold": false, "modes": ["mine"]},
	"base_grow": {"keys": [KEY_U], "hold": false, "modes": ["mine"]},
	"buy1": {"keys": [KEY_1], "hold": false, "modes": ["hub"]},
	"buy2": {"keys": [KEY_2], "hold": false, "modes": ["hub"]},
	"buy3": {"keys": [KEY_3], "hold": false, "modes": ["hub"]},
	"esc": {"keys": [KEY_ESCAPE], "hold": false, "modes": ["mine", "hub"]},
	"continue": {"keys": [KEY_ENTER], "hold": false, "modes": []},
	"pad": {"keys": [], "hold": true, "modes": ["mine", "hub"]},
}
const TOOL_ROW := ["tool_rope", "tool_ladder", "tool_anchor", "tool_lamp", "tool_beam", "tool_grapple"]
const PAD_KEYS := [KEY_A, KEY_D, KEY_W, KEY_S]

var mode: String = "mine"
## The screen size the layout is computed for; refreshed from the viewport in play.
var layout_size: Vector2 = Vector2(1152, 648)

var _fingers: Dictionary = {} # finger index -> widget name
var _held: Dictionary = {} # widget name -> finger index
var _tap_frames: Dictionary = {} # widget name -> physics frames left holding its key

## Every widget's rectangle in screen pixels for a viewport of this size.
## Sizes scale with the height, so a tall phone screen gets proportionally big buttons.
static func layout_for(size: Vector2) -> Dictionary:
	var u := size.y / 648.0
	var m := 24.0 * u
	var r := 80.0 * u
	var out := {}
	out["pad"] = Rect2(m, size.y - m - 2.0 * r, 2.0 * r, 2.0 * r)
	var dig := Rect2(size.x - m - 100.0 * u, size.y - m - 100.0 * u, 100.0 * u, 100.0 * u)
	out["dig"] = dig
	var use := Rect2(dig.position.x - 88.0 * u, size.y - m - 76.0 * u, 76.0 * u, 76.0 * u)
	out["use"] = use
	out["flare"] = Rect2(dig.position.x + 12.0 * u, dig.position.y - 88.0 * u, 76.0 * u, 76.0 * u)
	var tools := Rect2(use.position.x + 6.0 * u, use.position.y - 76.0 * u, 64.0 * u, 64.0 * u)
	out["tools"] = tools
	for i in range(TOOL_ROW.size()):
		out[TOOL_ROW[i]] = Rect2(tools.position.x + 2.0 * u, tools.position.y - (i + 1) * 68.0 * u, 60.0 * u, 60.0 * u)
	var base_names := ["base_plant", "base_repair", "base_fortify", "base_grow"]
	for i in range(4):
		out[base_names[i]] = Rect2(use.position.x - 152.0 * u + (i % 2) * 72.0 * u, size.y - m - 64.0 * u - (i / 2) * 72.0 * u, 64.0 * u, 64.0 * u)
	for i in range(3):
		out["buy%d" % (i + 1)] = Rect2(use.position.x - 224.0 * u + i * 72.0 * u, size.y - m - 64.0 * u, 64.0 * u, 64.0 * u)
	out["esc"] = Rect2(size.x - m - 56.0 * u, 72.0 * u, 56.0 * u, 56.0 * u)
	out["continue"] = Rect2(size.x / 2.0 - 120.0 * u, size.y * 0.62, 240.0 * u, 72.0 * u)
	return out

func _rect(widget: String) -> Rect2:
	return layout_for(layout_size)[widget]

## Whether a widget can be touched right now (the rules arrive with the modes).
func _widget_visible(_widget: String) -> bool:
	return true

func _hit(position: Vector2) -> String:
	for widget in WIDGETS:
		if _widget_visible(widget) and _rect(widget).has_point(position):
			return widget
	return ""

## A finger goes down on, or lifts from, the screen.
func touch(index: int, position: Vector2, pressed: bool) -> void:
	if pressed:
		if _fingers.has(index):
			return
		var widget := _hit(position)
		if widget == "" or _held.has(widget):
			return
		_fingers[index] = widget
		_held[widget] = index
		_tap_frames.erase(widget)
		_press(widget, position)
	else:
		if not _fingers.has(index):
			return
		var lifted: String = _fingers[index]
		_fingers.erase(index)
		_held.erase(lifted)
		_lift(lifted)

## A finger moves. Only the pad follows it; a finger that started elsewhere
## keeps its own widget, and one that started on the pad never presses another.
func drag(index: int, position: Vector2) -> void:
	if _fingers.get(index, "") == "pad":
		_apply_pad(position)

func release_all() -> void:
	_fingers.clear()
	_held.clear()
	_tap_frames.clear()
	TouchKeys.release_all()

func _press(widget: String, position: Vector2) -> void:
	if widget == "pad":
		_apply_pad(position)
		return
	for key in WIDGETS[widget].keys:
		TouchKeys.set_key(key, true)

func _lift(widget: String) -> void:
	if widget == "pad":
		for key in PAD_KEYS:
			TouchKeys.set_key(key, false)
	elif WIDGETS[widget].hold:
		for key in WIDGETS[widget].keys:
			TouchKeys.set_key(key, false)
	else:
		_tap_frames[widget] = TAP_HOLD_FRAMES

func _apply_pad(position: Vector2) -> void:
	var rect := _rect("pad")
	var down := TouchPad.keys_for(position - rect.get_center(), rect.size.x / 2.0)
	for key in PAD_KEYS:
		TouchKeys.set_key(key, down.has(key))

func _physics_process(_delta: float) -> void:
	for widget in _tap_frames.keys():
		_tap_frames[widget] -= 1
		if _tap_frames[widget] <= 0:
			_tap_frames.erase(widget)
			for key in WIDGETS[widget].keys:
				TouchKeys.set_key(key, false)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		seen_touch = true
		touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		drag(event.index, event.position)
