extends Node2D
class_name Outpost

## A survivor outpost (milestone 34, a mine event): a lit camp of living
## miners. E trades run ore for a supply pack (tools, even ones not yet
## unlocked at the hub), while stock lasts. One survivor here can be
## recruited (see LostMiner.recruit_cost). The survivors talk, so every
## second spent near the outpost adds noise.
const PACK_ORE := 20
const PACK := {"lamps": 1, "ladders": 2, "anchors": 1}
const STOCK := 2
const NOISE_RADIUS := 80.0
const NOISE_PER_SECOND := 2.0
const RECRUIT_ORE := 40
const SURVIVOR_OFFSET := Vector2(48, 0)

var run: RunContext
var stock: int = STOCK

func _ready() -> void:
	add_to_group(Groups.MINE_EVENTS)

func _process(delta: float) -> void:
	if run and run.player.global_position.distance_to(global_position) < NOISE_RADIUS:
		run.noise_meter.add_noise(NOISE_PER_SECOND * delta, global_position)

func prompt(run: RunContext) -> String:
	if stock <= 0:
		return "The outpost has nothing left to trade"
	if run.player.currency < PACK_ORE:
		return "Supplies cost %d ore" % PACK_ORE
	return "E: trade %d ore for 1 lamp, 2 ladders, 1 anchor (%d left)" % [PACK_ORE, stock]

func use(run: RunContext) -> void:
	if stock <= 0 or run.player.currency < PACK_ORE:
		return
	stock -= 1
	run.player.currency -= PACK_ORE
	run.add_lamps(PACK.lamps)
	run.player.ladders_left += PACK.ladders
	run.player.anchors_left += PACK.anchors
	Sfx.play("place")
