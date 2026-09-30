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

func test_quirks_apply_their_effects() -> void:
	var player := _still_player(Vector2.ZERO, 1.0)
	var base := _base(Vector2(-500, 0))
	var meter: NoiseMeter = add(NoiseMeter.new())
	var p := Progress.new()
	p.save_path = TEST_SAVE_PATH
	p.roster = [
		{"name": "A", "type": "light", "runs": 0, "quirk": "night_eyes"},
		{"name": "B", "type": "light", "runs": 0, "quirk": "deep_lungs"},
		{"name": "C", "type": "light", "runs": 0, "quirk": "sure_footed"},
		{"name": "D", "type": "light", "runs": 0, "quirk": "hums"},
	]
	p.crew_names = ["A", "B", "C", "D"]
	var radius_min := player.light.radius_min
	var max_fuel := player.light.max_fuel
	p.apply_to(player, meter, base)
	assert_eq(player.light.radius_min, radius_min + Progress.NIGHT_EYES_MIN_RADIUS_BONUS, "night eyes")
	assert_eq(player.light.max_fuel, max_fuel + Progress.DEEP_LUNGS_FUEL, "deep lungs")
	assert_eq(player.safe_fall_tiles, Player.SAFE_FALL_TILES + Progress.SURE_FOOTED_TILES, "sure-footed")
	assert_true(meter.noise_multiplier > 1.0, "hums makes you louder")

func test_ladders_outclimb_and_outlast_ropes_with_traversal_bonus() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var player := _still_player(mine.cell_to_world(Vector2i(40, 150)), 1.0)
	player.mine = mine
	var p := Progress.new()
	p.save_path = TEST_SAVE_PATH
	p.roster = [{"name": "Cole", "type": "traversal", "runs": 0}]
	p.crew_names = ["Cole"]
	p.levels = {"ladders": 1}
	p.apply_to(player, add(NoiseMeter.new()), _base(Vector2(-500, 0)))
	player._place_rope()
	player._place_ladder()
	var tools := mine.get_children().filter(func(c): return c is Rope)
	var rope: Rope = tools[0]
	var ladder: Rope = tools[1]
	assert_eq(rope.life_seconds, Player.ROPE_LIFE_SECONDS * 1.5, "rope life +50%")
	assert_eq(ladder.life_seconds, Player.LADDER_LIFE_SECONDS * 1.5, "ladder life +50%")
	assert_eq(ladder.climb_speed, Player.LADDER_CLIMB_SPEED * 1.25, "ladder climb +25%")
	assert_true(ladder.climb_speed > rope.climb_speed, "ladders climb faster than ropes")
	assert_eq(player.ladders_left, Player.LADDERS_PER_RUN - 1, "a ladder was used up")

func test_locked_tools_are_unavailable_until_bought() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var player := _still_player(mine.cell_to_world(Vector2i(40, 150)), 1.0)
	player.mine = mine
	var p := Progress.new()
	p.save_path = TEST_SAVE_PATH
	p.apply_to(player, add(NoiseMeter.new()), _base(Vector2(-500, 0)))
	assert_eq(player.ladders_left, 0, "no ladders before the unlock")
	assert_eq(player.anchors_left, 0, "no anchors before the unlock")
	player._place_ladder()
	player._place_anchor()
	assert_true(mine.get_children().filter(func(c): return c is Rope or c is Anchor).is_empty(), "nothing placed while locked")
	var unlocked := _still_player(Vector2.ZERO, 1.0)
	p.levels = {"ladders": 1, "anchors": 1}
	p.apply_to(unlocked, add(NoiseMeter.new()), _base(Vector2(-500, 0)))
	assert_eq(unlocked.ladders_left, Player.LADDERS_PER_RUN, "ladders once unlocked")
	assert_eq(unlocked.anchors_left, Player.ANCHORS_PER_RUN, "anchors once unlocked")

func test_stone_layer_has_gas_pockets() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var gas_rows: Array = []
	for x in range(MineGrid.GRID_WIDTH):
		for y in range(MineGrid.GRID_HEIGHT):
			if mine.is_gas(Vector2i(x, y)):
				gas_rows.append(y)
	assert_eq(gas_rows.size(), MineGrid.GAS_POCKET_COUNT, "all gas pockets placed")
	assert_true(gas_rows.all(func(y): return mine.layer_index_at_world(mine.cell_to_world(Vector2i(0, y))) == MineGrid.GAS_LAYER), "only in Stone")

