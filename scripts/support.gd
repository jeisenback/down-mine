extends Node2D
class_name Support

## A timber support beam (milestone 32, the PRD's "supports"): built where
## the player stands, it stops tunnel collapses and floor crumbling within
## RADIUS_TILES - keeping a stretch of the route home open. Wears out like
## other placed structures, faster in the dark.
const RADIUS_TILES := 3.0
const LIFE_SECONDS := 180.0
const DARK_DECAY_MULTIPLIER := 2.0

var lifetime: float = 1.0

func _ready() -> void:
	add_to_group("supports")

func _process(delta: float) -> void:
	var rate := (1.0 / LIFE_SECONDS) * (1.0 if MineLight.is_lit(get_tree(), global_position) else DARK_DECAY_MULTIPLIER)
	lifetime -= rate * delta
	if lifetime <= 0.0:
		queue_free()

## Whether any standing support protects world_pos.
static func protects(tree: SceneTree, world_pos: Vector2) -> bool:
	for support in tree.get_nodes_in_group("supports"):
		if support.global_position.distance_to(world_pos) <= RADIUS_TILES * MineGrid.TILE_SIZE:
			return true
	return false
