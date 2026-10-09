# M51b The Drifts Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** One old gallery per worked layer (Topsoil, Clay, upper Stone) branches off the shaft: a timber-posted two-tile tunnel that ends in that layer's camp or the lost miner, with a collapsed section to dig through in the Clay and Stone ones.

**Architecture:** `MineGrid._carve_drifts` runs at the end of `_carve_old_mine`, continuing its derived RNG so the shaft and ladder keep their values. Each drift is recorded as data (`drifts`), carved into the solid grid, floored with planks over caves, and posted on the decor layer. Camps join `event_rooms` as ordinary `camp` entries, so `Main._spawn_events` needs no change; the Stone drift's far cell becomes `lost_miner_cell`.

**Tech Stack:** Godot 4.5, GDScript. Tests are `tests/test_*.gd` extending `TestCase`, run with `godot --headless --fixed-fps 60 -s tests/run_tests.gd` (the Godot binary for this session is at `/tmp/claude-0/-home-user-down-mine/5ebdb75c-4140-522a-8fa8-1480d465a6fb/scratchpad/godot/godot`; run `--headless --import` once after adding scripts). Baseline: 86 passed. Playtest: `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd`, baseline 16 scenarios.

**Spec:** `docs/superpowers/specs/2026-10-09-run-loop-redesign-design.md`, section "The old mine" (Galleries and Tiles). The shaft is already built (M51a, `docs/superpowers/plans/2026-10-10-m51a-the-shaft.md`); the lift, the journal pointer and the rest of the contents are M51c.

## Global Constraints

- Values from the spec: one gallery per worked layer (Topsoil, Clay, Stone down to the collapse); it branches from the shaft to a random side at a random row in that layer; 2 tiles tall; 24 to 40 tiles long; timber posts every 6 tiles; where it crosses a cave a plank floor spans the gap (solid, diggable); a collapsed section is 4 to 8 tiles long and must be dug through; the camps of the worked layers move into galleries, deeper layers keep theirs as rooms; in Stone the lost miner's spot moves to the gallery's far end. Deterministic from the seed; generated before the event rooms so rooms avoid it.
- Ruling (the user chose it when the spec was ambiguous): the Topsoil and Clay galleries end in their layer's camp; the Stone gallery ends at the lost miner (Stone's camp stays a room); the Clay and Stone galleries each have one collapsed section midway, the Topsoil one has none.
- Naming: the existing `Gallery` class is the collapsing ore room (M36) and is unrelated. Code here says "drift"; README and ROADMAP say "gallery".
- Timber post and plank floor are drawn in code like the M51a tiles (M52 replaces them). The post is open and collision-free on the decor layer; the plank is a solid tile on layer 0.
- A drift needs open shaft rows to branch from. If the shaft's open part does not reach a layer (the collapse can sit in Stone's first rows), that layer gets no drift; Topsoil and Clay always do. The lost miner then keeps its old placement.
- No emojis anywhere. Every commit message ends with the two attribution lines used on this branch (see `git log -1`).

## Review Focus

Inputs the spec implies but no task's own happy path exercises, most likely to bite first. Each has its test in the owning task.

1. A drift that crosses a cave must stay walkable end to end (plank floors, headroom, no one-tile hop), including the step from the shaft into it. Task 1 and Task 3 (playtest).
2. Event rooms, the vault shell, pickups, gas and crumbling must keep out of every drift; drifts must not undercut a room that was placed later. Task 1.
3. A seed with no valid Stone row must still build a mine and keep a lost miner. Task 2.
4. Camps moving out of `EVENT_ROOMS` must leave exactly one camp per layer and keep reading journal pages in order of discovery. Task 2.
5. A collapsed section must not swallow the camp or miner at the far end, and must dig like rock. Task 2.

---

### Task 1: Carve the drifts

**Files:**
- Modify: `scripts/mine.gd` (tiles, `drifts`, `_carve_drifts`, room avoidance)
- Test: `tests/test_world.gd`