func test_digging_gas_releases_a_cloud_that_hurts_inside_it() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var released: Array = []
	mine.gas_released.connect(func(pos): released.append(pos))
	var gas_cell := Vector2i(40, 150)
	var plain_cell := Vector2i(41, 150)
	mine.set_cell(0, gas_cell, mine.source_id, MineGrid.GAS_ATLAS_COORDS)
	mine.set_cell(0, plain_cell, mine.source_id, Vector2i(1, 0))
	mine.dig_cells([plain_cell])
	assert_true(released.is_empty(), "plain rock releases nothing")
	mine.dig_cells([gas_cell], false)
	assert_true(released.is_empty(), "enemy tunnelling doesn't release gas")
	mine.set_cell(0, gas_cell, mine.source_id, MineGrid.GAS_ATLAS_COORDS)
	mine.dig_cells([gas_cell])
	assert_eq(released.size(), 1, "the player digging gas releases it")
	var inside := _still_player(released[0], 1.0)
	var outside := _still_player(released[0] + Vector2(GasCloud.RADIUS * 2, 0), 1.0)
	for target in [inside, outside]:
		var cloud: GasCloud = add(preload("res://scenes/GasCloud.tscn").instantiate())
		cloud.player = target
		cloud.global_position = released[0]
	await physics_frames(int(60 * (GasCloud.DAMAGE_INTERVAL + 0.2)))
	assert_true(inside.health < 999, "standing in the cloud hurts")
	assert_eq(outside.health, 999, "outside the cloud is safe")

func test_support_stops_collapse_nearby() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var near := Vector2i(10, 250)
	var far := Vector2i(30, 250)
	for cell in [near, far]:
		mine.set_cell(0, cell, mine.source_id, Vector2i(2, 0))
	mine.dig_cells([near, far])
	var support: Support = add(preload("res://scenes/Support.tscn").instantiate())
	support.global_position = mine.cell_to_world(near + Vector2i(1, 0))
	# Player well away from both: decay also crumbles floors within 20
	# tiles of the player, which could reopen the collapsed far tunnel.
	for i in range(20):
		mine.tick_decay(10.0, mine.cell_to_world(Vector2i(60, 250)))
	assert_true(not mine.is_solid(near), "supported tunnel stays open")
	assert_true(mine.is_solid(far), "unsupported dark tunnel collapsed")

func test_beacon_widens_and_burns_base_light() -> void:
	var base := _base(Vector2.ZERO)
	var radius := base.light.radius_max
	var burn := base.light.burn_rate
	base.build_beacon()
	assert_eq(base.light.radius_max, radius * RunBase.BEACON_RADIUS_MULTIPLIER, "wider refuge")
	assert_eq(base.light.burn_rate, burn * RunBase.BEACON_BURN_MULTIPLIER, "burns faster")

func test_deep_rock_decays_faster() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var stone := mine.cell_to_world(Vector2i(40, 150))
	var deep := mine.cell_to_world(Vector2i(40, 280))
	assert_eq(mine.layer_index_at_world(deep), MineGrid.UNSTABLE_LAYER, "row 280 is deep rock")
	assert_eq(mine.decay_interval(deep), mine.decay_interval(stone) * MineGrid.UNSTABLE_DECAY_MULTIPLIER, "deep decay interval halved")

func _open_box(mine: MineGrid, from: Vector2i, to: Vector2i) -> void:
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			mine.set_cell(0, Vector2i(x, y), -1)
	for x in range(from.x, to.x + 1): # a floor under the box
		mine.set_cell(0, Vector2i(x, to.y + 1), mine.source_id, Vector2i(1, 0))

func test_grapple_pulls_to_anchor_in_sight() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	_open_box(mine, Vector2i(30, 100), Vector2i(45, 115))
	var player: Player = add(PlayerScene.instantiate())
	player.mine = mine
	player.global_position = mine.cell_to_world(Vector2i(32, 115))
	var anchor: Anchor = add(Player.AnchorScene.instantiate())
	anchor.global_position = mine.cell_to_world(Vector2i(38, 109)) # mid-air, ~8.5 tiles up-right
	await physics_frames(5)
	player._try_fire_grapple()
	var closest := 9999.0
	for i in range(60):
		await physics_frames(1)
		closest = min(closest, player.global_position.distance_to(anchor.global_position))
	assert_true(closest < 8.0, "pulled to the anchor (closest %.1f px)" % closest)

