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
const RUN_ANIM_FPS := 12.0

var player: Player
var miner_name: String = ""
var shirt_color: Color = Color(1, 1, 1)
var npc_type: String = "light"
## True for a miner stranded on an earlier run (vs. this run's new find).
var was_stranded: bool = false
## Layer index they were found in, kept as roster history.
var found_in: int = 0
var following: bool = false
## Crew waiting at the run base (milestone 24): shown, never picked up.
var stationary: bool = false
## Ore to recruit this miner at a survivor outpost (milestone 34); while
## above 0 they stay put and are a mine event (E recruits).
var recruit_cost: int = 0
## Trail points behind the player. Main sets this at pickup so a second
## escort walks behind the first instead of on top of them.
var follow_delay: int = FOLLOW_DELAY_POINTS
var _trail: Array[Vector2] = []
var _anim_time: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	sprite.texture = PixelArt.with_shirt(sprite.texture, shirt_color)
	$MineLight/PointLight2D.color = shirt_color.lightened(0.4)
	if recruit_cost > 0:
		stationary = true
		add_to_group("mine_events")

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
	picked_up.emit()

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
			picked_up.emit()
		return

	var player_pos := player.global_position
	if _trail.is_empty() or _trail[-1].distance_to(player_pos) >= TRAIL_SPACING:
		_trail.append(player_pos)
	if _trail.size() <= follow_delay:
		_anim_time = 0.0
		sprite.frame = 0
		return
	var next: Vector2 = _trail.pop_front()
	if absf(next.x - global_position.x) > 0.01:
		sprite.flip_h = next.x < global_position.x
	global_position = next
	_anim_time += delta
	sprite.frame = int(_anim_time * RUN_ANIM_FPS) % Player.RUN_FRAME_COUNT
