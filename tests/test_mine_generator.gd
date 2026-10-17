extends TestCase

## Generation, tested on plain data (issue #74): MineGenerator.generate(seed) builds a
## MineLayout with no scene and no tile map. The same seeds as the old MineGrid tests.

const TORCH_SEEDS := [1001, 1, 2, 3, 31, 35, 44, 98]
const GoldenTest := preload("res://tests/test_mine_golden.gd")

func _in_shaft(layout: MineLayout, cell: Vector2i) -> bool:
	return MineGenerator.shaft_rect(layout.shaft_end_row).has_point(cell)

func _pickup_cells(layout: MineLayout) -> Array:
	return layout.fuel_cells + layout.ore_cells.map(func(o): return o.cell)

func _on_a_spine(layout: MineLayout, cell: Vector2i) -> bool:
	return layout.drifts.any(func(d: Drift): return cell.y == d.row and cell.x >= mini(d.x0, d.x1) and cell.x <= maxi(d.x0, d.x1))

func _torches(layout: MineLayout, where: String) -> Array:
	return layout.torches.filter(func(t): return t.where == where)

# --- the layout is data -----------------------------------------------------------

func test_generate_creates_no_nodes() -> void:
	var before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	MineGenerator.generate(7)
	assert_eq(Performance.get_monitor(Performance.OBJECT_NODE_COUNT), before, "no node was made")

func test_drifts_rooms_and_torches_are_typed_data() -> void:
	var layout := shared_layout(1001)
	assert_true(not layout.drifts.is_empty() and layout.drifts.all(func(d): return d is Drift), "drifts are Drift objects")
	assert_true(not layout.event_rooms.is_empty() and layout.event_rooms.all(func(r): return r is EventRoom), "rooms are EventRoom objects")
	assert_true(not layout.torches.is_empty() and layout.torches.all(func(t): return t is TorchSite), "torches are TorchSite objects")
	var lift: EventRoom = layout.event_rooms.filter(func(r): return r.kind == "lift")[0]
	assert_true(lift.in_shaft and not lift.at_drift_end, "the lift is flagged as the shaft's own")
	var vault: EventRoom = layout.event_rooms.filter(func(r): return r.kind == "vault")[0] if layout.event_rooms.any(func(r): return r.kind == "vault") else null
	if vault != null:
		assert_true(vault.door.x >= 0, "a vault knows its door")
	var stone: Drift = layout.drifts.filter(func(d): return d.layer == 2)[0]
	assert_eq(stone.end_kind, "miner", "the Stone gallery ends at the lost miner")
	assert_eq(stone.cells().size(), (absi(stone.x1 - stone.x0) + 1) * 2, "a drift lists its two rows of open cells")

func test_a_drift_keeps_its_collapses_in_a_list() -> void:
	var layout := shared_layout(1001)
	for d in layout.drifts:
		assert_eq(d.from_shaft, d.layer <= 2, "layer %d: only the top three layers are fed from the shaft" % d.layer)
		if d.layer == 0:
			assert_true(d.collapses.is_empty(), "Topsoil has no collapse")
			assert_eq(d.to_dict()["features"]["collapse"], Rect2i(), "and the fingerprint key is empty")
		else:
			assert_true(d.collapses.size() >= MineGrid.SPINE_COLLAPSES_MIN, "layer %d has several collapses" % d.layer)
			assert_eq(d.to_dict()["features"]["collapse"], d.collapses[0], "the fingerprint key holds the first, nearest the mouth")

func test_generate_is_a_pure_function_of_the_seed() -> void:
	var a := MineGenerator.generate(4242)
	var b := MineGenerator.generate(4242)
	assert_true(a.kinds == b.kinds, "same tiles")
	assert_eq(a.drifts.map(func(d): return d.to_dict()), b.drifts.map(func(d): return d.to_dict()), "same drifts")
	assert_eq(a.event_rooms.map(func(r): return r.to_dict()), b.event_rooms.map(func(r): return r.to_dict()), "same rooms")
	assert_eq(a.torches.map(func(t): return t.to_dict()), b.torches.map(func(t): return t.to_dict()), "same torches")
	assert_eq(a.spare_floor_cells, b.spare_floor_cells, "same spare floors")
	assert_true(a.kinds != MineGenerator.generate(4243).kinds, "another seed builds another mine")

