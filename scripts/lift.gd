extends Node2D
class_name Lift

## An old lift cage (milestone 33, a mine event; hung in the shaft by M51):
## repair it with ore, then ride it once, straight up to the surface,
## escorts and all. A way home that costs ore instead of a climb. It hangs in
## Clay, a quiet layer, so the repair makes no noise anything hears.
const REPAIR_ORE := 30

enum State { BROKEN, READY, USED }

var state: State = State.BROKEN

@onready var cage: ArtSprite = $Art

func _ready() -> void:
	add_to_group("mine_events")

func prompt(main: Node) -> String:
	match state:
		State.BROKEN:
			if main.player.currency < REPAIR_ORE:
				return "Lift repair needs %d ore" % REPAIR_ORE
			return "E: repair the lift, %d ore" % REPAIR_ORE
		State.READY:
			return "E: ride the lift to the surface"
	return ""

func use(main: Node) -> void:
	if state == State.BROKEN and main.player.currency >= REPAIR_ORE:
		main.player.currency -= REPAIR_ORE
		Sfx.play("collapse")
		state = State.READY
		cage.modulate = Color(1, 1, 1) # rust-dark until repaired
	elif state == State.READY:
		state = State.USED
		cage.art.empty = true # the cage has gone up; the rails stay
		Sfx.play("place")
		main.ride_to_surface(global_position.x)
