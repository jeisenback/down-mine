# Old Workings: Galleries, Connectors and Clues Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every layer long, decayed galleries that carry loot and lead to rooms, and make worked passages visible from a distance.

**Architecture:** `MineGenerator` carves one *working* per layer: a spine (`Drift`) in layers 0 to 5, then, after the rooms exist, stepped connectors (`Connector`) to each eligible room. All new randomness uses one new generator seeded `mine_seed + 53`. Phase 3 adds clues (torches, branch-mouth posts, a fuel glint) in `MineGrid._apply` and `FuelPickup`, with no new random draws.

**Tech Stack:** Godot 4.5 GDScript; headless tests (`/opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd`); balance bots `tests/balance_probe.gd`.

**Spec:** `docs/superpowers/specs/2026-10-13-galleries-and-clues-design.md`

## Global Constraints

- New randomness: a `RandomNumberGenerator` seeded `mine_seed + 53`, nothing from the global generator. Offsets 51 and 52 keep their streams. The header of `scripts/mine_generator.gd` is updated in Task 3.
- Every layout changes in phases 1 and 2. The golden fingerprints (`tests/test_mine_golden.gd`) are re-recorded at the end of each of those phases, from the new code after the property tests pass, and the PR says so.
- No new systems, hazards or enemies. Clues reuse torches, posts and frames.
- Total fuel pickups (`FUEL_DEPOSIT_COUNT` 240) and ore pickups (`ORE_DEPOSIT_COUNT` 180) per mine do not change: gallery pickups replace cave pickups. The global generator must end in the same state shape: one `randf()` per `FuelPickup`, so the number of `FuelPickup` nodes is unchanged.
- Spine: straight two-tile tunnel, 60 to 100 tiles, at least `WORKING_EDGE_MARGIN` (4) tiles from the map edge. Shaft-fed spines clamp their length to the room beside the shaft (about 73) and never go under 60.
- Decay: layers 1 to 5 get 2 to 4 collapses of 3 to 8 tiles each, at least 4 open tiles between collapses and at each end. Posts every 5 to 8 tiles (random gap), a quarter missing. Layer 0 (Topsoil) has no collapse, as now.
- Heart: carved first, before the old mine. The layer 5 spine stops at least `HEART_STANDOFF_TILES` (10) tiles short of the Heart room. The Heart and the vault never get a connector.
- Connectors: probability `CONNECTOR_CHANCE` (0.8) per eligible room, at most `CONNECTOR_MAX_LENGTH` (70) tiles, stepped (floor changes by at most one tile at a time, every level at least 2 tiles long), skipped if they would cross another room, the vault shell, the Heart, the shaft, or a spine collapse.
- Gallery pickups: about one fuel per 12 tiles of passage, one ore per 25.
- Clues: one lit torch per `SPINE_TORCH_SPACING` (30) tiles of spine, a post pair at each connector mouth, a glint on fuel pickups that draws no random numbers.
- Constants live on `MineGrid` next to the existing `DRIFT_` ones.
- No emojis anywhere (user preference).

## Review Focus

1. **Heart near a map edge** (its column within about 20 tiles of x = 0 or 159): the deep spines must still head toward it, keep the standoff, never cross the Heart, and be skipped (not shortened below 60) when no span fits.
2. **A room directly above or below its spine** (no horizontal distance to step through): the connector must start far enough along the spine to fit its steps, or be skipped; never a vertical wall of unwalkable steps.
3. **Two rooms whose connectors would meet or overlap**: the second is skipped; connectors never share cells with each other.
4. **Cave crossings**: any open gap under a spine or connector gets a plank floor; no passage cell is left without a floor or without two open rows of headroom.
5. **Gallery pickups where the gallery is short or collapsed**: pickups never land inside a collapse, on a landing, or on a cell already holding one; if a gallery has fewer eligible floor cells than wanted, the shortfall stays in the caves so the totals hold.

---

## Phase 1: spines in every layer