func test_layout_invariants_hold_for_many_seeds() -> void:
	for s in range(1, 31):
		var layout := shared_layout(s)
		var stone := MineGenerator.layer_rows(2)
		assert_true(layout.shaft_end_row >= stone.x and layout.shaft_end_row <= stone.x + (stone.y - stone.x) / 2, "seed %d: the shaft ends in the upper half of Stone" % s)
		for cell in _pickup_cells(layout):
			assert_true(not layout.room_cells.has(cell) or _on_a_spine(layout, cell), "seed %d: a pickup in a room or the old mine, off the galleries, at %s" % [s, cell])
			assert_true(not layout.is_solid(cell) and layout.is_solid(cell + Vector2i.DOWN), "seed %d: a pickup stands on a floor at %s" % [s, cell])
		var miner := layout.lost_miner_cell
		if miner.x >= 0:
			assert_true(not layout.is_solid(miner), "seed %d: the lost miner is in open space" % s)
		for d in layout.drifts:
			if d.from_shaft:
				assert_eq(layout.kind_at(Vector2i(layout.shaft_column() + d.side, d.row + 1)), MineLayout.Kind.PLANK, "seed %d: a plank landing beside the shaft" % s)

# --- spines (long, decayed galleries) -------------------------------------------

func test_spines_are_long() -> void:
	for s in GoldenTest.SEEDS:
		for d in shared_layout(s).drifts:
			if d.from_shaft:
				assert_true(d.length() >= MineGrid.SPINE_MIN_LENGTH and d.length() <= MineGrid.SPINE_MAX_LENGTH, "seed %d layer %d: length %d" % [s, d.layer, d.length()])

func test_spines_are_walkable_and_decayed() -> void:
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		for d in layout.drifts:
			assert_eq(GalleryChecks.passage_problems(layout, d), [], "seed %d layer %d passage" % [s, d.layer])
			assert_eq(GalleryChecks.collapse_problems(d), [], "seed %d layer %d collapses" % [s, d.layer])

func test_spines_leave_the_shaft_at_the_landing_and_stay_in_the_map() -> void:
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		for d in layout.drifts:
			if not d.from_shaft:
				continue
			assert_eq(d.x0, layout.shaft_column() + d.side * (MineGrid.SHAFT_WIDTH / 2 + 1), "seed %d: starts beside the shaft" % s)
			assert_eq(layout.kind_at(Vector2i(layout.shaft_column() + d.side, d.row + 1)), MineLayout.Kind.PLANK, "seed %d: a plank landing" % s)
			assert_true(mini(d.x0, d.x1) >= MineGrid.WORKING_EDGE_MARGIN and maxi(d.x0, d.x1) <= MineGrid.GRID_WIDTH - 1 - MineGrid.WORKING_EDGE_MARGIN, "seed %d: inside the margins" % s)

func test_the_stone_spine_takes_the_side_facing_the_heart() -> void:
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		var heart: EventRoom = layout.event_rooms.filter(func(r): return r.kind == "heart")[0]
		var stone: Array = layout.drifts.filter(func(d): return d.layer == 2)
		if stone.is_empty():
			continue
		assert_eq(stone[0].side, 1 if heart.cell.x > layout.shaft_column() else -1, "seed %d: Stone heads for the Heart" % s)

func test_every_layer_has_a_working() -> void:
	for s in GoldenTest.SEEDS:
		var layers: Array = shared_layout(s).drifts.map(func(d): return d.layer)
		layers.sort()
		# Stone's spine hangs off the shaft's open part, which does not always reach it (as before).
		layers.erase(2)
		assert_eq(layers, [0, 1, 3, 4, 5], "seed %d: a spine in every layer the shaft or the deep workings reach" % s)

