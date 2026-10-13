extends CanvasLayer
class_name HUD

## Emitted when the player presses Enter on the run summary (it leads to the hub).
## The HUD runs while the tree is paused (see _ready) so it can hear this.
signal new_run_requested
## The player confirmed "abandon this run" in the controls overlay (milestone 66).
signal abandon_requested

const COMPASS_MARGIN := 40.0
# Below this distance, hide the arrow instead of pointing it - arctan2 of
# a near-zero direction vector is extremely sensitive to small position
# jitter, so without a real "arrived" radius the arrow spins erratically
# as soon as the player gets close, not just when exactly on top of it.
const ARRIVAL_RADIUS := 32.0
const MESSAGE_SECONDS := 8.0

# Milestone 41: a title screen on first launch and a controls overlay on
# Esc, both pausing the game.
const TITLE_TEXT := """DOWN MINE

Dig down through six layers to the Heart of the mine and bring it home.
Rescue lost miners on the way. Keep your light burning and your noise low.

%s: start        %s: controls"""
const CONTROLS_TEXT := """CONTROLS  (Esc to close)

A / D  move        W  jump (tap for a short hop; into a 2-tile ledge to mantle)
Space  dig forward (with W: up)        S  dig down (with A / D: stairs)
Shift  flare the light        Q  grapple up, or to an anchor
R  rope up (S+R: down over an edge)        T  ladder        G  anchor        L  lamp
E  use a camp, lift, outpost, vault or relic - or extract at the surface
P  plant the base here        F (hold)  repair base        B  fortify base
1  support beam        U  grow the base (Outpost: beacon, Fort: alarm bell)"""

## The controls overlay in the hub (milestone 57).
const HUB_CONTROLS_TEXT := """CONTROLS  (Esc to close)

A / D  walk        W  jump
1 2 3  buy at the building you stand beside
E  join or leave the crew beside a miner, open the notice board, or go down the mine at the entrance"""

# The same two overlays for the touch controls (milestone 62): the buttons, not the keys.
const TOUCH_CONTROLS_TEXT := """CONTROLS  (Continue to close)

Pad  left and right walk, up jumps, down digs down; down and a side digs stairs; push into rock to tunnel
Dig  hold to dig forward (with the pad up: dig up)        Flare  hold to flare the light
Use  a camp, lift, outpost, vault or relic - or extract at the surface
Tools  rope, grapple, beam, ladder, lamp, anchor; at the base: repair, fortify, grow; plant the base"""
const TOUCH_HUB_CONTROLS_TEXT := """CONTROLS  (Continue to close)

Pad  left and right walk, up jumps
1 2 3  buy at the building you stand beside
Use  join or leave the crew beside a miner, open the notice board, or go down the mine at the entrance"""

const ABANDON_LINE := "X  abandon this run (asks first)"
const ABANDON_ASK := """Abandon this run?

The ore you carry is lost, as if you had died.

Press X again to confirm, Esc to cancel."""
const TOUCH_ABANDON_ASK := """Abandon this run?

The ore you carry is lost, as if you had died.

Tap ABANDON again to confirm, HELP to cancel."""

const DEBUG_TEXT := """

DEBUG:  I god mode    O +100 ore    Y refill light
N teleport to next event    K drop to next layer    M reveal map"""

## Session-wide, so the title shows once per launch, not every new run.
## The test runner sets it so scene tests aren't paused on the title.
static var title_seen: bool = false

@onready var fuel_label: Label = $Margin/VBox/FuelLabel
@onready var fuel_bar: ProgressBar = $Margin/VBox/FuelBar
@onready var health_label: Label = $Margin/VBox/HealthLabel
@onready var layer_label: Label = $Margin/VBox/LayerLabel
@onready var noise_label: Label = $Margin/VBox/NoiseLabel
@onready var noise_bar: ProgressBar = $Margin/VBox/NoiseBar
@onready var ore_label: Label = $Margin/VBox/OreLabel
@onready var banked_label: Label = $Margin/VBox/BankedLabel
@onready var base_label: Label = $Margin/VBox/BaseLabel
@onready var wave_label: Label = $Margin/VBox/WaveLabel
@onready var escort_label: Label = $Margin/VBox/EscortLabel
@onready var lamp_label: Label = $Margin/VBox/LampLabel
@onready var prompt_label: Label = $PromptLabel
@onready var compass: Node2D = $Compass
@onready var run_summary: ColorRect = $RunSummary
@onready var run_summary_label: Label = $RunSummary/SummaryLabel

