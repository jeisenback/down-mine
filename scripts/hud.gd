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

@onready var fuel_label: Label = $Margin/VBox/FuelLabel
@onready var health_label: Label = $Margin/VBox/HealthLabel
@onready var noise_label: Label = $Margin/VBox/NoiseLabel
@onready var noise_bar: ProgressBar = $Margin/VBox/NoiseBar
@onready var ore_label: Label = $Margin/VBox/OreLabel
@onready var banked_label: Label = $Margin/VBox/BankedLabel
@onready var base_label: Label = $Margin/VBox/BaseLabel
@onready var escort_label: Label = $Margin/VBox/EscortLabel
@onready var compass: Node2D = $Compass
@onready var stranded_compass: Node2D = $StrandedCompass
@onready var stranded_arrow: Polygon2D = $StrandedCompass/Arrow
@onready var run_summary: ColorRect = $RunSummary
@onready var run_summary_label: Label = $RunSummary/SummaryLabel

var _summary_header: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_input(event: InputEvent) -> void:
	if not run_summary.visible:
		return
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	if key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER]:
		new_run_requested.emit()
	var index := key.physical_keycode - KEY_1
	if index < 0 or index > 8:
		return
	if index < Progress.UPGRADE_ORDER.size():
		upgrade_requested.emit(Progress.UPGRADE_ORDER[index])
	else:
		crew_toggle_requested.emit(index - Progress.UPGRADE_ORDER.size())

func update_fuel(fraction: float) -> void:
	fuel_label.text = "Light: %d%%" % int(fraction * 100)

func update_health(health: int) -> void:
	health_label.text = "Health: %d" % max(0, health)

func update_noise(value: float, fraction: float) -> void:
	noise_label.text = "Noise: %d" % int(value)
	noise_bar.value = fraction * 100.0

func update_currency(amount: int) -> void:
	ore_label.text = "Ore: %d" % amount

func update_base(health: int, max_health: int, under_attack: bool) -> void:
	base_label.text = "Base: %d/%d%s" % [health, max_health, "  UNDER ATTACK" if under_attack else ""]
	base_label.modulate = Color(1, 0.4, 0.3) if under_attack else Color(1, 1, 1)

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

## Second arrow, in a stranded miner's shirt colour (see Main).
func update_stranded_compass(to_target: Vector2, color: Color) -> void:
	stranded_arrow.color = color
	_point_arrow(stranded_compass, to_target)

func hide_stranded_compass() -> void:
	stranded_compass.visible = false

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
func show_run_summary(title: String, success: bool, currency: int, depth: int, progress: Progress, notes: Array = []) -> void:
	var currency_line := "Ore banked: %d" % currency if success else "Ore lost: %d" % currency
	_summary_header = "\n".join([title, currency_line, "Depth reached: %d tiles" % depth] + notes)
	refresh_hub(progress)
	run_summary.visible = true

## The run summary doubles as the hub: spend banked ore, then go back down.
func refresh_hub(progress: Progress) -> void:
	var lines := [_summary_header, "", "Banked ore: %d" % progress.banked_ore]
	for i in range(Progress.UPGRADE_ORDER.size()):
		var id: String = Progress.UPGRADE_ORDER[i]
		var upgrade: Dictionary = Progress.UPGRADES[id]
		var cost := progress.next_cost(id)
		var price := "MAX" if cost < 0 else "%d ore" % cost
		lines.append("[%d] %s (%s)  Lv %d/%d  - %s" % [
			i + 1, upgrade.name, upgrade.effect, progress.level(id), upgrade.max_level, price])
	lines.append("")
	lines.append("Crew %d/%d" % [progress.crew().size(), progress.crew_slots()])
	if progress.roster.is_empty():
		lines.append("No one yet - find lost miners in the mine")
	var first_key := Progress.UPGRADE_ORDER.size() + 1
	for i in range(progress.roster.size()):
		var member: Dictionary = progress.roster[i]
		var type_info: Dictionary = Progress.NPC_TYPES[member.type]
		var on_crew := "  [CREW]" if member.name in progress.crew_names else ""
		var key_label := "[%d] " % (first_key + i) if first_key + i <= 9 else ""
		lines.append("%s%s - %s: %s%s" % [key_label, member.name, type_info.label, type_info.effect, on_crew])
	for npc in progress.stranded:
		var last_layer: bool = npc.layer == Progress.LAYER_NAMES.size() - 1
		var fate := "lost for good if not rescued next run" if last_layer else "drifts to the %s if not rescued" % Progress.LAYER_NAMES[npc.layer + 1]
		lines.append("Stranded: %s in the %s - %s" % [npc.name, Progress.LAYER_NAMES[npc.layer], fate])
	lines.append("")
	lines.append("Press Enter for a new run")
	run_summary_label.text = "\n".join(lines)
