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
## The screen size the layout is computed for; refreshed from the viewport
## when it is ready and whenever the window is resized.
var layout_size: Vector2 = Vector2(1152, 648)
var tools_open: bool = false
var base_nearby: bool = false
var canvas: Control
var rotate_hint: Label
var _was_paused: bool = false
var _pad_thumb: Vector2 = Vector2.ZERO

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
	out["continue"] = Rect2(size.x / 2.0 - 120.0 * u, size.y - m - 72.0 * u, 240.0 * u, 72.0 * u)
	return out

func _rect(widget: String) -> Rect2:
	return layout_for(layout_size)[widget]

## Whether the controls are wanted at all: a touch screen, a first real touch,
## the ?touch launch option, or a test forcing them on.
static func wanted() -> bool:
	return force or seen_touch or DisplayServer.is_touchscreen_available() or LaunchOptions.has("touch")

static func is_portrait(size: Vector2) -> bool:
	return size.y > size.x

## Which widgets show right now: Continue and Esc while the game is paused,
## otherwise by mode (the Tools row and the base cluster only when open or near).
func visible_widgets() -> Array:
	var out: Array = []
	if is_portrait(layout_size):
		return out
	if is_inside_tree() and get_tree().paused:
		return ["continue", "esc"]
	for widget in WIDGETS:
		if not WIDGETS[widget].modes.has(mode):
			continue
		if widget.begins_with("tool_") and not tools_open:
			continue
		if widget.begins_with("base_") and not base_nearby:
			continue
		out.append(widget)
	return out

func set_mode(new_mode: String) -> void:
	mode = new_mode
	tools_open = false
	release_all()

func set_base_nearby(near: bool) -> void:
	if near == base_nearby:
		return
	base_nearby = near
	if not near:
		for widget in WIDGETS:
			if widget.begins_with("base_") and _held.has(widget):
				_fingers.erase(_held[widget])
				_held.erase(widget)
				_lift(widget)

func _widget_visible(widget: String) -> bool:
	return visible_widgets().has(widget)

func _hit(position: Vector2) -> String:
	for widget in WIDGETS:
		if _widget_visible(widget) and _rect(widget).has_point(position):
			return widget
	return ""

## A finger goes down on, or lifts from, the screen.
func touch(index: int, position: Vector2, pressed: bool) -> void:
	if pressed:
		if _fingers.has(index) or not wanted():
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
	if widget == "tools":
		tools_open = not tools_open
		return
	for key in WIDGETS[widget].keys:
		TouchKeys.set_key(key, true)
	if widget.begins_with("tool_"):
		tools_open = false

func _lift(widget: String) -> void:
	if widget == "pad":
		_pad_thumb = _rect("pad").get_center()
		for key in PAD_KEYS:
			TouchKeys.set_key(key, false)
	elif WIDGETS[widget].hold:
		for key in WIDGETS[widget].keys:
			TouchKeys.set_key(key, false)
	else:
		_tap_frames[widget] = TAP_HOLD_FRAMES

func _apply_pad(position: Vector2) -> void:
	var rect := _rect("pad")
	_pad_thumb = position
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

func _ready() -> void:
	canvas = Control.new()
	canvas.name = "Canvas"
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.draw.connect(_draw_widgets)
	add_child(canvas)
	rotate_hint = Label.new()
	rotate_hint.name = "RotateHint"
	rotate_hint.text = "Rotate your phone"
	rotate_hint.set_anchors_preset(Control.PRESET_FULL_RECT)
	rotate_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rotate_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rotate_hint.add_theme_font_size_override("font_size", 24)
	rotate_hint.visible = false
	add_child(rotate_hint)
	get_viewport().size_changed.connect(_refresh_layout_size)
	_refresh_layout_size()
	_pad_thumb = _rect("pad").get_center()

func _refresh_layout_size() -> void:
	layout_size = get_viewport().get_visible_rect().size

func _process(_delta: float) -> void:
	var paused := get_tree().paused
	if paused != _was_paused:
		_was_paused = paused
		tools_open = false
		release_all()
	var shown := wanted()
	canvas.visible = shown and not is_portrait(layout_size)
	rotate_hint.visible = shown and is_portrait(layout_size)
	if canvas.visible:
		canvas.queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()

const LABELS := {
	"dig": "DIG", "flare": "FLARE", "use": "USE", "tools": "TOOLS", "esc": "ESC", "continue": "CONTINUE",
	"tool_rope": "ROPE", "tool_ladder": "LADDER", "tool_anchor": "ANCHOR", "tool_lamp": "LAMP",
	"tool_beam": "BEAM", "tool_grapple": "GRAPPLE", "base_plant": "PLANT", "base_repair": "REPAIR",
	"base_fortify": "FORTIFY", "base_grow": "GROW", "buy1": "1", "buy2": "2", "buy3": "3",
}

## Flat, semi-transparent pixel-style shapes: a darker outline, a short label,
## brighter while held. The pad is a ring with four ticks and a thumb dot.
func _draw_widgets() -> void:
	var font := ThemeDB.fallback_font
	var u := layout_size.y / 648.0
	for widget in visible_widgets():
		var rect := _rect(widget)
		var held: bool = _held.has(widget) or _tap_frames.has(widget) or (widget == "tools" and tools_open)
		var fill := Color(0.9, 0.75, 0.35, 0.55 if held else 0.28)
		if widget == "pad":
			var centre := rect.get_center()
			var radius := rect.size.x / 2.0
			canvas.draw_circle(centre, radius, Color(0.9, 0.75, 0.35, 0.18))
			canvas.draw_arc(centre, radius, 0.0, TAU, 32, Color(0.1, 0.08, 0.05, 0.7), 2.0 * u)
			for dir in [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]:
				canvas.draw_line(centre + dir * radius * 0.55, centre + dir * radius * 0.8, Color(0.95, 0.9, 0.8, 0.6), 3.0 * u)
			var thumb := _pad_thumb if _held.has("pad") else centre
			thumb = centre + (thumb - centre).limit_length(radius)
			canvas.draw_circle(thumb, radius * 0.3, Color(0.95, 0.85, 0.5, 0.55 if held else 0.35))
			continue
		canvas.draw_rect(rect, fill)
		canvas.draw_rect(rect, Color(0.1, 0.08, 0.05, 0.75), false, 2.0 * u)
		var text: String = LABELS.get(widget, "")
		var size := int(16.0 * u)
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		canvas.draw_string(font, rect.get_center() + Vector2(-width / 2.0, size * 0.35), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(1, 1, 1, 0.9))

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		# A touch synthesised from the mouse (so a desktop can test the controls)
		# must not reveal them on its own.
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			seen_touch = true
		touch(event.index, event.position, event.pressed)
	elif event is InputEventScreenDrag:
		drag(event.index, event.position)