var _summary_header: String = ""
var _noise_warning: bool = false
var _noise_value: float = 0.0
var _message: String = ""
var _message_time: float = 0.0
## The tool the gamepad's Y would use, shown on the tool line while a pad is the last input in use.
var pad_tool_text: String = ""
var overlay: ColorRect
var seed_label: Label
var _hub_mode: bool = false
var _debug: bool = false
var esc_hint: Label
var compass_label: Label
var _seed: int = 0
var _overlay_label: Label
## What the full-screen overlay is showing: the one fact the overlay code asks about (the
## summary and the hub are separate: the summary is its own node, the hub only picks the text).
enum Overlay { NONE, TITLE, CONTROLS, ASK_ABANDON }
var overlay_state: Overlay = Overlay.NONE

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	_style_labels()
	if not title_seen:
		_set_overlay(Overlay.TITLE)

## Light and Health are the survival stats, so they are larger; every label gets
## a dark outline so it reads over bright ground as well as in the dark.
func _style_labels() -> void:
	var labels: Array = $Margin/VBox.get_children().filter(func(c): return c is Label)
	labels += [prompt_label, esc_hint, seed_label, compass_label]
	for label in labels:
		label.add_theme_constant_override("outline_size", 3)
		label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	for label in [fuel_label, health_label]:
		label.add_theme_font_size_override("font_size", 22)

func _build_overlay() -> void:
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	_overlay_label = Label.new()
	_overlay_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay_label.add_theme_font_size_override("font_size", 16)
	overlay.add_child(_overlay_label)
	esc_hint = Label.new()
	esc_hint.text = "Esc: controls"
	esc_hint.modulate = Color(1, 1, 1, 0.6)
	esc_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	esc_hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(esc_hint)
	seed_label = Label.new()
	seed_label.modulate = Color(1, 1, 1, 0.6)
	seed_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	seed_label.position.y += 24
	seed_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	seed_label.visible = false # the seed lives in the controls overlay; only the debug tag shows
	add_child(seed_label)
	compass_label = Label.new()
	compass_label.text = "Base"
	compass_label.modulate = Color(1, 0.85, 0.3, 0.9)
	compass_label.add_theme_font_size_override("font_size", 12)
	compass_label.visible = false
	add_child(compass_label)
	add_child(overlay)

## The hub shows only the banked ore and the prompt line: the mine's
## status rows and the compass are hidden, and Esc shows the hub's controls.
func set_hub_mode() -> void:
	for row in [fuel_label, fuel_bar, health_label, layer_label, noise_label, noise_bar, ore_label, base_label, wave_label, lamp_label, escort_label]:
		row.visible = false
	compass.visible = false
	compass_label.visible = false
	_hub_mode = true

## Seed in the corner (to report or replay a mine); debug adds its keys
## to the controls overlay.
func show_seed(mine_seed: int, debug: bool) -> void:
	_seed = mine_seed
	seed_label.text = "DEBUG"
	seed_label.visible = debug
	_debug = debug

## Whether text should name the touch buttons rather than keys.
func _touch() -> bool:
	return TouchControls.wanted()

## The controls overlay for what is on screen now: keyboard or touch, mine or hub.
func _controls_text() -> String:
	var text := CONTROLS_TEXT + (DEBUG_TEXT if _debug else "")
	if _touch():
		text = TOUCH_HUB_CONTROLS_TEXT if _hub_mode else TOUCH_CONTROLS_TEXT
	elif _hub_mode:
		text = HUB_CONTROLS_TEXT
	else:
		text += "\n\n" + ABANDON_LINE
	return text + ("\n\nSeed %d" % _seed if _seed != 0 else "")

