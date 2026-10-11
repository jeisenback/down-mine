extends CanvasLayer
class_name HUD

## Emitted when the player asks for another run from the run summary.
## The HUD runs while the tree is paused (see _ready) so it can hear this.
signal new_run_requested
## Hub purchase, by Progress upgrade id (keys 1, 2, ... on the summary).
signal upgrade_requested(id: String)
## Crew picker, by roster index (the keys after the upgrade keys).
signal crew_toggle_requested(roster_index: int)

const COMPASS_MARGIN := 40.0
# Below this distance, hide the arrow instead of pointing it - arctan2 of
# a near-zero direction vector is extremely sensitive to small position
# jitter, so without a real "arrived" radius the arrow spins erratically
# as soon as the player gets close, not just when exactly on top of it.
const ARRIVAL_RADIUS := 32.0
# Hub roster keys A-J: one per possible miner (10 names).
const ROSTER_KEYS := 10
const MESSAGE_SECONDS := 8.0

# Milestone 41: a title screen on first launch and a controls overlay on
# Esc, both pausing the game. Hub letters A-J pick crew, so the overlay
# key can't be a letter.
const TITLE_TEXT := """DOWN MINE

Dig down through six layers to the Heart of the mine and bring it home.
Rescue lost miners on the way. Keep your light burning and your noise low.

Enter: start        Esc: controls"""
const CONTROLS_TEXT := """CONTROLS  (Esc to close)

A / D  move        W  jump (tap for a short hop; into a 2-tile ledge to mantle)
Space  dig forward (with W: up)        S  dig down (with A / D: stairs)
Shift  flare the light        Q  grapple up, or to an anchor
R  rope up (S+R: down over an edge)        T  ladder        G  anchor        L  lamp
E  use a camp, lift, outpost, vault or relic - or extract at the surface
P  plant the base here        F (hold)  repair base        B  fortify base
1  support beam        U  grow the base (Outpost: beacon, Fort: alarm bell)

At the hub:  1-6 buy upgrades,  A-J choose crew,  L  recent runs,  Enter  new run"""

## The controls overlay in the hub (milestone 57).
const HUB_CONTROLS_TEXT := """CONTROLS  (Esc to close)

A / D  walk        W  jump
1 2 3  buy at the building you stand beside
E  join or leave the crew beside a miner, open the notice board, or go down the mine at the entrance"""

const DEBUG_TEXT := """

DEBUG:  I god mode    O +100 ore    Y refill light
N teleport to next event    K drop to next layer    M reveal map"""

## Session-wide, so the title shows once per launch, not every new run.
## The test runner sets it so scene tests aren't paused on the title.
static var title_seen: bool = false

@onready var fuel_label: Label = $Margin/VBox/FuelLabel
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
var showing_run_log: bool = false
var _progress: Progress
var _noise_warning: bool = false
var _noise_value: float = 0.0
var _message: String = ""
var _message_time: float = 0.0
var overlay: ColorRect
var seed_label: Label
var _controls_text: String = CONTROLS_TEXT
var _overlay_label: Label
var _showing_title: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	if not title_seen:
		_show_overlay(TITLE_TEXT, true)

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
	var hint := Label.new()
	hint.text = "Esc: controls"
	hint.modulate = Color(1, 1, 1, 0.6)
	hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	hint.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(hint)
	seed_label = Label.new()
	seed_label.modulate = Color(1, 1, 1, 0.6)
	seed_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, 12)
	seed_label.position.y += 24
	seed_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	add_child(seed_label)
	add_child(overlay)

## The hub shows only the banked ore and the prompt line: the mine's
## status rows and the compass are hidden, and Esc shows the hub's controls.
func set_hub_mode() -> void:
	for row in [fuel_label, health_label, layer_label, noise_label, noise_bar, ore_label, base_label, wave_label, lamp_label, escort_label]:
		row.visible = false
	compass.visible = false
	_controls_text = HUB_CONTROLS_TEXT

## Seed in the corner (to report or replay a mine); debug adds its keys
## to the controls overlay.
func show_seed(mine_seed: int, debug: bool) -> void:
	seed_label.text = "Seed %d%s" % [mine_seed, "  DEBUG" if debug else ""]
	if debug:
		_controls_text = CONTROLS_TEXT + DEBUG_TEXT

func _show_overlay(text: String, is_title: bool) -> void:
	_overlay_label.text = text
	_showing_title = is_title
	overlay.visible = true
	get_tree().paused = true

## Closes the overlay; the game stays paused behind the run summary.
func _hide_overlay() -> void:
	overlay.visible = false
	_showing_title = false
	title_seen = true
	get_tree().paused = run_summary.visible

## Esc toggles controls (from the title too); Enter starts from the
## title. Returns whether the key was used.
func _overlay_key(keycode: int) -> bool:
	if keycode == KEY_ESCAPE:
		if overlay.visible and not _showing_title:
			_hide_overlay()
		else:
			_show_overlay(_controls_text, false)
		return true
	if overlay.visible and keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_hide_overlay()
		return true
	return overlay.visible # swallow other keys while it's up