func test_deep_spines_are_free_standing_and_walkable() -> void:
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		for d in layout.drifts.filter(func(d): return d.layer >= 3):
			assert_true(not d.from_shaft and d.end_kind == "", "seed %d layer %d: free-standing, no end feature" % [s, d.layer])
			assert_true(d.length() >= MineGrid.SPINE_MIN_LENGTH and d.length() <= MineGrid.SPINE_MAX_LENGTH, "seed %d layer %d: length %d" % [s, d.layer, d.length()])
			assert_eq(MineGenerator.layer_index_for_row(d.row), d.layer, "seed %d: in its layer" % s)
			assert_eq(GalleryChecks.passage_problems(layout, d), [], "seed %d layer %d passage" % [s, d.layer])
			assert_eq(GalleryChecks.collapse_problems(d), [], "seed %d layer %d collapses" % [s, d.layer])
			assert_true(mini(d.x0, d.x1) >= MineGrid.WORKING_EDGE_MARGIN and maxi(d.x0, d.x1) <= MineGrid.GRID_WIDTH - 1 - MineGrid.WORKING_EDGE_MARGIN, "seed %d: inside the margins" % s)
			assert_true(not MineGenerator.shaft_rect(layout.shaft_end_row).intersects(Rect2i(mini(d.x0, d.x1), d.row - 1, d.length(), 3)), "seed %d: clear of the shaft" % s)

func test_deep_spines_head_toward_the_heart_and_stop_short_of_it() -> void:
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		var heart: EventRoom = layout.event_rooms.filter(func(r): return r.kind == "heart")[0]
		for d in layout.drifts.filter(func(d): return d.layer >= 3):
			assert_true(GalleryChecks.heads_toward(d, heart.rect), "seed %d layer %d: heads for the Heart" % [s, d.layer])
		for d in layout.drifts:
			assert_true(not heart.rect.grow(1).intersects(Rect2i(mini(d.x0, d.x1), d.row - 1, d.length(), 3)), "seed %d layer %d: clear of the Heart room" % [s, d.layer])
		var last: Drift = layout.drifts.filter(func(d): return d.layer == 5)[0]
		var gap: int = (heart.rect.position.x - last.x1 - 1) if last.side > 0 else (last.x1 - (heart.rect.end.x - 1) - 1)
		assert_true(gap >= MineGrid.HEART_STANDOFF_TILES, "seed %d: the layer 5 spine stops %d tiles short (>= %d)" % [s, gap, MineGrid.HEART_STANDOFF_TILES])

func test_spine_span_keeps_clear_of_an_anchor_and_the_margins() -> void:
	var heart := Rect2i(3, 440, 9, 4) # a Heart against the left side
	var left := MineGenerator.spine_span(-1, heart, 100, 0)
	assert_eq(left.x, MineGrid.GRID_WIDTH - 1 - MineGrid.WORKING_EDGE_MARGIN, "starts at the right margin and runs left")
	assert_true(left.y >= heart.end.x + MineGrid.HEART_STANDOFF_TILES, "and stops short of the Heart")
	var right := MineGenerator.spine_span(1, Rect2i(140, 440, 9, 4), 100, 5)
	assert_eq(right.x, MineGrid.WORKING_EDGE_MARGIN + 5, "the start offset moves it inside the margin")
	assert_true(Rect2i(140, 440, 9, 4).position.x - right.y - 1 >= MineGrid.HEART_STANDOFF_TILES, "right-hand Heart: stops short")
	assert_eq(MineGenerator.spine_span(1, Rect2i(40, 440, 9, 4), 100, 0), Vector2i(-1, -1), "no span of at least the minimum fits: none")
	var free := MineGenerator.spine_span(1, Rect2i(), 80, 0)
	assert_eq(free, Vector2i(MineGrid.WORKING_EDGE_MARGIN, MineGrid.WORKING_EDGE_MARGIN + 79), "without an anchor only the margins limit it")

# --- pickups along the galleries --------------------------------------------------

func _spine_cells(drift: Drift) -> Dictionary:
	var cells := {}
	for i in range(drift.length()):
		cells[Vector2i(drift.x0 + drift.side * i, drift.row)] = i
	return cells

