extends TestCase

## Visual upgrades (M89): soft shading on exposed rock edges, a vignette and drifting dust in the
## lantern light. All cosmetic: none of it touches physics, light reach or the layout.

const MineScene := preload("res://scenes/Mine.tscn")

# --- edge shading -------------------------------------------------------------------------

func test_the_mask_has_one_bit_per_exposed_side() -> void:
	assert_eq(MineShading.mask(true, false, false, false), 1, "north")
	assert_eq(MineShading.mask(false, true, false, false), 2, "east")
	assert_eq(MineShading.mask(false, false, true, false), 4, "south")
	assert_eq(MineShading.mask(false, false, false, true), 8, "west")
	assert_eq(MineShading.mask(true, true, true, true), 15, "all four")
	assert_eq(MineShading.mask(false, false, false, false), 0, "none")

func test_a_shade_tile_marks_only_its_exposed_sides() -> void:
	var size := MineGrid.TILE_SIZE
	var top := MineShading.shade_color(MineShading.NORTH, size / 2, 0)
	assert_true(top.a > 0.1 and top.v > 0.5, "an exposed top edge is a faint highlight (%s)" % str(top))
	var ceiling := MineShading.shade_color(MineShading.SOUTH, size / 2, size - 1)
	assert_true(ceiling.a > 0.2 and ceiling.v < 0.1, "an exposed underside is a shadow (%s)" % str(ceiling))
	assert_eq(MineShading.shade_color(MineShading.NORTH, size / 2, size - 1).a, 0.0, "the unexposed side is clear")
	assert_eq(MineShading.shade_color(MineShading.NORTH, size / 2, size / 2).a, 0.0, "the middle of a tile is clear")
	for x in range(size):
		for y in range(size):
			assert_eq(MineShading.shade_color(0, x, y).a, 0.0, "a buried tile is clear")

func test_the_shade_atlas_has_one_tile_per_mask() -> void:
	var image := MineShading.build_image()
	assert_eq(image.get_width(), MineGrid.TILE_SIZE * 16, "sixteen tiles wide")
	assert_eq(image.get_height(), MineGrid.TILE_SIZE, "one tile tall")
	var drawn := image.get_pixel(MineGrid.TILE_SIZE * MineShading.NORTH + 8, 0)
	var wanted := MineShading.shade_color(MineShading.NORTH, 8, 0)
	assert_true(absf(drawn.a - wanted.a) < 0.01 and absf(drawn.r - wanted.r) < 0.01, "tiles are drawn from shade_color (%s vs %s)" % [str(drawn), str(wanted)])

func _expected_mask(mine: MineGrid, cell: Vector2i) -> int:
	return MineShading.mask(
		not mine.is_solid(cell + Vector2i.UP), not mine.is_solid(cell + Vector2i.RIGHT),
		not mine.is_solid(cell + Vector2i.DOWN), not mine.is_solid(cell + Vector2i.LEFT))

func _shade_of(mine: MineGrid, cell: Vector2i) -> int:
	return mine.get_cell_atlas_coords(MineGrid.SHADE_LAYER, cell).x if mine.get_cell_source_id(MineGrid.SHADE_LAYER, cell) != -1 else 0

func test_every_rock_cell_is_shaded_by_its_open_neighbours() -> void:
	var mine := shared_mine(1001)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var checked := 0
	for i in range(3000):
		var cell := Vector2i(rng.randi_range(1, MineGrid.GRID_WIDTH - 2), rng.randi_range(1, MineGrid.GRID_HEIGHT - 2))
		if not mine.is_solid(cell):
			assert_eq(_shade_of(mine, cell), 0, "open ground at %s has no shade" % str(cell))
			continue
		checked += 1
		assert_eq(_shade_of(mine, cell), _expected_mask(mine, cell), "shade at %s" % str(cell))
	assert_true(checked > 500, "enough rock cells were checked (%d)" % checked)

func test_digging_and_filling_keep_the_shading_current() -> void:
	var mine: MineGrid = add(MineScene.instantiate())
	var cell := Vector2i(80, 300)
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			mine.fill_cell(cell + Vector2i(dx, dy))
	assert_eq(_shade_of(mine, cell + Vector2i.UP), 0, "buried rock is clear")
	mine.dig_cells([cell])
	assert_eq(_shade_of(mine, cell + Vector2i.UP), MineShading.SOUTH, "the rock above a hole is shadowed on its underside")
	assert_eq(_shade_of(mine, cell + Vector2i.DOWN), MineShading.NORTH, "the rock below it is lit on its top edge")
	assert_eq(_shade_of(mine, cell + Vector2i.LEFT), MineShading.EAST, "and the side rock on its open side")
	assert_eq(_shade_of(mine, cell), 0, "the hole itself has no shade")
	mine.fill_cell(cell)
	assert_eq(_shade_of(mine, cell + Vector2i.UP), 0, "refilled: clear again")
	assert_eq(_shade_of(mine, cell), 0, "the refilled cell is buried again")

func test_shading_adds_no_collision() -> void:
	var mine := shared_mine(1001)
	for x in range(MineGrid.GRID_WIDTH):
		var cell := Vector2i(x, MineGrid.SURFACE_ROWS + 1)
		if mine.get_cell_source_id(MineGrid.SHADE_LAYER, cell) != -1:
			var data := mine.get_cell_tile_data(MineGrid.SHADE_LAYER, cell)
			assert_eq(data.get_collision_polygons_count(0), 0, "a shade tile is not solid")
			return
	assert_true(false, "some surface rock is shaded")

# --- vignette and dust --------------------------------------------------------------------

func _main() -> Main:
	Progress.path_override = TEST_SAVE_PATH
	var fresh := Progress.new()
	fresh.save_path = TEST_SAVE_PATH
	fresh.save()
	return add(load("res://scenes/Main.tscn").instantiate())

func test_a_run_has_a_vignette_under_the_hud() -> void:
	var main := _main()
	await physics_frames(3)
	assert_true(main.vignette is CanvasLayer, "Main has a vignette")
	assert_eq(main.vignette.layer, main.hud.layer, "on the HUD's layer")
	assert_true(main.vignette.get_index() < main.hud.get_index(), "drawn before the HUD, so the text stays clear")
	Progress.path_override = ""

func test_a_run_has_dust_drifting_in_the_air() -> void:
	var main := _main()
	await physics_frames(3)
	assert_true(main.dust_motes is CPUParticles2D, "Main has dust motes")
	assert_true(main.dust_motes.emitting, "emitting")
	assert_true(not main.dust_motes.local_coords, "the motes hang in the air as the player moves")
	assert_true(main.dust_motes.amount <= 40, "a few motes, not a storm (%d)" % main.dust_motes.amount)
	assert_eq(main.dust_motes.get_parent(), main.player, "they follow the player")
	Progress.path_override = ""
