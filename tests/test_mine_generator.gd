extends TestCase

## Generation, tested on plain data (issue #74): MineGenerator.generate(seed) builds a
## MineLayout with no scene and no tile map. The same seeds as the old MineGrid tests.

const TORCH_SEEDS := [1001, 1, 2, 3, 31, 35, 44, 98]

func _in_shaft(layout: MineLayout, cell: Vector2i) -> bool:
	return MineGenerator.shaft_rect(layout.shaft_end_row).has_point(cell)

func _drift_cells(d: Dictionary) -> Array:
	var cells: Array = []
	for i in range(absi(d.x1 - d.x0) + 1):
		var x: int = d.x0 + d.side * i
		cells.append(Vector2i(x, d.row - 1))
		cells.append(Vector2i(x, d.row))
	return cells

func _pickup_cells(layout: MineLayout) -> Array:
	return layout.fuel_cells + layout.ore_cells.map(func(o): return o.cell)

func _torches(layout: MineLayout, where: String) -> Array:
	return layout.torches.filter(func(t): return t.where == where)

# --- the layout is data -----------------------------------------------------------

func test_generate_creates_no_nodes() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	MineGenerator.generate(7)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "no node was made")

func test_generate_is_a_pure_function_of_the_seed() -> void:
	var a := MineGenerator.generate(4242)
	var b := MineGenerator.generate(4242)
	assert_true(a.kinds == b.kinds, "same tiles")
	assert_eq(a.drifts, b.drifts, "same drifts")
	assert_eq(a.event_rooms, b.event_rooms, "same rooms")
	assert_eq(a.torches, b.torches, "same torches")
	assert_eq(a.spare_floor_cells, b.spare_floor_cells, "same spare floors")
	assert_true(a.kinds != MineGenerator.generate(4243).kinds, "another seed builds another mine")

func test_layout_invariants_hold_for_many_seeds() -> void:
	for s in range(1, 31):
		var layout := shared_layout(s)
		var stone := MineGenerator.layer_rows(2)
		assert_true(layout.shaft_end_row >= stone.x and layout.shaft_end_row <= stone.x + (stone.y - stone.x) / 2, "seed %d: the shaft ends in the upper half of Stone" % s)
		for cell in _pickup_cells(layout):
			assert_true(not layout.room_cells.has(cell), "seed %d: a pickup in a room or the old mine at %s" % [s, cell])
			assert_true(not layout.is_solid(cell) and layout.is_solid(cell + Vector2i.DOWN), "seed %d: a pickup stands on a floor at %s" % [s, cell])
		var miner := layout.lost_miner_cell
		if miner.x >= 0:
			assert_true(not layout.is_solid(miner), "seed %d: the lost miner is in open space" % s)
		for d in layout.drifts:
			assert_eq(layout.kind_at(Vector2i(layout.shaft_column() + d.side, d.row + 1)), MineLayout.Kind.PLANK, "seed %d: a plank landing beside the shaft" % s)

# --- the old mine -----------------------------------------------------------------

func test_about_thirty_percent_of_old_ladder_pieces_are_missing() -> void:
	var present := 0
	var total := 0
	for s in range(1, 21):
		var layout := shared_layout(s)
		var open := layout.shaft_open_rows()
		var pieces := int(ceil((open.y - open.x + 1) / float(MineGrid.OLD_LADDER_PIECE_ROWS)))
		total += pieces
		present += layout.old_ladder_rows.size()
		for row in layout.old_ladder_rows:
			assert_true((row - open.x) % MineGrid.OLD_LADDER_PIECE_ROWS == 0 and row <= open.y, "piece rows sit on the 8-row grid inside the open shaft")
	var ratio := present / float(total)
	assert_true(ratio > 0.6 and ratio < 0.8, "about 70%% present (%.2f of %d)" % [ratio, total])