func test_grapple_reaches_anchor_on_a_ledge_from_below() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	_open_box(mine, Vector2i(30, 100), Vector2i(45, 115))
	for x in range(42, 45): # a high shelf; the anchor stands on it
		mine.set_cell(0, Vector2i(x, 108), mine.source_id, Vector2i(1, 0))
	var player: Player = add(PlayerScene.instantiate())
	player.mine = mine
	player.global_position = mine.cell_to_world(Vector2i(38, 115))
	var anchor: Anchor = add(Player.AnchorScene.instantiate())
	anchor.global_position = mine.cell_to_world(Vector2i(43, 107))
	await physics_frames(5)
	player._try_fire_grapple()
	await physics_frames(60)
	assert_true(player.global_position.distance_to(anchor.global_position) < 8.0,
		"pulled up over the shelf's lip onto it (%.0f px away)" % player.global_position.distance_to(anchor.global_position))
	assert_true(player.is_on_floor(), "standing on the shelf")

func test_grapple_ignores_anchor_behind_rock() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	_open_box(mine, Vector2i(30, 100), Vector2i(45, 115))
	for y in range(100, 116): # a rock wall between player and anchor
		mine.set_cell(0, Vector2i(35, y), mine.source_id, Vector2i(1, 0))
	var player := _still_player(mine.cell_to_world(Vector2i(32, 115)), 1.0)
	player.mine = mine
	var anchor: Anchor = add(Player.AnchorScene.instantiate())
	anchor.global_position = mine.cell_to_world(Vector2i(38, 109))
	assert_eq(player._anchor_in_reach(), null, "no line of sight, no anchor pull")

func test_sign_trail_spreads_from_far_to_near() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var center := Vector2i(40, 150)
	# A fixed candidate set - one floor cell per tile of distance - so the
	# test doesn't depend on how many cave floors the random map put here
	# (a sparse map can't offer a cell near every target distance).
	var spare: Array = []
	for d in range(1, 21):
		spare.append(center + Vector2i(d, 0))
	mine._spare_floor_cells = spare
	var cells := mine.take_trail_cells(center, 5, 2.0, 18.0)
	assert_eq(cells.size(), 5, "five signs placed")
	var distances := cells.map(func(c): return Vector2(c - center).length())
	for d in distances:
		assert_true(d >= 2.0 and d <= 18.0, "sign within 2-18 tiles (was %.1f)" % d)
	for i in range(distances.size() - 1):
		assert_true(distances[i] >= distances[i + 1], "ordered far to near")
	assert_true(distances[0] > 12.0, "trail starts far out (was %.1f)" % distances[0])
	assert_true(distances[-1] < 6.0, "trail ends close to the miner (was %.1f)" % distances[-1])
	var again := mine.take_trail_cells(center, 5, 2.0, 18.0)
	assert_true(again.all(func(c): return not c in cells), "cells are claimed, never reused")

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

func test_mine_carves_event_rooms() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	assert_eq(mine.event_rooms.filter(func(r): return r.kind == "camp").size(), 3, "a camp per layer")
	var lifts := mine.event_rooms.filter(func(r): return r.kind == "lift")
	assert_eq(lifts.size(), 1, "one lift")
	assert_eq(mine.event_rooms.filter(func(r): return r.kind == "outpost").size(), 1, "one outpost")
	assert_eq(mine.event_rooms.filter(func(r): return r.kind == "gallery").size(), 1, "one gallery")
	assert_eq(mine.event_rooms.filter(func(r): return r.kind == "nest").size(), 1, "one nest")
	var hearts := mine.event_rooms.filter(func(r): return r.kind == "heart")
	assert_eq(hearts.size(), 1, "one Heart")
	assert_true(hearts[0].cell.y >= MineGrid.GRID_HEIGHT - 20, "Heart at the bottom")
	assert_true(mine._layer_index_for_row(lifts[0].cell.y) >= 1, "lift below topsoil")
	for room in mine.event_rooms:
		assert_true(not mine.is_solid(room.cell), "room is open")
		assert_true(mine.is_solid(room.cell + Vector2i.DOWN), "room has a floor")