**Interfaces:**
- Consumes: M51a's `_carve_old_mine(solid)` and its local `rng`, `shaft_open_rows()`, `shaft_column()`, `_room_cells`, `_reserved_floors`, `DECOR_LAYER`, `DEBRIS_ATLAS_COORDS`, `FRAME_ATLAS_COORDS`.
- Produces: `const MineGrid.POST_ATLAS_COORDS := Vector2i(2 * LAYER_COUNT + 5, 0)` (decor layer, no collision polygon); `const MineGrid.PLANK_ATLAS_COORDS := Vector2i(2 * LAYER_COUNT + 6, 0)` (layer 0, solid and diggable); `const MineGrid.DRIFT_MIN_LENGTH := 24`, `DRIFT_MAX_LENGTH := 40`, `DRIFT_POST_SPACING := 6`; `var MineGrid.drifts: Array` of `{"layer": int, "side": int (-1 left, 1 right), "row": int (the standing row; its floor is row + 1; headroom is row - 1), "x0": int (first cell beside the shaft), "x1": int (far end cell), "features": Dictionary filled in Task 2}`, in layer order; `func MineGrid.drift_cells(drift: Dictionary) -> Array` (every open cell of the drift, both rows); `func MineGrid.is_in_old_mine(cell: Vector2i) -> bool` (the shaft or any drift, grown by nothing).
- `_shaft_rect()`-based room avoidance becomes avoidance of every old-mine rect: `_old_mine_rects() -> Array[Rect2i]` (the shaft's, then each drift's two-row box).

- [ ] **Step 1: Write the failing tests** in `tests/test_world.gd`:

```gdscript
func test_each_worked_layer_gets_a_drift_of_the_right_shape() -> void:
	for s in [1001, 1, 2, 3, 4, 5, 6, 7]:
		var mine := _mine_with_seed(s)
		var layers: Array = mine.drifts.map(func(d): return d.layer)
		assert_true(layers.has(0) and layers.has(1), "seed %d: Topsoil and Clay always have one" % s)
		for d in mine.drifts:
			assert_eq(mine.layer_index_at_world(mine.cell_to_world(Vector2i(d.x0, d.row))), d.layer, "seed %d: the drift sits in its layer" % s)
			var length: int = absi(d.x1 - d.x0) + 1
			assert_true(length >= MineGrid.DRIFT_MIN_LENGTH and length <= MineGrid.DRIFT_MAX_LENGTH, "seed %d: length %d" % [s, length])
			assert_eq(d.x0, mine.shaft_column() + d.side * (MineGrid.SHAFT_WIDTH / 2 + 1), "seed %d: starts beside the shaft" % s)
			for cell in mine.drift_cells(d):
				assert_true(not mine.is_solid(cell) or mine.get_cell_atlas_coords(0, cell) == MineGrid.DEBRIS_ATLAS_COORDS, "seed %d: open at %s" % [s, cell])
			for x in range(mini(d.x0, d.x1), maxi(d.x0, d.x1) + 1):
				assert_true(mine.is_solid(Vector2i(x, d.row + 1)), "seed %d: floor at x=%d" % [s, x])
				assert_true(not mine.is_indestructible(Vector2i(x, d.row + 1)), "seed %d: and it digs" % s)

func test_drifts_floor_caves_with_planks_and_post_every_six_tiles() -> void:
	var planks := 0
	for s in range(1, 13):
		var mine := _mine_with_seed(s)
		for d in mine.drifts:
			var step: int = d.side
			for i in range(absi(d.x1 - d.x0) + 1):
				var x: int = d.x0 + step * i
				if mine.get_cell_atlas_coords(0, Vector2i(x, d.row + 1)) == MineGrid.PLANK_ATLAS_COORDS:
					planks += 1
				var posted := mine.get_cell_atlas_coords(MineGrid.DECOR_LAYER, Vector2i(x, d.row)) == MineGrid.POST_ATLAS_COORDS
				assert_eq(posted, i > 0 and i % MineGrid.DRIFT_POST_SPACING == 0, "seed %d: post at step %d" % [s, i])
	assert_true(planks > 0, "across 12 seeds some drift crosses a cave and gets planks")
	var mine := _mine_with_seed(1001)
	var data: TileData = (mine.tile_set.get_source(mine.source_id) as TileSetAtlasSource).get_tile_data(MineGrid.POST_ATLAS_COORDS, 0)
	assert_eq(data.get_collision_polygons_count(0), 0, "the post has no collision")

func test_event_rooms_and_pickups_keep_out_of_the_drifts() -> void:
	for s in [3, 8, 13, 22, 33, 51, 55, 1001]:
		var mine := _mine_with_seed(s)
		for room in mine.event_rooms:
			if room.has("drift"):
				continue # a drift's own camp stands inside it
			var rect: Rect2i = room.rect.grow(1)
			for d in mine.drifts:
				for cell in mine.drift_cells(d):
					assert_true(not rect.has_point(cell), "seed %d: room %s overlaps a drift" % [s, room.kind])
		for child in mine.get_children():
			if child is FuelPickup or child is OrePickup:
				assert_true(not mine.is_in_old_mine(mine.world_to_cell(child.global_position)), "seed %d: pickup in the old mine" % s)
```