func test_each_worked_layer_gets_a_drift_of_the_right_shape() -> void:
	for s in [1001, 1, 2, 3, 4, 5, 6, 7]:
		var layout := shared_layout(s)
		var layers: Array = layout.drifts.map(func(d): return d.layer)
		assert_true(layers.has(0) and layers.has(1), "seed %d: Topsoil and Clay always have one" % s)
		for d in layout.drifts:
			assert_eq(MineGenerator.layer_index_for_row(d.row), d.layer, "seed %d: the drift sits in its layer" % s)
			var length: int = absi(d.x1 - d.x0) + 1
			assert_true(length >= MineGrid.DRIFT_MIN_LENGTH and length <= MineGrid.DRIFT_MAX_LENGTH, "seed %d: length %d" % [s, length])
			assert_eq(d.x0, layout.shaft_column() + d.side * (MineGrid.SHAFT_WIDTH / 2 + 1), "seed %d: starts beside the shaft" % s)
			for cell in _drift_cells(d):
				assert_true(not layout.is_solid(cell) or layout.kind_at(cell) == MineLayout.Kind.DEBRIS, "seed %d: open at %s" % [s, cell])
			for x in range(mini(d.x0, d.x1), maxi(d.x0, d.x1) + 1):
				var floor_kind := layout.kind_at(Vector2i(x, d.row + 1))
				assert_true(layout.is_solid(Vector2i(x, d.row + 1)), "seed %d: floor at x=%d" % [s, x])
				assert_true(floor_kind != MineLayout.Kind.BEDROCK and floor_kind != MineLayout.Kind.VAULT, "seed %d: and it digs" % s)

func test_drifts_floor_caves_with_planks_and_post_every_six_tiles() -> void:
	var planks := 0
	for s in range(1, 13):
		var layout := shared_layout(s)
		for d in layout.drifts:
			for i in range(absi(d.x1 - d.x0) + 1):
				var x: int = d.x0 + d.side * i
				if layout.kind_at(Vector2i(x, d.row + 1)) == MineLayout.Kind.PLANK:
					planks += 1
				var posted: bool = layout.decor.get(Vector2i(x, d.row), -1) == MineLayout.Decor.POST
				assert_eq(posted, i > 0 and i % MineGrid.DRIFT_POST_SPACING == 0, "seed %d: post at step %d" % [s, i])
	assert_true(planks > 0, "across 12 seeds some drift crosses a cave and gets planks")

func test_the_lift_stands_in_the_shaft_at_the_bottom_of_clay() -> void:
	# 31 and 98 move the lift off a Clay gallery; 35 caps it at the shaft's open end and then moves it.
	for s in [1001, 1, 2, 3, 4, 5, 6, 7, 8, 31, 35, 44, 89, 98]:
		var layout := shared_layout(s)
		var lifts: Array = layout.event_rooms.filter(func(r): return r.kind == "lift")
		assert_eq(lifts.size(), 1, "seed %d: one lift" % s)
		var cell: Vector2i = lifts[0].cell
		var col := layout.shaft_column()
		assert_true(absi(cell.x - col) == 1, "seed %d: on the shaft's edge column, ladder column left open" % s)
		assert_eq(MineGenerator.layer_index_for_row(cell.y), 1, "seed %d: in Clay" % s)
		assert_true(cell.y >= MineGenerator.layer_rows(1).y - 16, "seed %d: near Clay's bottom (row %d)" % [s, cell.y])
		assert_true(cell.y <= layout.shaft_open_rows().y - 2, "seed %d: inside the open shaft" % s)
		assert_true(not layout.is_solid(cell) and not layout.is_solid(cell + Vector2i.UP), "seed %d: open cage" % s)
		assert_eq(layout.kind_at(cell + Vector2i.DOWN), MineLayout.Kind.PLANK, "seed %d: a plank cage floor" % s)
		assert_true(not layout.is_solid(Vector2i(col, cell.y + 1)), "seed %d: the centre column stays open under it" % s)
		assert_true(layout.room_cells.has(cell) and layout.reserved_floors.has(cell + Vector2i.DOWN), "seed %d: the cage is kept clear of pickups and its floor never crumbles" % s)
		for d in layout.drifts:
			if d.layer == 1:
				assert_true(absi(d.row - cell.y) > 3, "seed %d: the Clay gallery (row %d) is clear of the lift (row %d)" % [s, d.row, cell.y])

func test_the_lost_miner_stands_at_the_stone_drifts_far_end() -> void:
	var with_drift := 0
	for s in range(1, 21):
		var layout := shared_layout(s)
		var stone: Array = layout.drifts.filter(func(d): return d.layer == 2)
		if stone.is_empty():
			assert_true(layout.lost_miner_cell.x >= 0, "seed %d: with no Stone drift the miner keeps the old placement" % s)
			continue
		with_drift += 1
		assert_eq(layout.lost_miner_cell, Vector2i(stone[0].x1, stone[0].row), "seed %d: the miner waits at the far end" % s)
	assert_true(with_drift >= 10, "most seeds have a Stone drift (%d of 20)" % with_drift)