func test_vault_is_sealed_but_for_its_door() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var vaults := mine.event_rooms.filter(func(r): return r.kind == "vault")
	assert_eq(vaults.size(), 1, "one vault")
	var vault: Dictionary = vaults[0]
	assert_eq(mine._layer_index_for_row(vault.cell.y), 2, "vault in deep rock")
	var door: Vector2i = vault.door
	assert_true(not mine.is_solid(door) and not mine.is_solid(door + Vector2i.UP), "doorway open")
	assert_true(mine.is_indestructible(door + Vector2i.DOWN), "bedrock under the door")
	assert_true(mine.is_indestructible(vault.cell + Vector2i.DOWN), "bedrock floor")
	var right := door.x + MineGrid.ROOM_SIZE.x + 1
	assert_true(mine.is_indestructible(Vector2i(right, door.y)), "bedrock far wall")
	assert_true(mine.is_indestructible(Vector2i(vault.cell.x, door.y - MineGrid.ROOM_SIZE.y)), "bedrock ceiling")

## Clears a patch of mine and lays a floor, a 1-tile bump and a 2-tile
## wall; returns the floor-standing cell left of the bump.
func _step_course(mine: MineGrid) -> Vector2i:
	var origin := Vector2i(10, 30)
	for x in range(origin.x, origin.x + 20):
		for y in range(origin.y, origin.y + 8):
			mine.set_cell(0, Vector2i(x, y), -1)
	for x in range(origin.x, origin.x + 20):
		mine.fill_cell(Vector2i(x, origin.y + 8))
	mine.fill_cell(Vector2i(origin.x + 6, origin.y + 7))  # 1-tile bump
	mine.fill_cell(Vector2i(origin.x + 12, origin.y + 7)) # 2-tile wall
	mine.fill_cell(Vector2i(origin.x + 12, origin.y + 6))
	return Vector2i(origin.x + 5, origin.y + 7)

func test_step_up_climbs_one_tile_but_not_two() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var start := _step_course(mine)
	var player: Player = add(PlayerScene.instantiate())
	player.mine = mine
	player.global_position = mine.cell_to_world(start)
	await physics_frames(10)
	var floor_y := player.global_position.y
	player._try_step_up(1.0)
	assert_true(player.global_position.y < floor_y - 15.0, "stepped onto the bump")
	player.global_position = mine.cell_to_world(start + Vector2i(6, 0))
	await physics_frames(10)
	var before := player.global_position
	player._try_step_up(1.0)
	assert_eq(player.global_position, before, "2-tile wall still blocks")

func test_releasing_jump_cuts_it_short() -> void:
	var player: Player = add(PlayerScene.instantiate())
	player.set_physics_process(false)
	player.velocity.y = Player.JUMP_VELOCITY
	player._jump_rising = true
	player._apply_jump_cut(true)
	assert_eq(player.velocity.y, Player.JUMP_VELOCITY, "held: full jump")
	player._apply_jump_cut(false)
	assert_eq(player.velocity.y, Player.JUMP_VELOCITY * Player.JUMP_CUT, "released: cut")
	player._apply_jump_cut(false)
	assert_eq(player.velocity.y, Player.JUMP_VELOCITY * Player.JUMP_CUT, "cut only once")

func test_mantle_pulls_up_a_ledge_within_reach() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var start := _step_course(mine)
	var wall := start + Vector2i(7, -1) # upper cell of the 2-tile wall
	var ledge_top := mine.cell_to_world(wall).y - MineGrid.TILE_SIZE / 2.0
	var wall_left := mine.cell_to_world(wall).x - MineGrid.TILE_SIZE / 2.0
	var player: Player = add(PlayerScene.instantiate())
	player.set_physics_process(false) # placed by hand, no gravity
	player.mine = mine
	await physics_frames(2) # tile collisions apply on the next physics frame
	var half := Vector2(6, 7) # collision box half-size
	player.global_position = Vector2(wall_left - half.x - 0.5, ledge_top - half.y + 10)
	assert_true(player._try_mantle(1.0), "top 10 px above feet: mantles")
	assert_true(player.global_position.y + half.y <= ledge_top + 0.5, "feet up on the ledge")
	player.global_position = Vector2(wall_left - half.x - 0.5, ledge_top - half.y + 20)
	assert_true(not player._try_mantle(1.0), "top 20 px above feet: out of reach")

