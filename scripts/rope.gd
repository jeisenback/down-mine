extends Area2D
class_name Rope

## A climbable placed tool: ropes (hang down from where they're placed)
## and ladders (stand up from the player's feet) share this script, set
## apart by their scene shape and the life/climb speed the player gives
## them. Lifetime is measured sitting in light; in the dark it decays
## twice as fast, sharing the PRD's "structures decay faster in darkness"
## clock with MineLight.
const DARK_DECAY_MULTIPLIER := 2.0
# Milestone 49: while the player's lantern is out, tools rot this much
# faster again, wherever they hang.
const DARK_ROT_MULTIPLIER := 3.0

var life_seconds: float = 45.0
var climb_speed: float = 80.0
var lifetime: float = 1.0 # 1.0 = fresh, 0.0 = gone

# Ropes draw the tileset's wooden pole strip (8x32), repeated down their
# length (milestone 30). Ladders have their own rails, no Visual node.
const POLE_TEXTURE := preload("res://assets/deep_night/tiles.png")
const POLE_REGION := Rect2i(176, 64, 8, 32)

func _ready() -> void:
	var visual := get_node_or_null("Visual") as Polygon2D
	if visual == null:
		return
	visual.texture = PixelArt.keyed_region(POLE_TEXTURE, POLE_REGION)
	visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	visual.color = Color(1, 1, 1)
	# Map the polygon's x (-3..3) onto the pole's centre columns (1..7).
	visual.uv = PackedVector2Array(visual.polygon).duplicate()
	for i in range(visual.uv.size()):
		visual.uv[i] = visual.polygon[i] + Vector2(4, 0)

func _process(delta: float) -> void:
	var rate := (1.0 / life_seconds) * (1.0 if MineLight.is_lit(get_tree(), global_position) else DARK_DECAY_MULTIPLIER)
	var player := get_tree().get_first_node_in_group("player") as Player
	if player != null and player.light.is_out():
		rate *= DARK_ROT_MULTIPLIER
	lifetime -= rate * delta
	if lifetime <= 0.0:
		queue_free()
