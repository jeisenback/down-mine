extends TestCase

const GoldenTest := preload("res://tests/test_mine_golden.gd")

## Old-workings decor (M90): rails along the spines, rubble beside collapses, cobwebs in the upper
## corners. Cosmetic: it sits on the decor layer, has no collision, and takes its random numbers from
## its own stream.

func _spine_for_cell(layout: MineLayout, cell: Vector2i, row_offset: int) -> Drift:
	for d in layout.drifts:
		if cell.y == d.row + row_offset and cell.x >= mini(d.x0, d.x1) and cell.x <= maxi(d.x0, d.x1):
			return d
	return null

func _decor_cells(layout: MineLayout, kinds: Array) -> Array:
	var cells: Array = []
	for cell in layout.decor:
		if layout.decor[cell] in kinds:
			cells.append(cell)
	return cells

# --- the tiles ----------------------------------------------------------------------------

func _opaque_pixels(image: Image, rect: Rect2i, alpha: float = 0.3) -> int:
	var count := 0
	for x in range(rect.position.x, rect.end.x):
		for y in range(rect.position.y, rect.end.y):
			if image.get_pixel(x, y).a >= alpha:
				count += 1
	return count

func test_the_rail_is_drawn_low_in_its_tile() -> void:
	var tile := Rect2i(0, 0, 16, 16)
	for worn in [false, true]:
		var image := OldWorkingsArt.rail(worn)
		assert_eq(image.get_size(), Vector2i(16, 16), "a tile")
		assert_true(_opaque_pixels(image, tile) > 12, "the rail has something to see (worn %s)" % str(worn))
		assert_eq(_opaque_pixels(image, Rect2i(0, 0, 16, 9)), 0, "nothing in the top of the tile, where the miner stands (worn %s)" % str(worn))
	assert_true(_opaque_pixels(OldWorkingsArt.rail(false), tile) > _opaque_pixels(OldWorkingsArt.rail(true), tile), "the worn rail is missing pieces")

func test_the_rubble_is_a_low_heap() -> void:
	var image := OldWorkingsArt.rubble()
	assert_true(_opaque_pixels(image, Rect2i(0, 0, 16, 16)) > 25, "a heap of stones")
	assert_eq(_opaque_pixels(image, Rect2i(0, 0, 16, 8)), 0, "no higher than half the tile")

func test_the_cobweb_hangs_in_a_top_corner() -> void:
	var image := OldWorkingsArt.cobweb()
	assert_true(_opaque_pixels(image, Rect2i(0, 0, 16, 16), 0.2) > 10, "strands to see")
	assert_eq(_opaque_pixels(image, Rect2i(0, 9, 16, 7), 0.2), 0, "nothing in the bottom of the tile")
	assert_true(_opaque_pixels(image, Rect2i(0, 0, 8, 8), 0.2) > _opaque_pixels(image, Rect2i(8, 8, 8, 8), 0.2), "gathered in the top corner")

func test_the_decor_tiles_are_on_the_decor_layer_without_collision() -> void:
	var layout := shared_layout(1001)
	var mine := shared_mine(1001)
	var wanted := {
		MineLayout.Decor.RAIL: MineGrid.RAIL_ATLAS_COORDS, MineLayout.Decor.RAIL_WORN: MineGrid.RAIL_WORN_ATLAS_COORDS,
		MineLayout.Decor.RUBBLE: MineGrid.RUBBLE_ATLAS_COORDS, MineLayout.Decor.COBWEB: MineGrid.COBWEB_ATLAS_COORDS}
	for kind in wanted:
		var cells := _decor_cells(layout, [kind])
		assert_true(not cells.is_empty(), "seed 1001 has decor of kind %d" % kind)
		if cells.is_empty():
			continue
		assert_eq(mine.get_cell_atlas_coords(MineGrid.DECOR_LAYER, cells[0]), wanted[kind], "kind %d is drawn from its tile" % kind)
		assert_eq(mine.get_cell_tile_data(MineGrid.DECOR_LAYER, cells[0]).get_collision_polygons_count(0), 0, "kind %d has no collision" % kind)

# --- where it goes ------------------------------------------------------------------------

