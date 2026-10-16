extends TestCase

## The walking bot on the real player: pits it can and cannot climb out of, and the connectors
## and spine stretches the generator promises are walkable (tile data alone cannot say so).

const PlayerScene := preload("res://scenes/Player.tscn")
const MineScene := preload("res://scenes/Mine.tscn")

const FLOOR_ROW := 40 # the standing row is FLOOR_ROW - 1

func _release() -> void:
	TouchKeys.release_all(WalkBot.SOURCE)

## A level floor with a two-wide pit `depth` tiles deep at x 20 and 21. Returns the player.
func _pit_arena(depth: int, start_in_pit: bool) -> Array:
	var mine: MineGrid = add(MineScene.instantiate())
	for x in range(10, 41):
		for y in range(FLOOR_ROW - 10, FLOOR_ROW):
			mine.set_cell(0, Vector2i(x, y), -1)
		for y in range(FLOOR_ROW, FLOOR_ROW + 6):
			mine.fill_cell(Vector2i(x, y))
	for x in [20, 21]:
		for y in range(FLOOR_ROW, FLOOR_ROW + depth):
			mine.set_cell(0, Vector2i(x, y), -1)
	var player: Player = add(PlayerScene.instantiate())
	player.mine = mine
	player.invincible = true
	var start := Vector2i(20, FLOOR_ROW + depth - 1) if start_in_pit else Vector2i(12, FLOOR_ROW - 1)
	player.global_position = mine.cell_to_world(start)
	await physics_frames(10)
	return [mine, player]

func test_the_bot_notices_a_wall() -> void:
	var arena := await _pit_arena(4, true)
	var mine: MineGrid = arena[0]
	var player: Player = arena[1]
	var result := await WalkBot.walk_to(tree, player, mine, Vector2i(27, FLOOR_ROW - 1), 8.0, WalkBot.KeyDriver.new())
	assert_true(not result["reached"], "a four-deep pit is not climbed out of")
	assert_true(result["stuck_at"].y >= FLOOR_ROW, "stuck inside the pit: %s" % str(result["stuck_at"]))
	assert_true(result["jumps"] > 0, "it tried jumping")
	for key in [KEY_A, KEY_D, KEY_W]:
		assert_true(not TouchKeys.is_down(key), "key %d released" % key)

func _climbs_out_of(depth: int) -> void:
	var arena := await _pit_arena(depth, true)
	var result := await WalkBot.walk_to(tree, arena[1], arena[0], Vector2i(27, FLOOR_ROW - 1), 8.0, WalkBot.KeyDriver.new())
	assert_true(result["reached"], "a %d-deep pit is climbed out of: %s" % [depth, str(result)])
	_release()

## One test per depth: two arenas alive in one test would share a physics space.
func test_a_two_deep_pit_can_be_climbed_out_of() -> void:
	await _climbs_out_of(2)

func test_a_three_deep_pit_can_be_climbed_out_of() -> void:
	await _climbs_out_of(3)

func test_the_bot_stops_when_it_arrives() -> void:
	var arena := await _pit_arena(2, false)
	var result := await WalkBot.walk_to(tree, arena[1], arena[0], Vector2i(18, FLOOR_ROW - 1), 8.0, WalkBot.KeyDriver.new())
	assert_true(result["reached"], "arrived: %s" % str(result))
	assert_true(result["seconds"] < 3.0, "in good time: %s" % str(result))
	assert_eq(result["jumps"], 0, "no jumping on a flat floor")

# --- real mines ---------------------------------------------------------------------------

func _main(mine_seed: int) -> Main:
	Progress.path_override = TEST_SAVE_PATH
	var fresh := Progress.new()
	fresh.save_path = TEST_SAVE_PATH
	fresh.save()
	HUD.title_seen = true
	MineGrid.next_seed = mine_seed
	var main: Main = add(load("res://scenes/Main.tscn").instantiate())
	main.mine.decay_multiplier = 1000.0
	main.player.invincible = true
	main.player.light.burn_rate = 0.0
	await physics_frames(10)
	return main

func _done() -> void:
	_release()
	Progress.path_override = ""

func _check_connector_walk(mine_seed: int, use_pad: bool) -> void:
	var main := await _main(mine_seed)
	assert_true(not main.mine.connectors.is_empty(), "seed %d has a connector" % mine_seed)
	var connector: Connector = main.mine.connectors[0]
	var driver = WalkBot.PadDriver.new(main.gamepad_controls) if use_pad else WalkBot.KeyDriver.new()
	var result := await WalkBot.walk_connector(tree, main.player, main.mine, connector, driver)
	var label := "seed %d layer %d, %d tiles" % [mine_seed, connector.layer, connector.cells.size()]
	assert_true(result["out"]["reached"], "%s: down to the room: %s" % [label, str(result["out"])])
	assert_true(result["back"]["reached"], "%s: back up to the spine: %s" % [label, str(result["back"])])
	_done()

## One test per seed: two Mains alive in one test would share a physics space.
func test_the_bot_walks_a_connector_down_and_back_seed_1001() -> void:
	await _check_connector_walk(1001, false)

func test_the_bot_walks_a_connector_down_and_back_seed_2() -> void:
	await _check_connector_walk(2, false)

func test_the_bot_walks_a_connector_down_and_back_seed_4() -> void:
	await _check_connector_walk(4, false)

func test_the_bot_walks_a_connector_with_the_pad() -> void:
	await _check_connector_walk(1001, true)

func test_the_bot_walks_the_open_stretch_of_a_spine() -> void:
	var main := await _main(1001)
	var spine: Drift = null
	for drift in main.mine.drifts:
		if drift.layer == 4 and not drift.from_shaft:
			spine = drift
	assert_true(spine != null, "a layer 4 spine")
	if spine == null:
		_done()
		return
	var first_x: int = spine.x0 + spine.side * 2
	var last_x: int = spine.x1 - spine.side * 2
	for box in spine.collapses:
		var near: int = box.position.x if spine.side > 0 else box.end.x - 1
		if (near - spine.x0) * spine.side < (last_x - spine.x0) * spine.side + 2 * spine.side:
			last_x = near - spine.side * 2
	var first := Vector2i(first_x, spine.row)
	var last := Vector2i(last_x, spine.row)
	main.player.global_position = main.mine.cell_to_world(first)
	main.player.velocity = Vector2.ZERO
	await physics_frames(5)
	var budget := WalkBot.budget_seconds(absi(last_x - first_x))
	var out := await WalkBot.walk_to(tree, main.player, main.mine, last, budget, WalkBot.KeyDriver.new())
	assert_true(out["reached"], "out along the spine: %s" % str(out))
	var back := await WalkBot.walk_to(tree, main.player, main.mine, first, budget, WalkBot.KeyDriver.new())
	assert_true(back["reached"], "and back: %s" % str(back))
	_done()
