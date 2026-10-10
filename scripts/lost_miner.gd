extends Node2D
class_name LostMiner

## An NPC found in the mine (milestone 13). Touch them and they follow
## the player's exact trail a short way behind - so they go wherever the
## player went (ropes, grapple pulls, dug stairs) with no pathfinding,
## which is the PRD's "escorted NPCs follow the route you built".
## Extracting while they follow adds them to the roster.

signal picked_up

const PICKUP_RANGE := 16.0
const TRAIL_SPACING := 2.0      # px the player must move before a new trail point
const FOLLOW_DELAY_POINTS := 18 # ~2 tiles of trail behind the player, per escort in line

var player: Player
var miner_name: String = ""
var shirt_color: Color = Color(1, 1, 1)
var npc_type: String = "light"
## True for a miner stranded on an earlier run (vs. this run's new find).
var was_stranded: bool = false
## Layer index they were found in, kept as roster history.
var found_in: int = 0
var following: bool = false:
	set(value):
		following = value
		if is_node_ready():
			_refresh_art()
## Crew waiting at the run base (milestone 24): shown, never picked up.
var stationary: bool = false:
	set(value):
		stationary = value
		if is_node_ready():
			_refresh_art()
## Ore to recruit this miner at a survivor outpost (milestone 34); while
## above 0 they stay put and are a mine event (E recruits).
var recruit_cost: int = 0
## Trail points behind the player. Main sets this at pickup so a second
## escort walks behind the first instead of on top of them.
var follow_delay: int = FOLLOW_DELAY_POINTS
var _trail: Array[Vector2] = []
var art: ArtSprite

func _ready() -> void:
	$MineLight/PointLight2D.color = shirt_color.lightened(0.4)
	if recruit_cost > 0:
		stationary = true
		add_to_group("mine_events")
	_refresh_art()

## A miner nobody has found yet sits slumped, lamp guttering; anyone on their
## feet (following, or standing at the base or an outpost) is the miner rig in
## their own coat. The art is rebuilt when that changes.
func _refresh_art() -> void:
	var kind := "player" if (following or stationary) else "lost"
	if art != null and art.kind == kind:
		return
	if art != null:
		art.free()
	art = ArtSprite.new()
	art.name = "Art"
	art.kind = kind
	art.origin = Vector2i(24, 24)
	art.coat = shirt_color.darkened(0.2)
	add_child(art)

func prompt(main: Node) -> String:
	if main.player.currency < recruit_cost:
		return "%s joins for %d ore" % [miner_name, recruit_cost]
	return "E: recruit %s (%s), %d ore" % [miner_name, Progress.NPC_TYPES[npc_type].label, recruit_cost]

func use(main: Node) -> void:
	if main.player.currency < recruit_cost:
		return
	main.player.currency -= recruit_cost
	recruit_cost = 0
	remove_from_group("mine_events")
	stationary = false
	following = true
	_refresh_art()
	picked_up.emit()

## The crew's job pose: digging while their job works, standing otherwise.
## Nothing happens to a miner still sitting waiting to be found.
func set_working(on: bool) -> void:
	if art != null and art.kind == "player":
		art.art.state = "dig" if on else "idle"

## Moves straight to pos and forgets the trail (the lift ride).
func teleport_to(pos: Vector2) -> void:
	_trail.clear()
	global_position = pos

func _physics_process(delta: float) -> void:
	if stationary:
		return
	if not following:
		if global_position.distance_to(player.global_position) < PICKUP_RANGE:
			following = true
			_refresh_art()
			picked_up.emit()
		return

	var player_pos := player.global_position
	if _trail.is_empty() or _trail[-1].distance_to(player_pos) >= TRAIL_SPACING:
		_trail.append(player_pos)
	if _trail.size() <= follow_delay:
		art.art.state = "idle"
		return
	var next: Vector2 = _trail.pop_front()
	if absf(next.x - global_position.x) > 0.01:
		art.flip_h = next.x < global_position.x
	art.art.state = "run" if next.distance_to(global_position) > 0.01 else "idle"
	global_position = next
