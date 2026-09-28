extends Node2D
class_name Anchor

## A placed grapple point (milestone 27, the PRD's "anchors"): hammered in
## where the player stands, then the grapple (Q) pulls the player straight
## to it from anywhere within range in line of sight - the answer to
## caverns whose ceiling is out of grapple reach. Decays like other placed
## tools, but slowly.
const LIFE_SECONDS := 180.0
const DARK_DECAY_MULTIPLIER := 2.0

var life_seconds: float = LIFE_SECONDS
var lifetime: float = 1.0

func _ready() -> void:
	add_to_group("anchors")

func _process(delta: float) -> void:
	var rate := (1.0 / life_seconds) * (1.0 if MineLight.is_lit(get_tree(), global_position) else DARK_DECAY_MULTIPLIER)
	lifetime -= rate * delta
	if lifetime <= 0.0:
		queue_free()
