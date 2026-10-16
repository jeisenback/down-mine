extends TestCase

## Movement measured on the real Player, on hand-built walled and roofed arenas (the numbers
## the tuning rests on, not arithmetic on constants).
##
## Measured here, and what would fail each: jump height (gravity scaled elsewhere, a changed
## jump cut or velocity), walking speed and stopping time (a changed acceleration or a drag
## applied elsewhere), the dig descent rate (the dig hold removed or its cap changed), fall
## damage by landing speed (the safe fall or a speed cap changed).
## Measured elsewhere: the one-tile step-up, the jump cut and the mantle reach
## (test_world.test_step_up_climbs_one_tile_but_not_two, test_releasing_jump_cuts_it_short,
## test_mantle_pulls_up_a_ledge_within_reach) and the pit climb-out (test_walk.gd).
## Still arithmetic on the constants: test_world.test_a_plain_jump_clears_a_two_tile_ledge and
## test_a_jump_and_mantle_reach_three_tiles_but_not_four.

const PlayerScene := preload("res://scenes/Player.tscn")
const MineScene := preload("res://scenes/Mine.tscn")

const SOURCE := "test"
const ORIGIN := Vector2i(10, 30)

func _release() -> void:
	TouchKeys.release_all(SOURCE)

## Fills a box of rock one tile wider than the arena all round, clears width x height inside it,
## and returns the standing cell at the left end of the floor. The roof is the top of the box.
func _arena(mine: MineGrid, width: int, height: int) -> Vector2i:
	for x in range(ORIGIN.x - 1, ORIGIN.x + width + 1):
		for y in range(ORIGIN.y - 1, ORIGIN.y + height + 1):
			mine.fill_cell(Vector2i(x, y))
	for x in range(ORIGIN.x, ORIGIN.x + width):
		for y in range(ORIGIN.y, ORIGIN.y + height):
			mine.set_cell(0, Vector2i(x, y), -1)
	return Vector2i(ORIGIN.x, ORIGIN.y + height - 1)

func _player(mine: MineGrid, cell: Vector2i, invincible := false) -> Player:
	var player: Player = add(PlayerScene.instantiate())
	player.mine = mine
	player.invincible = invincible
	player.light.burn_rate = 0.0
	player.global_position = mine.cell_to_world(cell)
	return player

func test_a_jump_peaks_at_the_tuned_height() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var stand := _arena(mine, 6, 12)
	var player := _player(mine, stand + Vector2i(2, 0))
	await physics_frames(15)
	var floor_y := player.global_position.y
	var top := floor_y
	TouchKeys.set_key(KEY_W, true, SOURCE)
	for i in range(60):
		await physics_frames(1)
		top = minf(top, player.global_position.y)
	_release()
	var rise := floor_y - top
	var expected := 40.8 # px: 200 px/s up at 490 px/s squared. Literal on purpose: retuning must change this test.
	assert_true(absf(rise - expected) <= 3.0, "jump rose %.1f px, expected %.1f +/- 3" % [rise, expected])

func test_walking_reaches_full_speed_and_stops_quickly() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var stand := _arena(mine, 40, 10)
	var player := _player(mine, stand + Vector2i(1, 0))
	await physics_frames(15)
	TouchKeys.set_key(KEY_D, true, SOURCE)
	await physics_frames(40)
	var x0 := player.global_position.x
	await physics_frames(30)
	var speed := (player.global_position.x - x0) / 0.5
	_release()
	assert_true(absf(speed - 120.0) <= 6.0, "walked at %.1f px/s, expected 120 +/- 5%%" % speed)
	await physics_frames(12) # 0.2 s
	assert_true(absf(player.velocity.x) < 5.0, "still moving at %.1f px/s 0.2 s after letting go" % player.velocity.x)

func test_digging_straight_down_descends_at_the_measured_rate() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	_arena(mine, 3, 2)
	for x in range(ORIGIN.x - 1, ORIGIN.x + 4): # rock 14 deep under the pocket
		for y in range(ORIGIN.y + 2, ORIGIN.y + 16):
			mine.fill_cell(Vector2i(x, y))
	var player := _player(mine, Vector2i(ORIGIN.x + 1, ORIGIN.y + 1))
	await physics_frames(15)
	TouchKeys.set_key(KEY_S, true, SOURCE)
	await physics_frames(20)
	var y0 := player.global_position.y
	await physics_frames(45)
	var rate := (player.global_position.y - y0) / 0.75 / MineGrid.TILE_SIZE
	_release()
	var expected := 5.4 # tiles per second, the pace the dig cooldown allows
	assert_true(absf(rate - expected) <= expected * 0.15, "dug down at %.2f tiles/s, expected %.2f +/- 15%%" % [rate, expected])

func test_falls_hurt_by_measured_landing_speed() -> void:
	var cases := {6: 0, 8: 1, 12: 2, 20: 2} # the 20 tile fall is capped at MAX_FALL_DAMAGE, 2
	for drop in cases:
		var mine: MineGrid = add(MineScene.instantiate())
		_arena(mine, 3, drop + 1)
		var player := _player(mine, Vector2i(ORIGIN.x + 1, ORIGIN.y))
		player.health = Player.MAX_HEALTH
		await physics_frames(drop * 6 + 40)
		var lost := Player.MAX_HEALTH - player.health
		assert_eq(lost, cases[drop], "health lost falling %d tiles" % drop)
		mine.queue_free()
		player.queue_free()
		await physics_frames(2)