### Task 1: Carve the Heart before the old mine

**Files:**
- Modify: `scripts/mine_generator.gd` (`_run`, `_carve_event_rooms`)
- Test: `tests/test_mine_golden.gd` (existing, unchanged)

**Interfaces:**
- Produces: `func _carve_event_room(room: Dictionary) -> void` (carves one `MineGrid.EVENT_ROOMS` entry, current body of the loop); `_carve_event_rooms()` carves entries 1 to end. After this task, `_layout.event_rooms[0]` is the Heart before `_carve_old_mine()` runs.

- [ ] **Step 1:** Extract the loop body of `_carve_event_rooms` into `_carve_event_room(room)`. `_run` calls it for `MineGrid.EVENT_ROOMS[0]` (the Heart) immediately before `_carve_old_mine()`; `_carve_event_rooms()` loops over the remaining entries. No other change.
- [ ] **Step 2:** Run the full suite. Expected: 324 passed, 0 failed. The golden test is the proof that no room moved (nothing draws from the room generator between the fill and the rooms, and the Heart's old-mine check sees an empty list either way). If any golden fails, stop: the premise of the spec is wrong.
- [ ] **Step 3:** Commit `Carve the Heart first (no layout change)`.

### Task 2: `Drift` carries several collapses and knows whether the shaft feeds it

**Files:**
- Modify: `scripts/drift.gd`, `scripts/mine_generator.gd` (`_collapse_drift`), `tests/test_world.gd:757`, `tests/playtest.gd:570`
- Test: `tests/test_mine_golden.gd` (unchanged), `tests/test_mine_generator.gd`

**Interfaces:**
- Produces: `Drift.collapses: Array[Rect2i]` (replaces `collapse`); `Drift.from_shaft := true`; `to_dict()` still writes `"collapse": collapses[0]` if any else `Rect2i()` so the recorded fingerprints stay valid; `Drift.length()`, `cells()` unchanged.

- [ ] **Step 1:** Add the two fields; `_collapse_drift` appends to `collapses` instead of assigning. Update the two call sites to read `collapses[0]`.
- [ ] **Step 2:** Add to `tests/test_mine_generator.gd` `test_a_drift_keeps_its_collapses_in_a_list`: for seed 1001, the Stone and Clay drifts have `collapses.size() == 1` and the old fingerprint key still holds `collapses[0]`; Topsoil has an empty list and `to_dict()["features"]["collapse"] == Rect2i()`.
- [ ] **Step 3:** Run the full suite. Expected: all pass, goldens unchanged.
- [ ] **Step 4:** Commit `Drift: a list of collapses and a from_shaft flag (no layout change)`.

### Task 3: Long, decayed spines off the shaft (layers 0 to 2)

**Files:**
- Modify: `scripts/mine.gd` (constants), `scripts/mine_generator.gd` (header, `_carve_drifts` becomes `_carve_workings`, `_collapse_drift` becomes `_decay_spine`, `old_mine_rects`)
- Create: `tests/gallery_checks.gd`
- Test: `tests/test_mine_generator.gd`

**Interfaces:**
- Produces on `MineGrid`: `SPINE_MIN_LENGTH := 60`, `SPINE_MAX_LENGTH := 100`, `WORKING_EDGE_MARGIN := 4`, `SPINE_COLLAPSES_MIN := 2`, `SPINE_COLLAPSES_MAX := 4`, `SPINE_COLLAPSE_MIN := 3`, `SPINE_COLLAPSE_MAX := 8`, `SPINE_POST_GAP_MIN := 5`, `SPINE_POST_GAP_MAX := 8`, `SPINE_POST_MISSING_CHANCE := 0.25`; remove `DRIFT_MIN_LENGTH`, `DRIFT_MAX_LENGTH`, `DRIFT_POST_SPACING`, `DRIFT_COLLAPSE_MIN`, `DRIFT_COLLAPSE_MAX` (keep `DRIFT_END_CLEAR := 4`).
- Produces: `MineGenerator._work_rng: RandomNumberGenerator` seeded `mine_seed + 53`; `func _carve_workings() -> void` (called where `_carve_drifts(rng)` was; draws only from `_work_rng`, in layer order); `func _decay_spine(drift: Drift) -> void`; `old_mine_rects` unchanged in shape.
- Produces (test helper) `tests/gallery_checks.gd`, `class_name GalleryChecks`, all static:
  - `passage_problems(layout: MineLayout, drift: Drift) -> Array[String]`: every column of the spine has the standing row and the row above open (except inside its collapses), a solid cell under the standing row, and consecutive columns have the same floor row.
  - `collapse_problems(drift: Drift) -> Array[String]`: collapse count and sizes within the constants, at least `DRIFT_END_CLEAR` open tiles at each end and between collapses.

- [ ] **Step 1: Write failing tests** in `tests/test_mine_generator.gd`, each looping over the 31 golden `SEEDS` via `shared_layout(seed)`:
  - `test_spines_are_long`: for drifts with `from_shaft`: `length() >= 60 and length() <= 100`.
  - `test_spines_are_walkable_and_decayed`: `GalleryChecks.passage_problems(...).is_empty()` and `collapse_problems(...).is_empty()` for each shaft-fed drift; layer 0 has `collapses.is_empty()`, layers 1 and 2 have 2 to 4.
  - `test_spines_still_leave_the_shaft_at_the_landing`: each shaft-fed drift's first cell is `shaft_column() + side * (SHAFT_WIDTH / 2 + 1)` and the landing plank exists (move the existing landing assertions here if they are only in `test_world`).
  - `test_work_rng_is_seeded_from_the_mine_seed_plus_53`: two generations of one seed give equal drifts (determinism), and generating seed 1001 does not change `shaft_end_row` or `old_ladder_rows` compared with the values in the pre-change golden run recorded in the test as literals.
- [ ] **Step 2:** Run them. Expected: FAIL (lengths 24 to 40, one collapse).
- [ ] **Step 3: Implement** `_carve_workings` for layers 0 to 2: same row choice window and side rule as the old `_carve_drifts` for layers 0 and 1; layer 2's side is the one facing the Heart (`+1` if the Heart room's centre x is greater than `shaft_column()`, else `-1`); length drawn 60 to 100 then clamped to the room on that side (`x` inside `[WORKING_EDGE_MARGIN, GRID_WIDTH - 1 - WORKING_EDGE_MARGIN]`); floors, planks, `room_cells`, `reserved_floors` and the landing as in the old code; posts placed with a random gap and a quarter skipped; `_decay_spine` places the collapses by rejection sampling (up to 20 tries each) keeping the clear-gap rule, and skips a collapse that cannot fit. End features unchanged (camp at layers 0 and 1, `"miner"` at layer 2). Update the generator header: stream `+53` for the workings.
- [ ] **Step 4:** Fix call sites that assumed the old numbers (`tests/test_world.gd:702-790`, `tests/test_main.gd:448-460`, `tests/playtest.gd` drift helpers): they must use `from_shaft` drifts and `collapses[0]`; where a test relied on a 24-tile drift, use the real `length()`.
- [ ] **Step 5:** Run the new tests and then the full suite. The golden test will now fail for every seed: that is expected in this phase; leave it failing until Task 6 and run the suite with `grep -v golden` filtering only to check everything else is green.
- [ ] **Step 6:** Commit `Spines: long, decayed galleries off the shaft`.