## Enters an overlay state: its text, whether it shows, and whether the game is paused (it is
## behind any overlay and behind the run summary). Leaving to NONE ends the title for the session.
func _set_overlay(state: Overlay) -> void:
	overlay_state = state
	match state:
		Overlay.TITLE:
			_overlay_label.text = TITLE_TEXT % [KeyHint.label("Enter", _touch()), KeyHint.label("Esc", _touch())]
		Overlay.CONTROLS:
			_overlay_label.text = _controls_text()
		Overlay.ASK_ABANDON:
			_overlay_label.text = TOUCH_ABANDON_ASK if _touch() else ABANDON_ASK
		Overlay.NONE:
			title_seen = true
	overlay.visible = state != Overlay.NONE
	get_tree().paused = state != Overlay.NONE or run_summary.visible

## Whether the controls overlay can end the run: open, in the mine, run not over.
func can_abandon() -> bool:
	return (overlay_state == Overlay.CONTROLS or overlay_state == Overlay.ASK_ABANDON) and not _hub_mode and not run_summary.visible

## Esc toggles controls (from the title too); Enter starts from the title; X twice abandons from
## the controls. Returns whether the key was used (an open overlay swallows every key).
func _overlay_key(keycode: int) -> bool:
	match overlay_state:
		Overlay.NONE:
			if keycode == KEY_ESCAPE:
				_set_overlay(Overlay.CONTROLS)
				return true
			return false
		Overlay.TITLE:
			if keycode == KEY_ESCAPE:
				_set_overlay(Overlay.CONTROLS)
			elif keycode in [KEY_ENTER, KEY_KP_ENTER]:
				_set_overlay(Overlay.NONE)
		Overlay.CONTROLS:
			if keycode == KEY_ESCAPE or keycode in [KEY_ENTER, KEY_KP_ENTER]:
				_set_overlay(Overlay.NONE)
			elif keycode == KEY_X and can_abandon():
				_set_overlay(Overlay.ASK_ABANDON)
		Overlay.ASK_ABANDON:
			if keycode == KEY_ESCAPE:
				_set_overlay(Overlay.NONE)
			elif keycode == KEY_X and can_abandon():
				_set_overlay(Overlay.NONE)
				abandon_requested.emit()
			else:
				_set_overlay(Overlay.CONTROLS) # any other key takes the question back
	return true

func _process(delta: float) -> void:
	esc_hint.visible = not _touch() # the ESC button is on screen (labelled HELP)
	prompt_label.modulate.a = 0.0 if get_tree().paused else 1.0 # not under the Continue button
	var shift := TOUCH_PROMPT_SHIFT if _touch() else 0.0
	prompt_label.offset_left = -300.0 + shift
	prompt_label.offset_right = 300.0 + shift
	_message_time -= delta
	if _message_time <= 0.0:
		_message = ""

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if _overlay_key(key.physical_keycode):
		get_viewport().set_input_as_handled()
		return
	if not run_summary.visible:
		return
	if key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		new_run_requested.emit()

# On touch the buy and Use buttons sit right of centre, so the prompt line moves left of them.
const TOUCH_PROMPT_SHIFT := -120.0

const LOW_LIGHT_FRACTION := 0.25
const WARNING_COLOR := Color(1, 0.4, 0.3)

func update_fuel(fraction: float) -> void:
	fuel_label.text = "Light: %d%%" % int(fraction * 100)
	fuel_bar.value = fraction * 100.0
	fuel_bar.modulate = WARNING_COLOR if fraction < LOW_LIGHT_FRACTION else Color(1, 1, 1)

func update_health(health: int, max_health: int) -> void:
	health_label.text = "Health: %d/%d" % [max(0, health), max_health]
	health_label.modulate = WARNING_COLOR if health <= 1 else Color(1, 1, 1)

func update_layer(text: String) -> void:
	layer_label.text = text

func update_noise(value: float, fraction: float) -> void:
	_noise_value = value
	noise_label.text = "Noise: %d%s" % [int(value), "  LOUD" if _noise_warning else ""]
	noise_bar.value = fraction * 100.0

## The alarm bell's warning (milestone 32): noise line turns red.
func set_noise_warning(on: bool) -> void:
	if on == _noise_warning:
		return
	_noise_warning = on
	noise_label.modulate = Color(1, 0.4, 0.3) if on else Color(1, 1, 1)
	update_noise(_noise_value, noise_bar.value / 100.0)