func test_gallery_pickups_sit_on_gallery_floors() -> void:
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		var fuel_wanted := 0
		var ore_wanted := 0
		var on_spines := {}
		for d in layout.drifts:
			fuel_wanted += d.length() / MineGrid.GALLERY_FUEL_TILES
			ore_wanted += d.length() / MineGrid.GALLERY_ORE_TILES
			var cells := _spine_cells(d)
			for cell in cells:
				on_spines[cell] = d
		var fuel_here := layout.fuel_cells.filter(func(c): return on_spines.has(c))
		var ore_here := layout.ore_cells.filter(func(o): return on_spines.has(o.cell))
		assert_eq(fuel_here.size(), fuel_wanted, "seed %d: one fuel per %d tiles of spine" % [s, MineGrid.GALLERY_FUEL_TILES])
		assert_eq(ore_here.size(), ore_wanted, "seed %d: one ore per %d tiles of spine" % [s, MineGrid.GALLERY_ORE_TILES])
		for cell in fuel_here + ore_here.map(func(o): return o.cell):
			var d: Drift = on_spines[cell]
			var i: int = _spine_cells(d)[cell]
			assert_true(i > 0 and i < d.length() - 1, "seed %d: not at a spine's mouth or far end" % s)
			assert_true(not d.collapses.any(func(box): return box.has_point(cell)), "seed %d: not inside a collapse" % s)
			assert_true(layout.is_solid(cell + Vector2i.DOWN), "seed %d: standing on a floor" % s)
		for o in ore_here:
			assert_eq(o.value, MineGrid.LAYERS[MineGenerator.layer_index_for_row(o.cell.y)].ore, "seed %d: ore is worth its layer's value" % s)

func test_the_pickup_totals_are_unchanged() -> void:
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		assert_eq(layout.fuel_cells.size(), MineGrid.FUEL_DEPOSIT_COUNT, "seed %d: the same amount of fuel in the mine" % s)
		assert_eq(layout.ore_cells.size(), MineGrid.ORE_DEPOSIT_COUNT, "seed %d: the same amount of ore" % s)
		var seen := {}
		for cell in _pickup_cells(layout):
			assert_true(not seen.has(cell), "seed %d: two pickups on %s" % [s, cell])
			seen[cell] = true

func test_a_short_gallery_leaves_the_shortfall_to_the_caves() -> void:
	var gen := MineGenerator.new()
	gen._solid = gen._make_grid(true) # every standing cell has a floor
	var drift := Drift.new(3, 1, 100, 10, 49, "") # 40 tiles: wants 3 fuel and 1 ore
	drift.collapses = [Rect2i(11, 99, 35, 2)] # only x = 46, 47, 48 are usable
	gen._layout.drifts = [drift]
	var found := gen._gallery_pickups()
	assert_eq(found.fuel.size(), 3, "the fuel takes every usable cell")
	assert_eq(found.ore.size(), 0, "so the ore is left to the caves")
	for cell in found.fuel:
		assert_true(cell.x >= 46 and cell.x <= 48 and cell.y == 100, "and only usable cells: %s" % cell)

# --- connectors (passages from the spines to the rooms) ----------------------------

func _spine_for(layout: MineLayout, c: Connector) -> Drift:
	return layout.drifts.filter(func(d): return d.layer == c.layer)[0]

func test_connector_length_and_origin() -> void:
	assert_eq(MineGenerator.connector_length(2), 2, "a drop of 2 is just the junction pit")
	assert_eq(MineGenerator.connector_length(5), 8, "two columns per level")
	assert_eq(MineGenerator.connector_length(51), MineGrid.CONNECTOR_MAX_LENGTH, "100 tiles of staircase is the cap")
	assert_eq(MineGenerator.connector_origin(100, 5, 1, 40, 200), 92, "running right it starts the staircase's length left of the room")
	assert_eq(MineGenerator.connector_origin(100, 5, -1, 40, 200), 108, "running left, to its right")
	assert_eq(MineGenerator.connector_origin(100, 5, 1, 40, 90), 89, "a spine that ends short: start at its end and run flat")
	assert_eq(MineGenerator.connector_origin(100, 5, 1, 95, 120), -1, "no spine column leaves room for the stairs: none")