- [ ] **Step 2: Run to verify they fail.** Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd 2>&1 | grep -E "FAIL|Parse Error"`. Expected: parse errors, `drifts` / `POST_ATLAS_COORDS` not found.

- [ ] **Step 3: Implement** in `scripts/mine.gd`.
  - Tiles: add the two atlas constants after `FRAME_ATLAS_COORDS`; `atlas_width` follows `PLANK_ATLAS_COORDS.x + 1`; draw the post (a 2 px upright centred plus a 4 px cap beam across the top) in `TIMBER_COLOR`, and the plank (the Stone tile with three horizontal planks, brown) as in the debris drawing; the collision-polygon loop skips `POST_ATLAS_COORDS` as it skips the frame.
  - `_carve_drifts(solid, rng)`, called at the end of `_carve_old_mine`: for layers 0, 1, 2 in order, pick the row range `[max(layer_rows.x, open.x + 3), min(layer_rows.y - 3, open.y - 3)]`; skip the layer when it is empty; otherwise draw `row`, `side` (`rng.randi_range(0, 1) * 2 - 1`) and `length` (`DRIFT_MIN_LENGTH`..`DRIFT_MAX_LENGTH`) from `rng` in that order, set `x0 = shaft_column() + side * (SHAFT_WIDTH / 2 + 1)` and `x1 = x0 + side * (length - 1)`. Clear `(x, row)` and `(x, row - 1)` for every x; where `(x, row + 1)` is not solid set it solid and record it as a plank cell; add every drift cell and floor cell to `_room_cells`, every floor cell (plank or rock) to `_reserved_floors`. Also floor the shaft-side landing: the shaft cell `(shaft_column() + side, row + 1)` becomes a plank cell so the climb steps straight into the drift.
  - Painting: in the layer-0 painting loop a plank cell takes `PLANK_ATLAS_COORDS`; posts go on `DECOR_LAYER` at `(x, row)` and `(x, row - 1)` for `i > 0 and i % DRIFT_POST_SPACING == 0`.
  - Data and helpers: `drifts`, `drift_cells(d)`, `_old_mine_rects()`, `is_in_old_mine(cell)` (shaft rect or any drift box); `_carve_event_rooms` skips a candidate whose rect grown by 1 intersects any `_old_mine_rects()` entry (replacing M51a's single shaft check); `is_in_shaft` stays as is. Keep the M51a determinism: no draws before the ladder draws.

- [ ] **Step 4: Run the suite.** Expected: `89 passed, 0 failed`.

- [ ] **Step 5: Commit** `scripts/mine.gd tests/test_world.gd`: "M51b: galleries branch off the shaft, posted and planked over caves".

### Task 2: Collapsed sections, camps in the drifts, the miner at the far end

**Files:**
- Modify: `scripts/mine.gd` (`EVENT_ROOMS`, `_carve_drifts`, `_pick_lost_miner_cell`)
- Test: `tests/test_world.gd`, `tests/test_main.gd`

**Interfaces:**
- Consumes: Task 1's `drifts`.
- Produces: in each drift entry `"features"`: `{"collapse": Rect2i (x, y, width, height of the filled box, empty Rect2i when none), "end": "camp" | "miner"}`; the Topsoil and Clay drifts end `"camp"`, the Stone one `"miner"`; `const MineGrid.DRIFT_COLLAPSE_MIN := 4`, `DRIFT_COLLAPSE_MAX := 8`; `event_rooms` entries for the two drift camps shaped like the others (`{"kind": "camp", "cell": end cell, "rect": Rect2i around it, "drift": true}`); `lost_miner_cell` set to the Stone drift's end cell when that drift exists.

- [ ] **Step 1: Write the failing tests.** In `tests/test_world.gd`:

```gdscript
func test_clay_and_stone_drifts_have_a_collapsed_section_and_topsoil_does_not() -> void:
	for s in [1001, 1, 2, 3, 4, 5]:
		var mine := _mine_with_seed(s)
		for d in mine.drifts:
			var box: Rect2i = d.features.collapse
			if d.layer == 0:
				assert_eq(box.size, Vector2i.ZERO, "seed %d: Topsoil's drift is clear" % s)
				continue
			assert_true(box.size.x >= MineGrid.DRIFT_COLLAPSE_MIN and box.size.x <= MineGrid.DRIFT_COLLAPSE_MAX, "seed %d: layer %d collapse is %d long" % [s, d.layer, box.size.x])
			assert_eq(box.size.y, 2, "seed %d: it fills both rows" % s)
			for cell in _cells_of(box):
				assert_eq(mine.get_cell_atlas_coords(0, cell), MineGrid.DEBRIS_ATLAS_COORDS, "seed %d: debris at %s" % [s, cell])
				assert_true(not mine.is_indestructible(cell), "and it digs")
			var far: int = d.x1
			var near_end: int = maxi(box.position.x, box.end.x - 1) if d.side > 0 else mini(box.position.x, box.end.x - 1)
			assert_true(absi(far - near_end) >= 4, "seed %d: at least 4 clear tiles between the collapse and the far end" % s)
			assert_true(absi(box.position.x - d.x0) >= 4 or absi(box.end.x - 1 - d.x0) >= 4, "and the collapse is not at the shaft mouth")