### Task 4: Free-standing workings in layers 3 to 5, Heart-ward

**Files:**
- Modify: `scripts/mine_generator.gd` (`_carve_workings`), `scripts/mine.gd` (constant)
- Test: `tests/test_mine_generator.gd`, `tests/gallery_checks.gd`

**Interfaces:**
- Consumes: `Drift.from_shaft`, `_work_rng`, `_decay_spine` (Task 3); the Heart's `EventRoom.rect` (Task 1).
- Produces on `MineGrid`: `HEART_STANDOFF_TILES := 10`; a drift for each of layers 3 to 5 with `from_shaft == false`, `end_kind == ""`. Static `GalleryChecks.heads_toward(drift: Drift, heart: Rect2i) -> bool`.

- [ ] **Step 1: Write failing tests** (31 seeds):
  - `test_every_layer_has_a_working`: `layout.drifts.map(layer)` contains 0 to 5 exactly once each, except a layer is allowed to be missing only when the test records why for that seed (none expected; start strict).
  - `test_deep_spines_are_free_standing_and_walkable`: layers 3 to 5 have `from_shaft == false`, length 60 to 100, `passage_problems` empty, `collapse_problems` empty, no cell inside the shaft rect.
  - `test_deep_spines_head_toward_the_heart`: `GalleryChecks.heads_toward` for layers 3 to 5, and the layer 5 spine's near end is at least 10 tiles from `heart.rect` horizontally and the spine's box does not intersect `heart.rect.grow(1)`.
  - `test_spines_keep_off_the_rooms`: no spine box intersects `shaft_rect`'s neighbours or the Heart room; rooms carved later keep out of all spine boxes (existing `test_event_rooms_and_pickups_keep_out_of_the_drifts` still passes).
  - `test_spines_work_with_the_heart_near_an_edge`: build a `MineGenerator` state in-test with a forced Heart rect at x = 3 and at x = 140 and call the span helper `MineGenerator.spine_span(heading: int, anchor: Rect2i, length: int) -> Vector2i` (returns first and last x, or `Vector2i(-1, -1)` when it cannot fit): assert it never overlaps `anchor` and returns `(-1, -1)` when the length cannot fit.