func test_connectors_are_walkable_and_meet_their_rooms() -> void:
	var total := 0
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		for c in layout.connectors:
			total += 1
			var spine := _spine_for(layout, c)
			assert_eq(GalleryChecks.connector_problems(layout, c, spine), [], "seed %d layer %d connector to a %s" % [s, c.layer, c.room.kind])
			var rows := MineGenerator.layer_rows(c.layer)
			assert_true(GalleryChecks.reachable(layout, c.mouth, c.room.cell, Vector2i(rows.x - 2, rows.y + 8)),
					"seed %d: the %s is reachable on foot from its connector's mouth" % [s, c.room.kind])
	assert_true(total >= 10, "across %d seeds some rooms get a connector (%d)" % [GoldenTest.SEEDS.size(), total])

func test_connectors_reach_rooms_far_below_their_spine() -> void:
	var deepest := 0
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		for c in layout.connectors:
			deepest = maxi(deepest, c.room.cell.y - _spine_for(layout, c).row)
	assert_true(deepest > 36, "a connector drops more than the old 36 rows (deepest %d)" % deepest)

func test_connectors_skip_the_vault_the_heart_and_the_lift() -> void:
	for s in GoldenTest.SEEDS:
		for c in shared_layout(s).connectors:
			assert_true(not c.room.kind in ["vault", "heart", "lift"] and not c.room.at_drift_end, "seed %d: no connector to a %s" % [s, c.room.kind])

func test_connectors_do_not_cross_anything() -> void:
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		var taken := {}
		for c in layout.connectors:
			var spine := _spine_for(layout, c)
			for i in range(c.cells.size()):
				var cell: Vector2i = c.cells[i]
				assert_true(not taken.has(cell), "seed %d: two connectors share %s" % [s, cell])
				taken[cell] = true
				assert_true(not MineGenerator.shaft_rect(layout.shaft_end_row).grow(1).has_point(cell), "seed %d: clear of the shaft" % s)
				for room in layout.event_rooms:
					if room != c.room:
						assert_true(not room.rect.grow(1).has_point(cell), "seed %d: clear of the %s room" % [s, room.kind])
				for d in layout.drifts:
					if d != spine:
						assert_true(not Rect2i(mini(d.x0, d.x1), d.row - 1, d.length(), 3).has_point(cell), "seed %d: clear of the layer %d spine" % [s, d.layer])
			for box in spine.collapses:
				assert_true(not box.grow(1).has_point(c.mouth), "seed %d: the junction is not in or beside a collapse" % s)
		for room in layout.event_rooms.filter(func(r): return r.kind == "vault"):
			for cell in layout.vault_cells:
				assert_true(not taken.has(cell), "seed %d: the vault shell is untouched" % s)

func test_the_connector_skip_rate_is_reported() -> void:
	var eligible := 0
	var connected := 0
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		for room in layout.event_rooms:
			if room.kind in ["vault", "heart", "lift"] or room.at_drift_end or room.in_shaft:
				continue
			if layout.drifts.any(func(d): return d.layer == MineGenerator.layer_index_for_row(room.cell.y)):
				eligible += 1
		connected += layout.connectors.size()
	print("connectors: %d of %d eligible rooms (%d%%) across %d seeds" % [connected, eligible, 100 * connected / maxi(eligible, 1), GoldenTest.SEEDS.size()])
	assert_true(connected > 0, "some rooms are connected")

# --- clues: lit spines and framed branch mouths --------------------------------------

