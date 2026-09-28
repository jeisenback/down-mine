extends Node2D
class_name Lift

## An old lift shaft (milestone 33, a mine event): repair it with ore -
## loud work - then ride it once, straight up to the surface, escorts
## and all. A way home that costs ore and noise instead of a climb.
const REPAIR_ORE := 30
const REPAIR_NOISE := 35.0

enum State { BROKEN, READY, USED }

var state: State = State.BROKEN

@onready var cage: Polygon2D = $Cage

func _ready() -> void:
	add_to_group("mine_events")

func prompt(main: Node) -> String:
	match state:
		State.BROKEN:
			if main.player.currency < REPAIR_ORE:
				return "Lift repair needs %d ore" % REPAIR_ORE
			return "E: repair the lift, %d ore (loud)" % REPAIR_ORE
		State.READY:
			return "E: ride the lift to the surface"
	return ""

func use(main: Node) -> void:
	if state == State.BROKEN and main.player.currency >= REPAIR_ORE:
		main.player.currency -= REPAIR_ORE
		main.noise_meter.add_noise(REPAIR_NOISE)
		Sfx.play("collapse")
		state = State.READY
		cage.color = Color(0.8, 0.6, 0.3)
	elif state == State.READY:
		state = State.USED
		cage.visible = false
		Sfx.play("place")
		main.ride_to_surface(global_position.x)