func _cells_of(box: Rect2i) -> Array:
	var cells: Array = []
	for x in range(box.position.x, box.end.x):
		for y in range(box.position.y, box.end.y):
			cells.append(Vector2i(x, y))
	return cells

func test_camps_of_the_worked_layers_stand_at_the_drift_ends() -> void:
	for s in [1001, 1, 2, 3]:
		var mine := _mine_with_seed(s)
		var camps: Array = mine.event_rooms.filter(func(r): return r.kind == "camp")
		assert_eq(camps.size(), MineGrid.LAYERS.size(), "seed %d: one camp per layer" % s)
		for d in mine.drifts:
			if d.features.end == "camp":
				var hit: Array = camps.filter(func(r): return r.cell == Vector2i(d.x1, d.row))
				assert_eq(hit.size(), 1, "seed %d: layer %d's camp is at its drift's end" % [s, d.layer])
		for layer in [0, 1]:
			assert_eq(camps.filter(func(r): return mine.layer_index_at_world(mine.cell_to_world(r.cell)) == layer).size(), 1, "seed %d: exactly one camp in layer %d" % [s, layer])

func test_the_lost_miner_stands_at_the_stone_drifts_far_end() -> void:
	var with_drift := 0
	for s in range(1, 21):
		var mine := _mine_with_seed(s)
		var stone: Array = mine.drifts.filter(func(d): return d.layer == 2)
		if stone.is_empty():
			assert_true(mine.lost_miner_cell.x >= 0, "seed %d: with no Stone drift the miner keeps the old placement" % s)
			continue
		with_drift += 1
		assert_eq(mine.lost_miner_cell, Vector2i(stone[0].x1, stone[0].row), "seed %d: the miner waits at the far end" % s)
	assert_true(with_drift >= 10, "most seeds have a Stone drift (%d of 20)" % with_drift)
```

In `tests/test_main.gd`:

```gdscript
func test_main_places_a_camp_and_the_miner_inside_the_drifts() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var stone: Array = main.mine.drifts.filter(func(d): return d.layer == 2)
	assert_true(not stone.is_empty(), "seed 1001 has a Stone drift")
	var miner_cell: Vector2i = main.mine.world_to_cell(main.lost_miners[0].global_position)
	assert_true(absi(miner_cell.x - stone[0].x1) <= 1 and absi(miner_cell.y - stone[0].row) <= 1, "the lost miner is at the Stone drift's far end")
	var camps := main.get_tree().get_nodes_in_group("mine_events").filter(func(e): return e is Camp)
	var topsoil: Array = main.mine.drifts.filter(func(d): return d.layer == 0)
	assert_true(camps.any(func(c): return main.mine.world_to_cell(c.global_position) == Vector2i(topsoil[0].x1, topsoil[0].row)), "the Topsoil camp stands at its drift's end")
	Progress.path_override = ""