func test_each_spine_has_a_lit_torch_every_thirty_tiles() -> void:
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		for d in layout.drifts:
			var mine: Array = _torches(layout, "gallery").filter(func(t): return t.cell.y == d.row and t.cell.x >= mini(d.x0, d.x1) and t.cell.x <= maxi(d.x0, d.x1))
			assert_eq(mine.size(), d.length() / MineGrid.SPINE_TORCH_SPACING, "seed %d layer %d: a torch per %d tiles" % [s, d.layer, MineGrid.SPINE_TORCH_SPACING])
			var offsets: Array = mine.map(func(t): return absi(t.cell.x - d.x0))
			offsets.sort()
			for i in range(1, offsets.size()):
				assert_true(offsets[i] - offsets[i - 1] >= MineGrid.SPINE_TORCH_SPACING / 2, "seed %d: torches spread along the spine (%s)" % [s, str(offsets)])
			for t in mine:
				assert_true(not layout.is_solid(t.cell) and layout.is_solid(t.cell + Vector2i.DOWN), "seed %d: on an open standing cell" % s)
				assert_true(not d.collapses.any(func(box): return box.has_point(t.cell)), "seed %d: not in a collapse" % s)
				assert_true(not _pickup_cells(layout).has(t.cell), "seed %d: not on a pickup" % s)

func test_a_spine_torch_takes_no_numbers_from_the_global_generator() -> void:
	var gen := MineGenerator.new()
	gen._solid = gen._make_grid(true)
	for x in range(10, 80):
		gen._solid[x][99] = false
		gen._solid[x][100] = false
	gen._layout.drifts = [Drift.new(3, 1, 100, 10, 79, "")]
	seed(321)
	var expected := randi()
	seed(321)
	gen._place_gallery_torches()
	assert_eq(randi(), expected, "the global generator is untouched")
	assert_eq(_torches(gen._layout, "gallery").size(), 2, "a 70-tile spine gets two torches")

func test_connector_mouths_are_framed_by_posts() -> void:
	var framed := 0
	for s in GoldenTest.SEEDS:
		var layout := shared_layout(s)
		for c in layout.connectors:
			var spine := _spine_for(layout, c)
			var low := mini(spine.x0, spine.x1)
			var high := maxi(spine.x0, spine.x1)
			for column in [c.mouth.x - c.dir, c.mouth.x + 2 * c.dir]:
				if column < low or column > high:
					continue # the spine ends there
				for row in [spine.row, spine.row - 1]:
					assert_eq(layout.decor.get(Vector2i(column, row), -1), MineLayout.Decor.POST, "seed %d: a post at (%d, %d) beside the junction" % [s, column, row])
					framed += 1
	assert_true(framed > 0, "some mouths are framed")

func test_the_shaft_and_ladder_keep_their_values() -> void:
	# Recorded from the code before the workings: they draw before the drifts, from the same stream.
	var expected := {1001: 163, 1: 180, 2: 171}
	for s in expected:
		assert_eq(shared_layout(s).shaft_end_row, expected[s], "seed %d: the shaft ends where it did" % s)
	assert_eq(shared_layout(1001).old_ladder_rows, [5, 13, 29, 45, 53, 61, 69, 77, 85, 101, 109, 117, 141, 149], "seed 1001: the same ladder pieces")

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
			assert_true(length >= MineGrid.SPINE_MIN_LENGTH and length <= MineGrid.SPINE_MAX_LENGTH, "seed %d: length %d" % [s, length])
			if d.from_shaft:
				assert_eq(d.x0, layout.shaft_column() + d.side * (MineGrid.SHAFT_WIDTH / 2 + 1), "seed %d: starts beside the shaft" % s)
			for cell in d.cells():
				assert_true(not layout.is_solid(cell) or layout.kind_at(cell) == MineLayout.Kind.DEBRIS, "seed %d: open at %s" % [s, cell])
			for x in range(mini(d.x0, d.x1), maxi(d.x0, d.x1) + 1):
				var floor_kind := layout.kind_at(Vector2i(x, d.row + 1))
				assert_true(layout.is_solid(Vector2i(x, d.row + 1)) or GalleryChecks.in_a_junction_pit(layout, d, x), "seed %d: floor at x=%d" % [s, x])
				assert_true(floor_kind != MineLayout.Kind.BEDROCK and floor_kind != MineLayout.Kind.VAULT, "seed %d: and it digs" % s)