func _process(delta: float) -> void:
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
	if key.physical_keycode == KEY_L and _progress:
		showing_run_log = not showing_run_log
		refresh_hub(_progress)
		return
	# Numbers buy upgrades/unlocks; letters A-J toggle roster members.
	var index := key.physical_keycode - KEY_1
	if index >= 0 and index < Progress.UPGRADE_ORDER.size():
		upgrade_requested.emit(Progress.UPGRADE_ORDER[index])
	var roster_index := key.physical_keycode - KEY_A
	if roster_index >= 0 and roster_index < ROSTER_KEYS:
		crew_toggle_requested.emit(roster_index)

func update_fuel(fraction: float) -> void:
	fuel_label.text = "Light: %d%%" % int(fraction * 100)

func update_health(health: int) -> void:
	health_label.text = "Health: %d" % max(0, health)

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
	var lines := ([_message] if _message != "" else []) + (["     ".join(prompts)] if not prompts.is_empty() else [])
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
		return
	arrow.visible = true
	var direction := to_target.normalized()
	var viewport_size := get_viewport().get_visible_rect().size
	var center := viewport_size / 2.0
	var radius: float = max(0.0, min(center.x, center.y) - COMPASS_MARGIN)
	arrow.position = center + direction * radius
	arrow.rotation = direction.angle()

## Right now a run only ever ends by dying or reaching this. Without a
## visible outcome it just looked like the game froze - this makes an
## ending actually read as an ending.
func _show_run_log(progress: Progress) -> void:
	var lines := ["RECENT RUNS (newest first)", ""]
	if progress.run_log.is_empty():
		lines.append("No runs logged yet")
	for entry in progress.run_log:
		lines.append(Progress.run_log_line(entry))
	lines.append("")
	lines.append("L: back to the hub        Enter: new run")
	run_summary_label.text = "\n".join(lines)

func show_run_summary(title: String, success: bool, currency: int, depth: int, progress: Progress, notes: Array = []) -> void:
	var currency_line := "Ore banked: %d" % currency if success else "Ore lost: %d" % currency
	_summary_header = "\n".join([title, currency_line, "Depth reached: %d tiles" % depth] + notes)
	refresh_hub(progress)
	run_summary.visible = true
	prompt_label.visible = false # run is over; no actions to prompt

## The run summary doubles as the hub: spend banked ore, then go back down.
## L swaps it for the run log page (milestone 45).
func refresh_hub(progress: Progress) -> void:
	_progress = progress
	if showing_run_log:
		_show_run_log(progress)
		return
	var lines := [_summary_header, "", "Banked ore: %d" % progress.banked_ore]
	if progress.hearts_claimed > 0:
		lines.append("Hearts claimed: %d - the mine decays faster each time" % progress.hearts_claimed)
	for i in range(Progress.UPGRADE_ORDER.size()):
		var id: String = Progress.UPGRADE_ORDER[i]
		var upgrade: Dictionary = Progress.UPGRADES[id]
		var cost := progress.next_cost(id)
		var price := "%d ore" % cost
		if cost < 0:
			price = "OWNED" if upgrade.max_level == 1 else "MAX"
		lines.append("[%d] %s (%s)  Lv %d/%d  - %s" % [
			i + 1, upgrade.name, upgrade.effect, progress.level(id), upgrade.max_level, price])
	lines.append("")
	lines.append("Crew %d/%d" % [progress.crew().size(), progress.crew_slots()])
	if progress.roster.is_empty():
		lines.append("No one yet - find lost miners in the mine")
	for i in range(progress.roster.size()):
		var member: Dictionary = progress.roster[i]
		var on_crew := "  [CREW]" if member.name in progress.crew_names else ""
		var key_label := "[%s] " % char(KEY_A + i) if i < ROSTER_KEYS else ""
		var runs: int = member.get("runs", 0)
		var history := "%d run%s, from %s" % [runs, "" if runs == 1 else "s", Progress.layer_name(member.get("found_in", 0))]
		if member.has("quirk"):
			history += "; " + Progress.QUIRKS[member.quirk].name
		lines.append("%s%s - %s %s: %s (%s)%s" % [key_label, progress.display_name(member),
			progress.rank_of(member).name, Progress.NPC_TYPES[member.type].label, progress.effect_text(member), history, on_crew])
	for npc in progress.stranded:
		var last_layer: bool = npc.layer == MineGrid.LAYERS.size() - 1
		var fate := "lost for good if not rescued next run" if last_layer else "drifts to the %s if not rescued" % Progress.layer_name(npc.layer + 1)
		lines.append("Stranded: %s in the %s - %s" % [npc.name, Progress.layer_name(npc.layer), fate])
	lines.append("")
	lines.append("L: recent runs        Enter: new run")
	run_summary_label.text = "\n".join(lines)
