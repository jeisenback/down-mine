extends TestCase

## The drawn art is wired into each scene: the old sprite node is gone, an
## ArtSprite named Art of the right kind took its place, and scripts drive it.

const PlayerScene := preload("res://scenes/Player.tscn")
const RunBaseScene := preload("res://scenes/RunBase.tscn")

func _art_of(scene_path: String, kind: String) -> Node:
	var node: Node = load(scene_path).instantiate()
	add(node)
	node.set_physics_process(false) # creatures need a player and target before they tick
	await tree.process_frame
	var art := node.get_node_or_null("Art")
	assert_true(art is ArtSprite, "%s has an Art node" % scene_path)
	if art is ArtSprite:
		assert_eq(art.kind, kind, "%s kind" % scene_path)
	return node

func _still_player(pos: Vector2) -> Player:
	var player: Player = add(PlayerScene.instantiate())
	player.set_physics_process(false)
	player.global_position = pos
	return player

# --- creatures ---------------------------------------------------------------

func test_creature_scenes_draw_their_own_art() -> void:
	var stalker := await _art_of("res://scenes/Stalker.tscn", "stalker")
	assert_true(stalker.get_node_or_null("Body") == null, "no old stalker sprite")
	var burrower := await _art_of("res://scenes/Burrower.tscn", "burrower")
	assert_true(burrower.get_node_or_null("Sprite2D") == null, "no old burrower sprite")
	var snuffer := await _art_of("res://scenes/Snuffer.tscn", "snuffer")
	assert_true(snuffer.get_node_or_null("Sprite2D") == null, "no old snuffer sprite")

func test_stalker_mirrors_toward_its_heading() -> void:
	var stalker: Stalker = await _art_of("res://scenes/Stalker.tscn", "stalker")
	stalker.velocity = Vector2(-30, 0)
	stalker._process(0.016)
	assert_true(stalker.get_node("Art").flip_h, "mirrored heading left")
	stalker.velocity = Vector2(30, 0)
	stalker._process(0.016)
	assert_true(not stalker.get_node("Art").flip_h, "not mirrored heading right")

func test_stalker_lunges_in_its_strike() -> void:
	var stalker: Stalker = await _art_of("res://scenes/Stalker.tscn", "stalker")
	stalker.player = _still_player(Vector2(10, 0))
	stalker._attack()
	stalker._process(0.0)
	assert_eq(stalker.get_node("Art").art.pose, 1.0, "lunging right after a strike")
	stalker._process(Stalker.STRIKE_POSE_SECONDS)
	assert_eq(stalker.get_node("Art").art.pose, 0.0, "rested again")

func test_burrower_and_snuffer_mirror_toward_their_target() -> void:
	var base: RunBase = add(RunBaseScene.instantiate())
	base.global_position = Vector2(-10, 0)
	var burrower: Burrower = load("res://scenes/Burrower.tscn").instantiate()
	add(burrower)
	burrower.set_physics_process(false)
	await tree.process_frame
	burrower.player = _still_player(Vector2(500, 0))
	burrower.target = base
	burrower.global_position = Vector2.ZERO
	burrower._physics_process(0.016)
	assert_true(burrower.get_node("Art").flip_h, "burrower faces its target on the left")
	base.global_position = Vector2(10, 0)
	burrower._physics_process(0.016)
	assert_true(not burrower.get_node("Art").flip_h, "and on the right")

func test_burrower_snaps_its_mandibles_when_it_strikes() -> void:
	var base: RunBase = add(RunBaseScene.instantiate())
	var burrower: Burrower = load("res://scenes/Burrower.tscn").instantiate()
	add(burrower)
	burrower.set_physics_process(false)
	await tree.process_frame
	burrower.player = _still_player(Vector2(500, 0))
	burrower.target = base
	burrower.global_position = base.global_position + Vector2(Burrower.ATTACK_RANGE - 1.0, 0)
	burrower._physics_process(0.016)
	assert_eq(burrower.get_node("Art").art.pose, 1.0, "mandibles wide on a strike")

# --- pickups -----------------------------------------------------------------

func test_pickup_scenes_draw_their_own_art() -> void:
	var fuel := await _art_of("res://scenes/FuelPickup.tscn", "fuel")
	assert_true(fuel.get_node_or_null("Body") == null, "no old fuel sprite")
	var ore := await _art_of("res://scenes/OrePickup.tscn", "ore")
	assert_true(ore.get_node_or_null("Body") == null, "no old ore sprite")

func test_pickups_are_still_picked_up() -> void:
	var player := _still_player(Vector2.ZERO)
	player.light.fuel = 10.0
	var fuel: FuelPickup = add(load("res://scenes/FuelPickup.tscn").instantiate())
	fuel._on_body_entered(player)
	assert_true(player.light.fuel > 10.0, "fuel added")
	assert_true(fuel.is_queued_for_deletion(), "fuel pickup consumed")
	var ore: OrePickup = add(load("res://scenes/OrePickup.tscn").instantiate())
	var before := player.currency
	ore._on_body_entered(player)
	assert_eq(player.currency, before + ore.value, "ore banked")
	assert_true(ore.is_queued_for_deletion(), "ore pickup consumed")