- [ ] **Step 2:** Run them. Expected: FAIL.
- [ ] **Step 3: Implement** the deep loop in `_carve_workings`: row uniformly in the layer band with 3 rows of slack and the Heart room avoided (up to 20 row tries); heading is `+1` when the Heart's centre x is at least `GRID_WIDTH / 2`, else `-1`; start = edge margin plus up to 10 slack on the far side; `spine_span` clamps the length so the layer 5 spine stops `HEART_STANDOFF_TILES` short of the Heart and every spine stays inside the margins; a layer whose span is under 60 gets no working (the test reports it). Floors, planks and `room_cells` as the shaft-fed code; ends are plain rock.
- [ ] **Step 4:** Run the new tests and the suite (golden still expected to fail).
- [ ] **Step 5:** Commit `Free-standing workings in the deep layers, heading for the Heart`.

### Task 5: Pickups along the galleries

**Files:**
- Modify: `scripts/mine_generator.gd` (`_scatter_pickups` and its call), `scripts/mine.gd` (constants)
- Test: `tests/test_mine_generator.gd`

**Interfaces:**
- Consumes: `Drift.cells()`, `_work_rng`.
- Produces on `MineGrid`: `GALLERY_FUEL_TILES := 12`, `GALLERY_ORE_TILES := 25`; `func _gallery_pickups() -> Dictionary` returns `{"fuel": Array[Vector2i], "ore": Array[Vector2i]}` of standing cells on spine floors outside collapses, landings and each other, drawn from `_work_rng`; `_scatter_pickups(floor_cells, gallery)` takes fewer cave pickups by exactly the gallery counts.