func test_rails_run_on_open_standing_cells_of_a_spine() -> void:
	var total := 0
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		var pits := {}
		for c in layout.connectors:
			pits[c.mouth] = true
			pits[c.mouth + Vector2i(c.dir, 0)] = true
		var torch_cells := {}
		for t in layout.torches:
			torch_cells[t.cell] = true
		for cell in _decor_cells(layout, [MineLayout.Decor.RAIL, MineLayout.Decor.RAIL_WORN]):
			total += 1
			var spine := _spine_for_cell(layout, cell, 0)
			assert_true(spine != null, "seed %d: a rail at %s is on a spine's standing row" % [s, str(cell)])
			if spine == null:
				continue
			assert_true(not layout.is_solid(cell) and layout.is_solid(cell + Vector2i.DOWN), "seed %d: on an open standing cell" % s)
			assert_true(not spine.collapses.any(func(box): return box.has_point(cell)), "seed %d: not inside a collapse" % s)
			assert_true(not pits.has(cell), "seed %d: not over a connector's pit" % s)
			assert_true(not torch_cells.has(cell), "seed %d: not under a torch" % s)
	assert_true(total > 400, "plenty of rail across the golden seeds (%d cells)" % total)

func test_rubble_lies_beside_collapses() -> void:
	var total := 0
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		for cell in _decor_cells(layout, [MineLayout.Decor.RUBBLE]):
			total += 1
			var spine := _spine_for_cell(layout, cell, 0)
			assert_true(spine != null, "seed %d: rubble at %s is on a spine's standing row" % [s, str(cell)])
			if spine == null:
				continue
			assert_true(spine.collapses.any(func(box: Rect2i): return cell.x >= box.position.x - 2 and cell.x <= box.end.x + 1 and not box.has_point(cell)), "seed %d: rubble %s is within two tiles of a collapse" % [s, str(cell)])
	assert_true(total > 20, "some rubble across the golden seeds (%d)" % total)

func test_cobwebs_hang_in_the_upper_corners_well_apart() -> void:
	var total := 0
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		var by_spine := {}
		for cell in _decor_cells(layout, [MineLayout.Decor.COBWEB]):
			total += 1
			var spine := _spine_for_cell(layout, cell, -1)
			assert_true(spine != null, "seed %d: a cobweb at %s is on a spine's upper row" % [s, str(cell)])
			if spine == null:
				continue
			assert_true(not layout.is_solid(cell) and layout.is_solid(cell + Vector2i.UP), "seed %d: under the roof" % s)
			assert_true(not spine.collapses.any(func(box): return box.has_point(cell)), "seed %d: not inside a collapse" % s)
			if not by_spine.has(spine):
				by_spine[spine] = []
			by_spine[spine].append(absi(cell.x - spine.x0))
		for spine in by_spine:
			var offsets: Array = by_spine[spine]
			offsets.sort()
			for i in range(1, offsets.size()):
				assert_true(offsets[i] - offsets[i - 1] >= MineGrid.COBWEB_GAP_MIN, "seed %d: webs at least %d apart (%s)" % [s, MineGrid.COBWEB_GAP_MIN, str(offsets)])
	assert_true(total > 30, "some cobwebs across the golden seeds (%d)" % total)

func test_decor_never_replaces_a_post() -> void:
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		for d in layout.drifts:
			for i in range(d.length()):
				var x: int = d.x0 + d.side * i
				var standing: int = layout.decor.get(Vector2i(x, d.row), -1)
				var upper: int = layout.decor.get(Vector2i(x, d.row - 1), -1)
				if standing == MineLayout.Decor.POST:
					assert_eq(upper, MineLayout.Decor.POST, "seed %d: a post keeps both its cells at column %d" % [s, x])

func test_decor_takes_no_numbers_from_the_global_generator() -> void:
	var gen := MineGenerator.new()
	gen._solid = gen._make_grid(true)
	for x in range(10, 90):
		gen._solid[x][99] = false
		gen._solid[x][100] = false
	gen._layout.mine_seed = 77
	gen._layout.drifts = [Drift.new(3, 1, 100, 10, 89, "")]
	seed(321)
	var expected := randi()
	seed(321)
	gen._place_old_workings_decor()
	assert_eq(randi(), expected, "the global generator is untouched")
	assert_true(gen._layout.decor.size() > 20, "and the decor was placed (%d cells)" % gen._layout.decor.size())
