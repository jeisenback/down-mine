# M51c The Works' Contents Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Finish the old mine: the lift moves into the shaft at the bottom of Clay (the old cage), and the journal's last page marks where the shaft's collapse ends so the way home from the hostile layers can be found.

**Architecture:** The lift becomes an `event_rooms` entry written by `MineGrid._carve_old_mine` (like the drift camps in M51b), standing on a small plank cage floor at the shaft's edge so the ladder column stays open. `Main` gets one method that reads the next journal page and, on the last one, adds the shaft's depth; `Camp` calls it. Camps and the lost miner already moved into the galleries in M51b.

**Tech Stack:** Godot 4.5, GDScript. Tests are `tests/test_*.gd` extending `TestCase`, run with `godot --headless --fixed-fps 60 -s tests/run_tests.gd` (the Godot binary for this session is at `/tmp/claude-0/-home-user-down-mine/5ebdb75c-4140-522a-8fa8-1480d465a6fb/scratchpad/godot/godot`; run `--headless --import` once after adding scripts). Baseline: 94 passed. Playtest: `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd`, baseline 20 scenarios.

**Spec:** `docs/superpowers/specs/2026-10-09-run-loop-redesign-design.md`, section "The old mine" ("The lift sits in the shaft at the bottom of Clay (the old cage), replacing its random room"; "the bottom of the shaft ... is marked on the journal's last page"; the playtest scenarios).

## Global Constraints