## Every tile, event room and pickup position, to compare two mines.
func _mine_fingerprint(mine: MineGrid) -> Array:
	var tiles := PackedInt32Array()
	for x in range(MineGrid.GRID_WIDTH):
		for y in range(MineGrid.GRID_HEIGHT):
			var atlas := mine.get_cell_atlas_coords(0, Vector2i(x, y))
			tiles.append(atlas.x * 10 + atlas.y)
	var pickups := mine.get_children().map(func(n): return n.position)
	return [tiles, mine.event_rooms, pickups]

func test_same_seed_builds_the_same_mine() -> void:
	MineGrid.next_seed = 4242
	var a: MineGrid = add(MineScene.instantiate())
	MineGrid.next_seed = 4242
	var b: MineGrid = add(MineScene.instantiate())
	var c: MineGrid = add(MineScene.instantiate()) # random seed
	assert_eq(a.mine_seed, 4242, "seed used")
	assert_true(_mine_fingerprint(a) == _mine_fingerprint(b), "same seed, same mine")
	assert_true(_mine_fingerprint(a) != _mine_fingerprint(c), "other seed, other mine")

func test_digging_down_centres_over_the_hole() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var start := _step_course(mine)
	var player: Player = add(PlayerScene.instantiate())
	player.mine = mine
	var column_x := mine.cell_to_world(start).x
	player.global_position = mine.cell_to_world(start) + Vector2(-7, 0) # off-centre, as at spawn
	await physics_frames(10)
	for i in range(10):
		player._dig_straight_down()
		await physics_frames(1)
	assert_true(absf(player.global_position.x - column_x) < 0.5, "slid over the dug column")
	await physics_frames(20)
	assert_true(player.global_position.y > mine.cell_to_world(start).y + 8, "fell into the hole")

func test_nonstop_noise_keeps_summoning() -> void:
	var meter := NoiseMeter.new()
	add(meter)
	var count := [0]
	meter.threshold_reached.connect(func(): count[0] += 1)
	for i in range(10):
		meter.add_noise(60.0) # nonstop: never dips below the threshold between hits
	assert_eq(count[0], 5, "every 100 noise summons again")
	assert_true(meter.noise < meter.threshold, "meter empties when it fills")

func test_stalker_hunts_through_rock_and_backs_off_after_a_strike() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var player := _still_player(mine.cell_to_world(Vector2i(40, 150)), 0.1)
	var stalker: Stalker = add(StalkerScene.instantiate())
	stalker.player = player
	stalker.run_base = _base(Vector2(-5000, -5000))
	stalker.global_position = player.global_position + Vector2(400, 0) # far, through solid Stone
	var start := stalker.global_position.distance_to(player.global_position)
	await physics_frames(120)
	assert_true(stalker.global_position.distance_to(player.global_position) < start - 30.0, "hunts from out of range")
	stalker.global_position = player.global_position + Vector2(10, 0)
	await physics_frames(5)
	assert_eq(player.health, 998, "struck once")
	await physics_frames(60)
	assert_true(stalker.global_position.distance_to(player.global_position) > 30.0, "backs off after striking")
	assert_eq(player.health, 998, "no follow-up hit while backing off")

func test_rope_throws_up_to_the_ceiling_and_drops_over_an_edge() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var start := _step_course(mine) # floor-standing cell, open room 7 tall above
	var player: Player = add(PlayerScene.instantiate())
	player.mine = mine
	player.set_physics_process(false)
	player.global_position = mine.cell_to_world(start)
	await physics_frames(2)
	player._place_rope()
	var rope: Node2D = mine.get_children().filter(func(n): return n is Rope)[-1]
	var top := mine.world_to_cell(rope.global_position + Vector2(0, 1))
	assert_eq(top, start + Vector2i(0, -(Player.ROPE_LENGTH_TILES - 1)), "thrown up 5 tiles in open air")
	# a drop in front: clear the floor ahead, face it, hold S
	mine.set_cell(0, start + Vector2i(-1, 1), -1) # (the tile to the right is the bump)
	mine.set_cell(0, start + Vector2i(-1, 2), -1)
	player.facing = -1
	player._place_rope(true)
	rope = mine.get_children().filter(func(n): return n is Rope)[-1]
	assert_eq(mine.world_to_cell(rope.global_position + Vector2(0, 1)), start + Vector2i(-1, 0), "S+R hangs over the edge")