```

- [ ] **Step 2: Run to verify they fail.** Expected: `features` / `DRIFT_COLLAPSE_MIN` not found.

- [ ] **Step 3: Implement.** In `_carve_drifts`, after the geometry draws, for layers 1 and 2 draw the collapse length (`DRIFT_COLLAPSE_MIN`..`DRIFT_COLLAPSE_MAX`) and its start offset along the drift from `[4, length_of_drift - 5 - collapse_length]` (so at least 4 clear tiles lie at each end), fill both rows over the box with solid and paint `DEBRIS_ATLAS_COORDS`, and reserve those cells. Set `features.end` to `"camp"` for layers 0 and 1 and `"miner"` for layer 2; append the camp `event_rooms` entries; remove the `{"kind": "camp", "layers": [0]}` and `{"kind": "camp", "layers": [1]}` lines from `EVENT_ROOMS`. In `_pick_lost_miner_cell`, when a Stone drift exists set `lost_miner_cell` to its end cell and mark its floor reserved; otherwise run the existing band search unchanged. `_carve_drifts` runs before `_carve_event_rooms`, so the reordering of the rng draws for rooms is the only side effect on other content (the removed camps no longer draw); note it in the commit.

- [ ] **Step 4: Run the suite.** Expected: `93 passed, 0 failed`. The M33 camp tests (`test_camp_search_and_lift_ride`, the world "a camp per layer" count) must pass unchanged.

- [ ] **Step 5: Commit** `scripts/mine.gd tests/test_world.gd tests/test_main.gd`: "M51b: collapsed sections, camps in the drifts, the miner at the far end".

### Task 3: Playtest, docs, probe

**Files:**
- Modify: `tests/playtest.gd`, `README.md`, `ROADMAP.md`
- Verify: `tests/balance_probe.gd`

**Interfaces:**
- Consumes: `MineGrid.drifts`, `drift_cells`; harness helpers `teleport`, `_place`, `frames`, `hold`, `tap`, `check`, `shot`, `_cell`, `_in_shaft(seed)` (starts a game on a seed with the light frozen and the player invincible).

- [ ] **Step 1: Write the scenarios** in `tests/playtest.gd` and register them after `shaft_end_with_ladder`:
  - `drift_to_camp`: on seed 1001 take the Topsoil drift; teleport to its `x0` standing cell, hold toward its far end (`D` for side 1, `A` for -1) for as many frames as `length * 12 / 120 * 60` allows (walk speed 120 px/s, 16 px tiles, plus a quarter margin), `check` the player is within 2 tiles of `x1`, tap E and `check` the camp is searched. Shots at the mouth and at the camp.
  - `drift_collapse`: on seed 1001 take the Clay drift; teleport 2 tiles short of the collapse box's near edge, hold the walk key plus Space (dig forward) until the player's x passes the box's far edge, `check` every box cell is open and the player stands beyond it. Shots before and after.
  - `drift_planks`: scan seeds 1..12 once for the first drift with a plank cell (record it as `PLANK_SEED` in the harness), start there, walk the drift end to end, `check` the player reached `x1` without falling below `row + 1` (no hole).

- [ ] **Step 2: Run the playtest.** Run: `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd 2>&1 | grep -E "ok|FAIL|scenarios"`. Expected: `19 scenarios, 0 failed`. A walk that gets stuck at a one-tile step is Review Focus 1: report the cell and the geometry rather than weakening the check, and fix the carve if the cause is the drift's own floor.

- [ ] **Step 3: Docs and probe.** README: extend "The old mine" with the galleries (one per worked layer off the shaft; Topsoil and Clay end in a camp; the Clay and Stone ones have a collapsed section to dig through; the Stone one ends at the lost miner). ROADMAP: mark M51b done under M51. Run the probe and report the dive lines against the M51a numbers (dark 2:00 / Stalker 1:01 / dark 1:56) in the commit message.

- [ ] **Step 4: Commit and push** `tests/playtest.gd README.md ROADMAP.md`: "M51b: playtest the galleries - docs and probe", then `git push -u origin ccr-55f79164-j8wgrv`.