func test_event_rooms_and_pickups_keep_out_of_the_shaft() -> void:
	# 3, 8, 13 and 51 are seeds whose rooms landed on the shaft before rooms learned to avoid it.
	for s in [3, 8, 11, 13, 22, 33, 44, 51, 55]:
		var layout := shared_layout(s)
		for room in layout.event_rooms:
			if room.has("shaft"):
				continue # the lift is the shaft's own
			var rect: Rect2i = room.rect.grow(1)
			for y in range(rect.position.y, rect.end.y):
				for x in range(rect.position.x, rect.end.x):
					assert_true(not _in_shaft(layout, Vector2i(x, y)), "seed %d: room %s overlaps the shaft" % [s, room.kind])
		for cell in _pickup_cells(layout):
			assert_true(not _in_shaft(layout, cell), "seed %d: pickup in the shaft" % s)
		var top_debris := Vector2i(layout.shaft_column(), layout.shaft_open_rows().y + 1)
		assert_true(layout.reserved_floors.has(top_debris), "seed %d: the debris never crumbles" % s)

func test_event_rooms_and_pickups_keep_out_of_the_drifts() -> void:
	# 44 and 89 are seeds where the lift room landed on a Stone drift before rooms avoided drifts.
	for s in [3, 8, 13, 22, 33, 44, 51, 55, 89, 1001]:
		var layout := shared_layout(s)
		var old_mine := MineGenerator.old_mine_rects(layout.drifts, layout.shaft_end_row)
		for room in layout.event_rooms:
			if room.has("drift"):
				continue # a drift's own camp stands inside it
			var rect: Rect2i = room.rect.grow(1)
			for d in layout.drifts:
				for cell in _drift_cells(d):
					assert_true(not rect.has_point(cell), "seed %d: room %s overlaps a drift" % [s, room.kind])
		for cell in _pickup_cells(layout):
			assert_true(not old_mine.any(func(r): return r.has_point(cell)), "seed %d: pickup in the old mine" % s)

# --- torches ----------------------------------------------------------------------

func test_shaft_torches_sit_on_the_frame_every_ten_rows_in_topsoil_and_clay() -> void:
	for s in TORCH_SEEDS:
		var layout := shared_layout(s)
		var open := layout.shaft_open_rows()
		var clay_bottom: int = MineGenerator.layer_rows(1).y
		var shaft := _torches(layout, "shaft")
		assert_true(shaft.size() >= 8, "seed %d: the shaft is lined (%d torches)" % [s, shaft.size()])
		var last := -1000
		var side := 0
		for t in shaft:
			var cell: Vector2i = t.cell
			assert_true(absi(cell.x - layout.shaft_column()) == 1, "seed %d: on a frame column" % s)
			assert_true(cell.y >= open.x and cell.y <= mini(open.y, clay_bottom), "seed %d: inside the open shaft above Clay's bottom (row %d)" % [s, cell.y])
			assert_true(not layout.is_solid(cell), "seed %d: not inside rock or a plank" % s)
			assert_true(cell.y - last >= MineGrid.TORCH_SHAFT_SPACING, "seed %d: ten rows apart" % s)
			if side != 0:
				assert_true(cell.x - layout.shaft_column() != side, "seed %d: alternating sides" % s)
			side = cell.x - layout.shaft_column()
			last = cell.y

func test_cave_torches_stand_on_free_floor_in_the_first_two_layers() -> void:
	for s in TORCH_SEEDS:
		var layout := shared_layout(s)
		var caves := _torches(layout, "cave")
		assert_eq(caves.size(), MineGrid.TORCH_CAVE_COUNT, "seed %d: the cave torch count" % s)
		for i in range(caves.size()):
			var cell: Vector2i = caves[i].cell
			assert_true(MineGenerator.layer_index_for_row(cell.y) <= 1, "seed %d: in Topsoil or Clay" % s)
			assert_true(not layout.is_solid(cell) and layout.is_solid(cell + Vector2i.DOWN), "seed %d: standing on a floor" % s)
			assert_true(not layout.room_cells.has(cell), "seed %d: not in the old mine or an event room" % s)
			assert_true(layout.reserved_floors.has(cell + Vector2i.DOWN), "seed %d: its floor never crumbles" % s)
			for j in range(i):
				var apart := Vector2(cell).distance_to(Vector2(caves[j].cell))
				assert_true(apart >= MineGrid.TORCH_CAVE_SPACING_TILES, "seed %d: torches %d tiles apart" % [s, apart])
