extends TestCase

## Scene rules: base repair, the Stalker's strike rule, Burrowers vs
## walls, and mine decay sparing lit ground. Builds only the nodes each
## test needs (never Main, so no save file is read).

const PlayerScene := preload("res://scenes/Player.tscn")
const RunBaseScene := preload("res://scenes/RunBase.tscn")
const StalkerScene := preload("res://scenes/Stalker.tscn")
const MineScene := preload("res://scenes/Mine.tscn")
const BurrowerScene := preload("res://scenes/Burrower.tscn")

func _still_player(pos: Vector2, fuel_fraction: float) -> Player:
	var player: Player = add(PlayerScene.instantiate())
	player.set_physics_process(false) # no input, no gravity
	player.global_position = pos
	player.health = 999
	player.light.burn_rate = 0.0
	player.light.fuel = player.light.max_fuel * fuel_fraction
	return player

func _base(pos: Vector2) -> RunBase:
	var base: RunBase = add(RunBaseScene.instantiate())
	base.global_position = pos
	return base

func test_repair_needs_ore_and_takes_time() -> void:
	var base := _base(Vector2.ZERO)
	base.take_hit(2)
	assert_true(not base.tick_repair(5.0, base.repair_cost() - 1), "can't repair without the ore")
	assert_eq(base.repair_progress, 0.0, "no progress when unaffordable")
	assert_true(not base.tick_repair(RunBase.REPAIR_TIME - 0.1, 100), "not done early")
	assert_true(base.tick_repair(0.2, 100), "done after REPAIR_TIME")
	assert_eq(base.health, 2, "one point restored")

func test_stalker_held_off_by_healthy_lantern() -> void:
	var player := _still_player(Vector2(1000, 1000), 0.5)
	var stalker: Stalker = add(StalkerScene.instantiate())
	stalker.player = player
	stalker.run_base = _base(Vector2(-5000, -5000))
	stalker.global_position = player.global_position + Vector2(90, 0)
	await physics_frames(300)
	assert_eq(player.health, 999, "no hits at 50% fuel")

func test_stalker_strikes_on_low_light() -> void:
	var player := _still_player(Vector2(1000, 1000), 0.1)
	var stalker: Stalker = add(StalkerScene.instantiate())
	stalker.player = player
	stalker.run_base = _base(Vector2(-5000, -5000))
	stalker.global_position = player.global_position + Vector2(90, 0)
	await physics_frames(300)
	assert_true(player.health < 999, "hit at 10% fuel")

func test_stalker_never_strikes_inside_base_light() -> void:
	var player := _still_player(Vector2(1000, 1000), 0.1)
	var stalker: Stalker = add(StalkerScene.instantiate())
	stalker.player = player
	stalker.run_base = _base(player.global_position)
	stalker.global_position = player.global_position + Vector2(250, 0)
	await physics_frames(300)
	assert_eq(player.health, 999, "base light is a refuge")

func test_burrower_must_chew_through_walls() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var player := _still_player(Vector2(-5000, -5000), 1.0)
	var base := _base(mine.cell_to_world(Vector2i(40, 100)))
	var wall_cell := Vector2i(40, 104)
	for y in range(101, 112): # plain rock path below the base
		mine.set_cell(0, Vector2i(40, y), mine.source_id, Vector2i(1, 0))
	mine.reinforce(wall_cell)
	var burrower: Burrower = add(BurrowerScene.instantiate())
	burrower.mine = mine
	burrower.player = player
	burrower.target = base
	burrower.global_position = mine.cell_to_world(Vector2i(40, 106))
	await physics_frames(90) # reaches the wall, then starts chewing
	assert_true(mine.is_wall(wall_cell), "wall still standing after 1.5s")
	assert_true(mine.world_to_cell(burrower.global_position).y > wall_cell.y, "held below the wall")
	await physics_frames(150) # WALL_CHEW_TIME is 2.5s
	assert_true(not mine.is_wall(wall_cell), "chewed through")

func test_decay_collapses_dark_tunnels_but_spares_lit_ones() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var lit_cell := Vector2i(40, 150)
	var dark_cell := Vector2i(10, 250)
	for cell in [lit_cell, dark_cell]:
		mine.set_cell(0, cell, mine.source_id, Vector2i(1, 0))
	mine.dig_cells([lit_cell, dark_cell]) # player digs are what collapse
	_still_player(mine.cell_to_world(lit_cell), 1.0)
	for i in range(20):
		mine.tick_decay(10.0, mine.cell_to_world(lit_cell)) # one decay tick per call
	assert_true(mine.is_solid(dark_cell), "dark tunnel collapsed")
	assert_true(not mine.is_solid(lit_cell), "lit tunnel spared")
