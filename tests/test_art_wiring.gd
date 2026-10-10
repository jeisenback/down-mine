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

# --- the miner and lost miners -------------------------------------------------

func test_miner_state_follows_movement() -> void:
	assert_eq(Player.animation_state(true, false, 0.0, 0.0), "idle", "standing")
	assert_eq(Player.animation_state(true, false, 1.0, 0.0), "run", "running")
	assert_eq(Player.animation_state(true, true, 0.0, 0.0), "dig", "digging in place")
	assert_eq(Player.animation_state(true, true, 1.0, 0.0), "dig", "digging forward")
	assert_eq(Player.animation_state(false, false, 1.0, -50.0), "jump", "rising")
	assert_eq(Player.animation_state(false, false, 0.0, 50.0), "fall", "falling")

func test_player_scene_draws_the_miner_and_mirrors_with_facing() -> void:
	var player := _still_player(Vector2.ZERO)
	await tree.process_frame
	var art: ArtSprite = player.get_node("Art")
	assert_eq(art.kind, "player", "kind")
	assert_true(player.get_node_or_null("Body") == null, "no old sprite")
	player.facing = -1
	player._update_animation(0.0, 0.016)
	assert_true(art.flip_h, "mirrored facing left")
	player.facing = 1
	player._update_animation(0.0, 0.016)
	assert_true(not art.flip_h, "not mirrored facing right")

func _lost_miner(color: Color) -> LostMiner:
	var miner: LostMiner = load("res://scenes/LostMiner.tscn").instantiate()
	miner.shirt_color = color
	miner.player = _still_player(Vector2(500, 0))
	add(miner)
	miner.set_physics_process(false)
	return miner

func test_lost_miners_wear_their_own_coat() -> void:
	var a := _lost_miner(Color(0.2, 0.6, 0.9))
	var b := _lost_miner(Color(0.9, 0.7, 0.1))
	await tree.process_frame
	assert_true(a.get_node("Art").art.coat != b.get_node("Art").art.coat, "different coats")

func test_lost_miner_sits_until_found_then_runs_and_mirrors() -> void:
	var miner := _lost_miner(Color(0.2, 0.6, 0.9))
	await tree.process_frame
	assert_eq(miner.get_node("Art").kind, "lost", "waiting miner sits")
	miner.following = true
	miner.global_position = Vector2(100, 0)
	miner.player.global_position = Vector2(100, 0)
	miner.follow_delay = 0
	miner.player.global_position = Vector2(80, 0) # the trail leads left
	miner._physics_process(0.016)
	var art: ArtSprite = miner.get_node("Art")
	assert_eq(art.kind, "player", "found miner is a person on their feet")
	assert_eq(art.art.state, "run", "moving")
	assert_true(art.flip_h, "mirrored heading left")
	miner.player.global_position = miner.global_position
	miner._physics_process(0.016)
	assert_eq(miner.get_node("Art").art.state, "idle", "stopped")

func test_drawing_never_consumes_the_global_random_generator() -> void:
	seed(42)
	var expected := randf()
	seed(42)
	for i in range(5):
		add(ArtSprite.new()).kind = "stalker"
	await tree.process_frame
	assert_eq(randf(), expected, "global generator untouched by art")

# --- the base and placed buildings ----------------------------------------------

func test_run_base_keeps_its_node_names_and_draws_its_art() -> void:
	var base: RunBase = add(RunBaseScene.instantiate())
	await tree.process_frame
	for pair in [["Flag", "flag"], ["Beacon", "beacon"], ["Bell", "bell"]]:
		var art := base.get_node_or_null(pair[0])
		assert_true(art is ArtSprite, "%s is an ArtSprite" % pair[0])
		if art is ArtSprite:
			assert_eq(art.kind, pair[1], "%s kind" % pair[0])
	assert_true(not base.get_node("Beacon").visible and not base.get_node("Bell").visible, "built later")
	base.build_beacon()
	base.build_bell()
	assert_true(base.get_node("Beacon").visible and base.get_node("Bell").visible, "built")

func test_the_bell_swings_harder_while_it_warns() -> void:
	var base: RunBase = add(RunBaseScene.instantiate())
	await tree.process_frame
	base.ring_bell(true)
	assert_eq(base.get_node("Bell").art.pose, 1.0, "ringing")
	base.ring_bell(false)
	assert_eq(base.get_node("Bell").art.pose, 0.0, "quiet")

func test_support_wears_with_its_lifetime() -> void:
	var support: Support = add(load("res://scenes/Support.tscn").instantiate())
	await tree.process_frame
	assert_eq(support.get_node("Art").kind, "support", "kind")
	support.lifetime = 1.0
	support._process(0.0)
	assert_eq(support.get_node("Art").art.pose, 0.0, "fresh")
	support.lifetime = 0.25
	support._process(0.0)
	assert_eq(support.get_node("Art").art.pose, 0.75, "worn")

func test_lamp_and_anchor_scenes_draw_their_art() -> void:
	var lamp := await _art_of("res://scenes/Lamp.tscn", "lamp")
	assert_true(lamp.get_node_or_null("Sprite") == null, "no old lamp sprite")
	var anchor := await _art_of("res://scenes/Anchor.tscn", "anchor")
	assert_true(anchor.get_node_or_null("Sprite") == null, "no old anchor sprite")