- [ ] **Step 1: Write failing tests** (31 seeds): `test_gallery_pickups_sit_on_gallery_floors` (every gallery fuel and ore cell is a spine standing cell, has a solid cell below, is not inside a collapse and is not the landing); `test_totals_are_unchanged` (`fuel_cells.size()` and `ore_cells.size()` equal the old totals, `min(constant, floor_cells.size())` in the same way as before); `test_gallery_pickups_do_not_double_up` (no cell appears twice across fuel and ore); `test_a_short_gallery_leaves_the_shortfall_in_the_caves` using a hand-built `Drift` with a tiny usable floor passed to `_gallery_pickups`.
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** Counts are `spine_length / GALLERY_FUEL_TILES` and `/ GALLERY_ORE_TILES` per spine, limited by usable cells; gallery cells go into `fuel_cells` and `ore_cells` first (ore entries keep `{"cell", "value"}` with the layer's `ore` value), and `_scatter_pickups` reduces its cave counts by the gallery counts so the totals hold.
- [ ] **Step 4:** Run the new tests and the suite (golden still expected to fail).
- [ ] **Step 5:** Commit `Gallery pickups replace cave pickups`.

### Task 6: Re-record, measure, document (phase 1 PR)

**Files:**
- Modify: `tests/test_mine_golden.gd` (GOLDEN), `ROADMAP.md`, `README.md`
- Test: whole suite

- [ ] **Step 1:** Print each golden hash from the new code with a throwaway script (the same call `test_mine_golden.gd` uses) and paste them in. Run the golden test: pass.
- [ ] **Step 2:** Time generation: `MineGenerator.generate(1001)` within 0.1 s of the 0.27 s measured before (so under 0.37 s). If over, profile before continuing.
- [ ] **Step 3:** Run `tests/balance_probe.gd -- heart` and `-- trip`; record before/after numbers (after PR #95: Heart 5 of 6 seeds, trip fuel left 53 / 46-48 / 40-41 / 30-33) in the PR description. Not a gate.
- [ ] **Step 4:** ROADMAP M80 and README entry: layouts changed on purpose, goldens re-recorded, what the spines are now. Run the full suite: green. Commit, push, open the PR, subscribe, wait for CI, ask before merging.

---

## Phase 2: connectors to rooms

### Task 7: `Connector` and `_carve_connectors`

**Files:**
- Create: `scripts/connector.gd`
- Modify: `scripts/mine_layout.gd`, `scripts/mine_generator.gd`, `scripts/mine.gd` (constants, `_apply` copy), `tests/mine_fingerprint.gd`, `tests/test_mine_golden.gd` (field list)
- Test: `tests/test_mine_generator.gd`, `tests/gallery_checks.gd`

**Interfaces:**
- Produces: `class_name Connector` with `room: EventRoom`, `layer: int`, `cells: Array[Vector2i]` (standing cells, one per column, start to end), `mouth: Vector2i` (the cell on the spine where it leaves), `collapses: Array[Rect2i]`, `to_dict() -> Dictionary`; `MineLayout.connectors: Array[Connector]`; `MineGrid.connectors` (copied in `_apply` like `drifts`); `MineGrid.CONNECTOR_CHANCE := 0.8`, `CONNECTOR_MAX_LENGTH := 70`, `CONNECTOR_LEVEL_MIN := 2`; `MineGenerator._carve_connectors() -> void`, called right after `_carve_event_rooms()`; static `MineGenerator.connector_start(room_edge_x: int, dy: int, spine_x0: int, spine_x1: int) -> int` (the start column on the spine, or `-1`).
- Produces test helper: `GalleryChecks.connector_problems(layout: MineLayout, c: Connector) -> Array[String]`.

Rules the implementer follows (decisions the spec leaves open): a connector leaves the spine at the column `connector_start` returns: the spine column whose horizontal distance to the room's near edge is `2 * abs(dy) + CONNECTOR_LEVEL_MIN` (dy = room standing row minus spine standing row), trying the side of the room that puts that column on the spine and nearer the spine's middle; if neither side is on the spine, no connector. The floor row then changes by one every `CONNECTOR_LEVEL_MIN` (or more, spread evenly) columns. At a step column the passage opens one extra row on the higher side so the step is three rows high there. Eligible rooms: any room in a layer with a spine except kinds `vault`, `heart` and the lift; the chance is drawn once per room, in `EVENT_ROOMS` order, from `_work_rng`.

- [ ] **Step 1: Write failing tests** (31 seeds, plus targeted ones):
  - `test_connector_start_fits_the_steps` (unit): `connector_start(100, 5, 40, 90)` is a column at distance 12 from 100 on the spine (`88`); `connector_start(100, 5, 40, 80)` is `-1`; `connector_start(100, 0, 40, 99)` is `98`.
  - `test_connectors_are_walkable`: `connector_problems` empty: two open rows above a solid floor at every column, consecutive floors differ by at most 1, each level at least 2 columns, length at most 70, ends at the room's near edge column.
  - `test_connectors_skip_the_vault_the_heart_and_the_lift`: no connector's `room.kind` is `vault`, `heart` or `lift`.
  - `test_connectors_do_not_cross`: no cell is shared between two connectors, a connector and a room other than its own, the shaft rect, or any spine collapse; and the vault shell cells are untouched.
  - `test_every_connected_room_is_reachable_on_foot_from_its_spine`: flood fill from the spine's first standing cell over passage cells (step up at most 1, drop any height) reaches the room's centre cell.
  - `test_cave_crossings_are_planked`: for connector cells, any floor cell that was open before carving is in `plank_cells`.
  - `test_the_skip_rate_is_reported`: not an assertion; prints how many eligible rooms across the 31 seeds got no connector, so the spec's open question (is 70 enough?) is answered with a number. Include the number in the PR.
- [ ] **Step 2:** Run. Expected: FAIL (no `Connector`).
- [ ] **Step 3: Implement** `Connector`, the layout field, `_carve_connectors` and `connector_start`; carve cells open, floor with rock or planks, add all cells to `room_cells` and floors to `reserved_floors`, planks to `plank_cells`; add `connectors` to `MineFingerprint.FIELDS` and the golden field list; extend `old_mine_rects` callers where later steps (pickups, lost miner) need to avoid connectors; add one or no collapse per connector in layers 1 to 5 (`_decay_connector`).
- [ ] **Step 4:** Run the new tests and the suite (golden expected to fail).
- [ ] **Step 5:** Commit `Connectors: stepped passages from the spines to the rooms`.

### Task 8: Re-record, measure, document (phase 2 PR)

- [ ] **Step 1:** Re-record the 31 goldens as in Task 6 and check generation time stays under 0.4 s.
- [ ] **Step 2:** Re-run both bots and record the numbers; report the skip rate from Task 7. If more than a quarter of eligible rooms get no connector, raise `CONNECTOR_MAX_LENGTH` in the same PR and say so.
- [ ] **Step 3:** ROADMAP M81 and README entry; full suite green; PR; ask before merging.

---

## Phase 3: clues

### Task 9: Lit torches along the spines, posts at connector mouths

**Files:**
- Modify: `scripts/torch_site.gd` (doc only: a third `where`), `scripts/mine_generator.gd` (`_place_torches`, a `_mark_mouths` step), `scripts/mine.gd` (constant)
- Test: `tests/test_mine_generator.gd`

**Interfaces:**
- Produces on `MineGrid`: `SPINE_TORCH_SPACING := 30`; `TorchSite` with `where == "gallery"`; `MineLayout.decor` gains `POST` cells in pairs beside each connector's `mouth` (one column either side, both rows).

- [ ] **Step 1: Write failing tests** (31 seeds): `test_each_spine_has_a_torch_every_30_tiles` (count of `"gallery"` torches on a spine is `length / 30` rounded down, at least 1 for 60-tile spines, spaced at least 25 apart, each on an open standing cell outside collapses); `test_gallery_torches_use_no_global_randomness` (the global generator's end state after `generate` is unchanged from a run with the torches disabled by a constant: `SPINE_TORCH_SPACING = 0` path, or compare the `randi()` fingerprint term before and after); `test_connector_mouths_are_framed` (for each connector, `decor` has `POST` at the cells beside `mouth` in both rows); `test_gallery_torches_are_in_the_fingerprint` (torch list includes them).
- [ ] **Step 2:** Run. Expected: FAIL.
- [ ] **Step 3: Implement.** Torches are placed from `_work_rng` (not the `+52` stream), after the cave torches, as `TorchSite.new(cell, "gallery")`; `MineGrid._apply` already instantiates `layout.torches`, so check that `Torch` placement code does not assume `"shaft"` or `"cave"`. Posts go in `decor` as `MineLayout.Decor.POST`.
- [ ] **Step 4:** Run the new tests and the suite (golden expected to fail: re-record in Task 11).
- [ ] **Step 5:** Commit `Clues: lit spines and framed branch mouths`.

### Task 10: Fuel glint

**Files:**
- Modify: `scripts/fuel_pickup.gd`, `scenes/FuelPickup.tscn` (or the art node it uses)
- Test: `tests/test_world.gd`

**Interfaces:**
- Produces: a visible twinkle on `FuelPickup` that never calls `randf`/`randi` (the existing `_seed_stream_draw` stays exactly as it is).

- [ ] **Step 1: Write failing test** `test_the_fuel_glint_draws_no_random_numbers`: seed the global generator, read `randi()`, reseed, instantiate and add a `FuelPickup` (its `_seed_stream_draw` consumes one draw), process 10 frames, then read `randi()`: it equals the second value from a control run with no frames processed. And `test_fuel_pickups_still_collect` (existing behavior: `body_entered` adds `fuel_amount` and frees).
- [ ] **Step 2:** Run. Expected: the first test passes trivially if nothing draws; write it so it fails first by also asserting `get_node_or_null("Glint") != null` and `Glint.visible`.
- [ ] **Step 3: Implement** a small child node `Glint` (a `Sprite2D` or `Polygon2D`) animated by `_process` using `sin(Time.get_ticks_msec())` phase only; no random calls.
- [ ] **Step 4:** Run the tests and the suite. Commit `Clues: a glint on fuel pickups`.

### Task 11: Re-record, play, document (phase 3 PR)

- [ ] **Step 1:** Re-record the goldens (torches and decor changed). Run the playtest scenarios locally if possible (`tests/playtest.gd` under xvfb); at minimum, CI runs them.
- [ ] **Step 2:** Take a screenshot of one spine with torches and one connector mouth from the playtest harness into the PR so the clues can be judged from pictures.
- [ ] **Step 3:** ROADMAP M82 and README entry, including the open balance question (lit spines stop decay: thin the torches if the mine feels too safe). Full suite green; PR; ask before merging.
- [ ] **Step 4:** Final fresh whole-branch review (one reviewer on the most capable model, given the spec and this plan), fix findings, then close the loop on issue #26 with a comment listing M80 to M82.

---

## Self-review

- **Spec coverage:** spines in all layers, decay, Heart-ward bias, standoff, Heart-first (Tasks 1, 3, 4); loot and unchanged totals (5); connectors, exceptions, cap, steps, skip rule, collapses (7); torches, mouth posts, glint (9, 10); fingerprints, determinism, `+53` stream (3, 6, 8, 11); reachability and generation time (7, 6); bots (6, 8). The spec's "Out of scope" items appear in no task.
- **Decisions the spec left open and this plan fixes:** shaft-fed spines clamp to the room beside the shaft (the 100-tile maximum cannot fit there); `WORKING_EDGE_MARGIN` is 4; connector start column rule, three-row notch at steps, eligible-room list, one random draw per room; gallery torches draw from the `+53` stream, not `+52`.
- **Type consistency:** `Drift.collapses`, `from_shaft`, `end_kind` (Tasks 2 to 5, 7, 9); `Connector.room/cells/mouth/collapses` (7, 9); `GalleryChecks` helpers named once each; `_work_rng` is the only new random source.
- **Proportion:** the plan is longer than the spec because it names every test; the code bodies are left to the implementer except where a rule had to be decided.