- Values from the spec: the lift sits in the shaft at the bottom of Clay and replaces its random room (`{"kind": "lift", "layers": [2, 3]}` leaves `EVENT_ROOMS`); the journal's last page marks the shaft's bottom. Deterministic from the seed.
- Consequence to carry, not fix: Clay is a quiet layer, so repairing the lift there makes no noise that anything hears (`NoiseMeter` ignores sounds made in quiet layers). `REPAIR_NOISE` stays as a constant; the README says the repair is quiet. The ride still takes the player and escorts to the surface once.
- The cage floor is two things only: a plank under the lift's cell at the shaft's edge column (like a drift landing), and nothing in the centre column, so the old ladder and falls through the shaft are not blocked.
- The shaft's open part may stop above Clay's last row (the collapse can sit in Stone's first rows); the lift row is capped at `shaft_open_rows().y - 2`.
- The journal text lives in `Progress.JOURNAL` (shared across runs and saves); the depth is added at read time from the current run's mine, so no save format changes.
- No emojis anywhere. Every commit message ends with the two attribution lines used on this branch (see `git log -1`).

## Review Focus

Inputs the spec implies but no task's own happy path exercises, most likely to bite first. Each has its test in the owning task.

1. The lift must be usable from the ladder and from a fall through the shaft: in `EVENT_RANGE` (24 px) of the ladder column, open above a floor, clear of the Clay gallery's landing. Task 1 and Task 3.
2. A seed where the shaft's open part ends above Clay's last row, and a Clay gallery within 3 rows of the lift's natural row. Task 1.
3. Repairing the lift now makes no noise: the old test asserted it was loud. Task 1.
4. Players whose saved journal is already complete never see the shaft's depth (the last page is read once). The text must still be sound when a later read returns "water-stained"; nothing may append a depth to that message. Task 2.
5. The depth is in the HUD's depth units (`row - SURFACE_ROWS`), not rows. Task 2.

---

### Task 1: The lift in the shaft

**Files:**
- Modify: `scripts/mine.gd` (`EVENT_ROOMS`, `_carve_old_mine` / a new `_place_lift`)
- Modify: `tests/test_world.gd` (the room test), `tests/test_main.gd` (the lift test)
- Test: `tests/test_world.gd`

**Interfaces:**
- Consumes: M51a/M51b's `shaft_open_rows()`, `shaft_column()`, `_layer_rows(1)`, `drifts`, `_plank_cells`, `_room_cells`, `_reserved_floors`, and `_carve_old_mine`'s local `rng` (draws after the drifts', so every earlier draw is unchanged).
- Produces: `func MineGrid._place_lift(solid: Array, rng: RandomNumberGenerator) -> void`, called at the end of `_carve_old_mine`; one `event_rooms` entry `{"kind": "lift", "cell": Vector2i, "rect": Rect2i, "shaft": true}` with `cell = Vector2i(shaft_column() + side, row)`; `const MineGrid.LIFT_ROWS_FROM_CLAY_BOTTOM := 1`.
- Row rule: `row = mini(_layer_rows(1).y - LIFT_ROWS_FROM_CLAY_BOTTOM, shaft_open_rows().y - 2)`; if a Clay gallery's `row` is within 3 rows of it, `row = gallery.row - 4`. `side = rng.randi_range(0, 1) * 2 - 1`. The cell below `cell` becomes a plank (solid, in `_plank_cells`, `_room_cells`, `_reserved_floors`); `cell` joins `_room_cells`.

- [ ] **Step 1: Write the failing tests.** In `tests/test_world.gd`:

```gdscript
func test_the_lift_stands_in_the_shaft_at_the_bottom_of_clay() -> void:
	for s in [1001, 1, 2, 3, 4, 5, 6, 7, 8, 44, 89]:
		var mine := _mine_with_seed(s)
		var lifts: Array = mine.event_rooms.filter(func(r): return r.kind == "lift")
		assert_eq(lifts.size(), 1, "seed %d: one lift" % s)
		var cell: Vector2i = lifts[0].cell
		var col := mine.shaft_column()
		assert_true(absi(cell.x - col) == 1, "seed %d: on the shaft's edge column, ladder column left open" % s)
		assert_eq(mine.layer_index_at_world(mine.cell_to_world(cell)), 1, "seed %d: in Clay" % s)
		assert_true(cell.y >= mine._layer_rows(1).y - 8, "seed %d: near Clay's bottom (row %d)" % [s, cell.y])
		assert_true(cell.y <= mine.shaft_open_rows().y - 2, "seed %d: inside the open shaft" % s)
		assert_true(not mine.is_solid(cell) and not mine.is_solid(cell + Vector2i.UP), "seed %d: open cage" % s)
		assert_eq(mine.get_cell_atlas_coords(0, cell + Vector2i.DOWN), MineGrid.PLANK_ATLAS_COORDS, "seed %d: a plank cage floor" % s)
		assert_true(not mine.is_solid(Vector2i(col, cell.y + 1)), "seed %d: the centre column stays open under it" % s)
		for d in mine.drifts:
			if d.layer == 1:
				assert_true(absi(d.row - cell.y) > 3, "seed %d: the Clay gallery (row %d) is clear of the lift (row %d)" % [s, d.row, cell.y])
```

In `tests/test_world.gd`'s existing `test_mine_carves_event_rooms`, replace the "lift below the quiet layers" assertion with `assert_true(MineGrid.LAYERS[mine._layer_index_for_row(lifts[0].cell.y)].quiet, "the lift is in Clay, a quiet layer")`. In `tests/test_main.gd`'s `test_camp_search_and_lift_ride` replace the lines that move the base beside the lift and assert `noise > 0.0` ("repair is loud") with `assert_eq(main.noise_meter.noise, 0.0, "Clay is quiet: nothing hears the repair")`, and drop the "below the quiet layers" comment.

- [ ] **Step 2: Run to verify they fail.** Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd 2>&1 | grep -E "FAIL|Parse Error"`. Expected: `test_the_lift_stands_in_the_shaft...` fails (the lift is in a room in Stone or Slate); the two edited tests fail on the new assertions.

- [ ] **Step 3: Implement** `_place_lift` in `scripts/mine.gd` to the interface above, call it at the end of `_carve_old_mine` (after `_carve_drifts`), and delete the `{"kind": "lift", "layers": [2, 3]}` line from `EVENT_ROOMS`. `Main._spawn_events` needs no change: it already places any `event_rooms` entry by `cell`.

- [ ] **Step 4: Run the suite.** Expected: `95 passed, 0 failed`. Every other lift and event test passes unchanged.

- [ ] **Step 5: Commit** `scripts/mine.gd tests/test_world.gd tests/test_main.gd`: "M51c: the lift moves into the shaft at the bottom of Clay".

### Task 2: The journal's last page marks the shaft

**Files:**
- Modify: `scripts/main.gd` (`read_journal_page`), `scripts/camp.gd`
- Test: `tests/test_main.gd`

**Interfaces:**
- Consumes: `Progress.read_journal_page() -> String`, `Progress.journal_read`, `Progress.JOURNAL`, `MineGrid.shaft_end_row`.
- Produces: `func Main.read_journal_page() -> String`: calls `progress.read_journal_page()`; when that call just read the final page (`progress.journal_read == Progress.JOURNAL.size()` afterwards and the returned text starts with `"Journal "`) it appends `" In the margin: the old shaft ends in a collapse at depth %d. Dig up into it from below." % (mine.shaft_end_row - MineGrid.SURFACE_ROWS)`; every other result is returned unchanged. `Camp.use` shows `main.read_journal_page()` instead of `main.progress.read_journal_page()`.

- [ ] **Step 1: Write the failing test** in `tests/test_main.gd`:

```gdscript
func test_the_last_journal_page_marks_the_shafts_end() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var depth: int = main.mine.shaft_end_row - MineGrid.SURFACE_ROWS
	main.progress.journal_read = Progress.JOURNAL.size() - 2
	var earlier: String = main.read_journal_page()
	assert_true(not earlier.contains("depth"), "an ordinary page carries no pointer")
	var last: String = main.read_journal_page()
	assert_true(last.contains("Last page"), "that read the last page")
	assert_true(last.contains("depth %d" % depth), "and it names the collapse's depth (%d)" % depth)
	var after: String = main.read_journal_page()
	assert_true(not after.contains("depth"), "afterwards the journal is unreadable, with no pointer")
	Progress.path_override = ""
```

- [ ] **Step 2: Run to verify it fails.** Expected: `read_journal_page` not found on Main.

- [ ] **Step 3: Implement** `Main.read_journal_page` and switch `Camp.use` to it.

- [ ] **Step 4: Run the suite.** Expected: `96 passed, 0 failed`.

- [ ] **Step 5: Commit** `scripts/main.gd scripts/camp.gd tests/test_main.gd`: "M51c: the journal's last page marks where the shaft ends".

### Task 3: Playtest, docs, probe

**Files:**
- Modify: `tests/playtest.gd`, `README.md`, `ROADMAP.md`
- Verify: `tests/balance_probe.gd`

**Interfaces:**
- Consumes: the lift's `event_rooms` cell via the `Lift` node in group `mine_events`; harness helpers `_in_shaft(seed)`, `_place`, `tap`, `hold`, `check`, `shot`, `_cell`, `_fill`, `key_event`.

- [ ] **Step 1: Write the scenarios** in `tests/playtest.gd`, registered after `drift_from_the_ladder`:
  - `shaft_lift_ride`: seed 1001; find the `Lift` node, give the player 100 ore, `_place` the player on the shaft's ladder column at the lift's row (`Vector2i(shaft_column(), lift_cell.y)`), tap E to repair (`check` the state is READY and ore dropped by 30), tap E to ride, `check` the player is at the surface (`_cell().y < MineGrid.SURFACE_ROWS`) and the lift is USED. Shots before and after.
  - `shaft_from_below`: seed 1001; open a pocket under the collapse in the shaft column with `_fill` (cells `end_row + 1 .. end_row + 3` open, `end_row + 4` solid), `_place` the player at `end_row + 3`, hold Space and W (dig up and jump) for 600 frames, `check` the player reached the open shaft (`_cell().y <= shaft_open_rows().y`). If the dig-up cycle cannot get through 6 rows in that time, report the row reached and the frames used rather than weakening the check; the journal pointer is only useful if the climb is possible.

- [ ] **Step 2: Run the playtest.** Run: `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd 2>&1 | grep -E "ok|FAIL|scenarios"`. Expected: `22 scenarios, 0 failed`.

- [ ] **Step 3: Docs and probe.** README: replace "An old lift sits in Stone or Slate: repair it for 30 ore (loud)" with the lift standing in the shaft at the bottom of Clay (30 ore, quiet because Clay is, one ride to the surface with escorts); add the journal's last page to the camp text. ROADMAP: mark M51c and M51 done and list M52 as next. Run the probe and report the dive, dark and idle lines against the M51b ones (dive 2:03 / 2:00 / 2:05, dark 1:35, idle 6:59) in the commit message.

- [ ] **Step 4: Commit and push** `tests/playtest.gd README.md ROADMAP.md`: "M51c: playtest the lift and the climb from below - docs and probe", then `git push -u origin ccr-55f79164-j8wgrv`.