func update_currency(amount: int) -> void:
	ore_label.text = "Ore: %d" % amount

## Status only; what the player can do right now goes on the prompt line.
func update_base(run_base: RunBase, under_attack: bool, walls: int) -> void:
	base_label.text = "Base: %s %d/%d  walls %d%s" % [run_base.tier_name(), run_base.health, run_base.max_health(), walls, "  UNDER ATTACK" if under_attack else ""]
	base_label.modulate = Color(1, 0.4, 0.3) if under_attack else Color(1, 1, 1)

## The wave line under Base (milestone 55): when the next wave comes. Red when
## it is close.
func update_wave(text: String, urgent: bool) -> void:
	wave_label.text = text
	wave_label.modulate = Color(1, 0.4, 0.3) if urgent else Color(1, 1, 1)

## Context actions (repair, fortify, plant, extract), one line along the
## bottom of the screen, hidden when there is nothing to do. A message
## (show_message) sits on the line above for a few seconds.
func update_prompts(prompts: Array) -> void:
	var shown := prompts.map(func(p): return KeyHint.prompt(p, _touch(), _hub_mode))
	var lines := ([_message] if _message != "" else []) + (["     ".join(shown)] if not shown.is_empty() else [])
	prompt_label.text = "\n".join(lines)
	prompt_label.visible = not lines.is_empty()

func show_message(text: String) -> void:
	_message = text
	_message_time = MESSAGE_SECONDS

## Placed tools left this run, by name; -1 means not unlocked (hidden).
## Ropes are unlimited, so not listed.
func update_tools(counts: Dictionary, snuffer_hunting: bool) -> void:
	var parts: Array = []
	for tool_name in counts:
		if counts[tool_name] >= 0:
			parts.append("%s %d" % [tool_name, counts[tool_name]])
	if pad_tool_text != "":
		parts.append("Tool: %s" % pad_tool_text)
	if snuffer_hunting:
		parts.append("SNUFFER HUNTING")
	lamp_label.text = "  ".join(parts)
	lamp_label.visible = not parts.is_empty()
	lamp_label.modulate = Color(0.7, 0.8, 1) if snuffer_hunting else Color(1, 1, 1)

func update_escort(miner_name: String) -> void:
	escort_label.text = "Escorting: %s" % miner_name
	escort_label.visible = true

func update_banked(amount: int) -> void:
	banked_label.text = "Banked: %d" % amount

## Points an arrow toward the run base from anywhere in the mine, clamped
## to a circle near the screen edge (an off-screen-indicator, not tied to
## the player's actual on-screen position, since this is a CanvasLayer in
## screen space). to_target is world-space (target - player), so the
## screen-space direction matches it directly since the camera doesn't
## rotate.
func update_compass(to_target: Vector2) -> void:
	_point_arrow(compass, to_target)

func _point_arrow(arrow: Node2D, to_target: Vector2) -> void:
	if to_target.length_squared() < ARRIVAL_RADIUS * ARRIVAL_RADIUS:
		arrow.visible = false
		compass_label.visible = false
		return
	arrow.visible = true
	compass_label.visible = true
	var direction := to_target.normalized()
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size / 2.0
	var radius: float = max(0.0, min(center.x, center.y) - COMPASS_MARGIN)
	arrow.position = center + direction * radius
	arrow.rotation = direction.angle()
	compass_label.position = arrow.position - direction * 30.0 - compass_label.get_minimum_size() / 2.0

## Right now a run only ever ends by dying or reaching this. Without a
## visible outcome it just looked like the game froze - this makes an
## ending actually read as an ending. The hub is a place of its own now
## (milestone 57); Enter goes there.
func show_run_summary(title: String, success: bool, currency: int, depth: int, _progress: Progress, notes: Array = []) -> void:
	var currency_line := "Ore banked: %d" % currency if success else "Ore lost: %d" % currency
	var lines := [title, currency_line, "Depth reached: %d tiles" % depth] + notes + ["", "%s: go to the hub" % KeyHint.label("Enter", _touch())]
	run_summary_label.text = "\n".join(lines)
	run_summary.visible = true
	prompt_label.visible = false # run is over; no actions to prompt