func test_drifts_floor_caves_with_planks_and_post_in_uneven_pairs() -> void:
	var planks := 0
	var gaps := {}
	for s in range(1, 13):
		var layout := shared_layout(s)
		var framing := {} # the posts beside a connector's mouth are placed on purpose, off the spine's own rhythm
		for c in layout.connectors:
			framing[c.mouth.x - c.dir] = c.layer
			framing[c.mouth.x + 2 * c.dir] = c.layer
		for d in layout.drifts:
			var last_post := 0
			for i in range(d.length()):
				var x: int = d.x0 + d.side * i
				if framing.get(x, -1) == d.layer:
					continue
				if layout.kind_at(Vector2i(x, d.row + 1)) == MineLayout.Kind.PLANK:
					planks += 1
				var low: bool = layout.decor.get(Vector2i(x, d.row), -1) == MineLayout.Decor.POST
				var high: bool = layout.decor.get(Vector2i(x, d.row - 1), -1) == MineLayout.Decor.POST
				assert_eq(low, high, "seed %d: a post is a pair at step %d" % [s, i])
				if low:
					assert_true(i > 0, "seed %d: no post at the mouth" % s)
					assert_true(i - last_post >= MineGrid.SPINE_POST_GAP_MIN or last_post == 0, "seed %d: posts at least %d apart (%d)" % [s, MineGrid.SPINE_POST_GAP_MIN, i - last_post])
					gaps[i - last_post] = true
					last_post = i
	assert_true(planks > 0, "across 12 seeds some drift crosses a cave and gets planks")
	assert_true(gaps.size() > 2, "post gaps are uneven (%s)" % str(gaps.keys()))

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
			if room.in_shaft:
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
			if room.at_drift_end:
				continue # a drift's own camp stands inside it
			var rect: Rect2i = room.rect.grow(1)
			for d in layout.drifts:
				for cell in d.cells():
					assert_true(not rect.has_point(cell), "seed %d: room %s overlaps a drift" % [s, room.kind])
		for cell in _pickup_cells(layout):
			assert_true(not old_mine.any(func(r): return r.has_point(cell)) or _on_a_spine(layout, cell), "seed %d: pickup in the old mine off the galleries" % s)

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

# --- smoothing --------------------------------------------------------------------

## The smoothing step exactly as it was before the flat-array rewrite (nested arrays,
## 8 lookups per cell): the reference the fast version must match cell for cell.
func _reference_smooth(grid: Array) -> Array:
	var w := MineGrid.GRID_WIDTH
	var h := MineGrid.GRID_HEIGHT
	var out: Array = []
	for x in range(w):
		var column: Array = []
		column.resize(h)
		column.fill(false)
		out.append(column)
	for x in range(w):
		for y in range(h):
			if y < MineGrid.SURFACE_ROWS:
				continue
			var walls := 0
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					var nx := x + dx
					var ny := y + dy
					if nx < 0 or nx >= w or ny < 0 or ny >= h:
						walls += 1
					elif grid[nx][ny]:
						walls += 1
			out[x][y] = walls >= 4 if grid[x][y] else walls >= 5
	return out

func test_smooth_matches_the_reference_on_random_grids() -> void:
	var w := MineGrid.GRID_WIDTH
	var h := MineGrid.GRID_HEIGHT
	for s in [1, 2, 3, 4, 5]:
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		var nested: Array = []
		var flat := PackedByteArray()
		flat.resize(w * h)
		for x in range(w):
			var column: Array = []
			column.resize(h)
			for y in range(h):
				var solid: bool = rng.randf() < 0.45 + 0.1 * s / 5.0
				column[y] = solid
				flat[x * h + y] = 1 if solid else 0
			nested.append(column)
		var expected := _reference_smooth(nested)
		var got: PackedByteArray = MineGenerator.smooth(flat)
		var mismatches := 0
		for x in range(w):
			for y in range(h):
				if (got[x * h + y] == 1) != expected[x][y]:
					mismatches += 1
		assert_eq(mismatches, 0, "grid %d: cells that differ from the reference" % s)
