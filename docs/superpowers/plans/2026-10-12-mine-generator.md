# Pure Mine Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move seed-to-layout generation out of `MineGrid` into a node-free `MineGenerator` returning a `MineLayout`, with every existing seed producing an identical mine, then speed up smoothing against the same safety net.

**Architecture:** `MineGenerator.generate(seed)` returns plain data (`MineLayout`); `MineGrid._ready` builds the tileset, generates, and applies the layout (`set_cell`, decor, pickup and torch nodes), copying it into the same fields it has today so no caller changes. A golden-seed fingerprint test, recorded from the current code before anything moves, is the safety net for both stages.

**Tech Stack:** Godot 4.5 GDScript; headless test runner `tests/run_tests.gd` (`/opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd`).

**Spec:** `docs/superpowers/specs/2026-10-12-mine-generator-design.md`

## Global Constraints

- Every existing seed produces exactly the same mine (tiles, decor, every list and field, pickup and torch nodes in the same child order).
- Random sources unchanged: local generator seeded `mine_seed`; `mine_seed + 51` (old mine); `mine_seed + 52` (torches); global `seed(mine_seed)` followed by `shuffle()` in the same place. Issue #76 stays as is.
- No constant moves: `MineGrid.GRID_WIDTH`, `LAYERS`, `EVENT_ROOMS`, `*_ATLAS_COORDS`, ... stay on `MineGrid`.
- `drifts`, `event_rooms`, `torches` stay plain dictionaries (typed classes are #75).
- No gameplay change. Seed resolution (`next_seed`, launch option, random seed) stays in `MineGrid`; the generator takes an explicit seed.
- Each PR: full unit suite 0 failed, `tests/playtest.gd` 0 failed, ROADMAP entry. Commit generated `.uid` files.

## Review Focus

- A seed outside the golden list (random seeds up to 999999): layout invariants must still hold. Task 3 loops `generate` over seeds 1..40 and checks them.
- Two `MineGrid`s from the same seed must not share sets or arrays (digging or claiming floors in one must not change the other). Task 2 pins it.
- The generator must create no nodes (pickups and torches are described as cells, not instantiated). Task 3 pins it with the node count.
- The "a fuel pickup consumes exactly one global random number" test and `test_same_seed_builds_the_same_mine` must pass unchanged (global-RNG order).
- Gas pockets chosen from the tile read-back: the golden fingerprint includes every gas cell (Task 1 fingerprint covers both tile layers).

---

## Stage 1 (PR 1): golden net, extraction, scene-free tests

### Task 1: Golden fingerprints, recorded from the current code

**Files:**
- Create: `tests/mine_fingerprint.gd`, `tests/test_mine_golden.gd`
- Modify: none in `scripts/`

**Interfaces:**
- Produces: `MineFingerprint.of(mine: MineGrid) -> String` (hex SHA-256) in `tests/mine_fingerprint.gd` (`class_name MineFingerprint`); `MineFingerprint.FIELDS: Array` (names of the `MineGrid` members it covers).
- Produces: `GOLDEN: Dictionary` (seed int -> fingerprint String) in `tests/test_mine_golden.gd`, over seeds `[1..20, 22, 31, 33, 35, 44, 51, 55, 89, 98, 1001, 4242]`.

- [ ] **Step 1: Write `MineFingerprint.of`.** It hashes, in order: for every cell of the grid, `get_cell_atlas_coords(0, cell)` and `get_cell_atlas_coords(DECOR_LAYER, cell)`; `mine_seed`, `shaft_end_row`, `lost_miner_cell`, `old_ladder_rows`, `drifts`, `event_rooms`, `torches` via `var_to_str`; the sets `_room_cells`, `_reserved_floors`, `_plank_cells`, `_debris_cells`, `_vault_cells` as sorted cell lists (sort by x then y); `_spare_floor_cells` in order; and for each child of the mine that is a `FuelPickup`, `OrePickup` or `Torch`: script class name, `position`, and `value` if present, in child order. Use `HashingContext` SHA-256 over the joined string.
- [ ] **Step 2: Write `test_mine_golden.gd`** with `GOLDEN = {}` empty and two tests: `test_every_golden_seed_matches` (for each seed: `shared`-style fresh `MineGrid` via `MineGrid.next_seed = s` and `add(MineScene.instantiate())`; assert `MineFingerprint.of(mine) == GOLDEN[s]`, message names the seed), and `test_the_fingerprint_covers_every_layout_field` (asserts `MineFingerprint.FIELDS` contains each of `mine_seed, shaft_end_row, lost_miner_cell, old_ladder_rows, drifts, event_rooms, torches, _room_cells, _reserved_floors, _plank_cells, _debris_cells, _vault_cells, _spare_floor_cells`).
- [ ] **Step 3: Record.** Run a scratch script (scratchpad, not committed) that prints `MineFingerprint.of` for each seed in the list, from the current unmodified `scripts/`; paste the output into `GOLDEN`.
- [ ] **Step 4: Verify** the new test file passes on the unmodified code: run the full suite; expect `0 failed`. Also run it twice to confirm the fingerprints are stable between runs.
- [ ] **Step 5: Commit** `tests/mine_fingerprint.gd`, `tests/test_mine_golden.gd` (+ `.uid`): "Golden fingerprints for 31 mine seeds (#74)".

### Task 2: Extract `MineLayout` and `MineGenerator`; `MineGrid` applies the layout

**Files:**
- Create: `scripts/mine_layout.gd`, `scripts/mine_generator.gd`
- Modify: `scripts/mine.gd` (`_ready`, `_generate_layout`, and the moved functions)
- Test: `tests/test_mine_golden.gd` (existing), `tests/test_world.gd` (existing, unchanged)

**Interfaces:**
- Produces `MineLayout` (`class_name MineLayout`, `extends RefCounted`): `enum Kind { EMPTY, ROCK, BEDROCK, VAULT, PLANK, DEBRIS, GAS }`; fields `mine_seed: int`, `kinds: PackedByteArray` (index `x * GRID_HEIGHT + y`), `decor: Dictionary` (cell -> `DecorKind` int: FRAME or POST), `drifts: Array`, `event_rooms: Array`, `torches: Array`, `room_cells`, `reserved_floors`, `plank_cells`, `debris_cells`, `vault_cells` (each `Dictionary` cell -> true), `fuel_cells: Array`, `ore_cells: Array` (of `{"cell": Vector2i, "value": int}`), `spare_floor_cells: Array`, `lost_miner_cell: Vector2i`, `shaft_end_row: int`, `old_ladder_rows: Array`; methods `kind_at(cell: Vector2i) -> int` (EMPTY outside the grid), `is_solid(cell: Vector2i) -> bool`, `shaft_column() -> int`, `shaft_open_rows() -> Vector2i`.
- Produces `MineGenerator` (`class_name MineGenerator`, `extends RefCounted`): `static func generate(mine_seed: int) -> MineLayout`; static pure helpers `layer_rows(layer: int) -> Vector2i`, `layer_index_for_row(y: int) -> int`, `shaft_column() -> int`, `shaft_open_rows(shaft_end_row: int) -> Vector2i`, `ore_value_for_row(y: int) -> int`.
- Consumes: `MineGrid` constants only.

- [ ] **Step 1: Create `MineLayout`** with the fields and methods above (data only, no Godot node types).
- [ ] **Step 2: Create `MineGenerator.generate`.** Move the pure code from `mine.gd` into it in the current call order: seed `rng` with `mine_seed`, `seed(mine_seed)`, random fill, `_reinforce_boundaries`, three `_smooth` passes, `_carve_old_mine` (its own `+51` generator), `_carve_event_rooms`, kinds from the precedence boundary > vault > plank > shaft or debris > rock, `_place_gas_pockets` (reads `kinds`: GAS where the cell is ROCK and not in `room_cells`), floor cells minus `room_cells`, `shuffle()`, fuel then ore cells then `spare_floor_cells`, lost-miner pick (its own copy of the take-spare-cell logic, no RNG), torches (its own `+52` generator). Functions that wrote `set_cell(DECOR_LAYER, ...)` write `layout.decor` instead. Reads of `is_solid` become `layout.is_solid`. The ore value uses `ore_value_for_row` (same value as `ore_value_at` for that row).
- [ ] **Step 3: Change `MineGrid._ready`/`_generate_layout`.** Seed resolution stays (launch seed, `next_seed`, random). Then `var layout := MineGenerator.generate(mine_seed)` and `_apply(layout)`: `set_cell` for every non-EMPTY kind (ROCK -> `layer_atlas(layer_index_for_row(y))`, GAS -> `gas_atlas(layer)`, VAULT/PLANK/BEDROCK -> their constants, DEBRIS -> `DEBRIS_ATLAS_COORDS`), decor cells, then fuel pickups, ore pickups, torches in that order, each with the `_reserved_floors` entry it has today. Copy the layout into the existing fields using `.duplicate()` for every Dictionary and Array. Delete the moved functions from `mine.gd`; keep public ones (`shaft_column`, `shaft_open_rows`, `is_in_shaft`, `is_in_old_mine`, `drift_cells`, `quiet_floor_row`, `layer_index_at_world`, ...) as thin delegates to the generator's statics.
- [ ] **Step 4: Add the aliasing test** `test_two_mines_from_one_seed_do_not_share_state` to `tests/test_mine_golden.gd`: build two `MineGrid`s with the same seed; claim a spare floor cell with `take_floor_cell_in_layer(0)` in the first; assert the second's `_spare_floor_cells.size()` and `_reserved_floors` are unchanged.
- [ ] **Step 5: Verify.** Full unit suite: `0 failed` including `test_every_golden_seed_matches` and the existing `test_world` generation tests; playtest 32 scenarios `0 failed`. If a golden seed differs, diff the fingerprint pieces for that seed to find which field moved before changing anything else.
- [ ] **Step 6: Commit**: "Extract MineGenerator and MineLayout from MineGrid (#74)".

### Task 3: Scene-free generator tests, and the time saved

**Files:**
- Create: `tests/test_mine_generator.gd`
- Modify: `tests/test_world.gd` (remove the tests moved), `tests/test_case.gd` (a layout cache)

**Interfaces:**
- Consumes: `MineGenerator.generate`, `MineLayout` (Task 2).
- Produces: `TestCase.shared_layout(mine_seed: int) -> MineLayout` (generated once per run, cached in a static dictionary; read only).

- [ ] **Step 1: Add `shared_layout`** to `tests/test_case.gd` (static cache; document that layouts are read only).
- [ ] **Step 2: Move these tests** from `test_world.gd` into `test_mine_generator.gd`, rewritten to read a `MineLayout` (`layout.drifts`, `layout.kind_at`, `layout.is_solid`, `layout.event_rooms`, `layout.torches`, `layout.old_ladder_rows`, `layout.lost_miner_cell`, `layout.shaft_open_rows()`), same seeds and same assertions: `test_about_thirty_percent_of_old_ladder_pieces_are_missing`, `test_the_lost_miner_stands_at_the_stone_drifts_far_end`, `test_the_lift_stands_in_the_shaft_at_the_bottom_of_clay`, `test_event_rooms_and_pickups_keep_out_of_the_shaft`, `test_event_rooms_and_pickups_keep_out_of_the_drifts`, `test_each_worked_layer_gets_a_drift_of_the_right_shape`, `test_cave_torches_stand_on_free_floor_in_the_first_two_layers`, `test_shaft_torches_sit_on_the_frame_every_ten_rows_in_topsoil_and_clay`. Tests that read tile atlas coords of `MineGrid` or use nodes stay in `test_world.gd`.
- [ ] **Step 3: Add the pinning tests** to `test_mine_generator.gd`:
  - `test_generate_creates_no_nodes`: node count (`Performance.get_monitor(Performance.OBJECT_NODE_COUNT)`) is equal before and after `MineGenerator.generate(7)`.
  - `test_layout_invariants_hold_for_many_seeds`: for seeds 1..40, `lost_miner_cell` is `(-1, -1)` or an open cell above a solid one; no `fuel_cells`/`ore_cells` cell is in `room_cells`; `shaft_end_row` lies in the upper half of Stone; every drift's landing cell is PLANK.
  - `test_generate_is_a_pure_function_of_the_seed`: two calls with the same seed give equal `kinds`, `drifts`, `event_rooms`, `torches`, `spare_floor_cells`.
- [ ] **Step 4: Verify and measure.** Full suite `0 failed`; read the "seconds per file" table and record `test_world` and `test_mine_generator` totals against the 99 s `test_world` baseline.
- [ ] **Step 5: ROADMAP entry** (M71: pure mine generator, with the measured numbers) and commit: "Scene-free generator tests; ROADMAP M71 (#74)".
- [ ] **Step 6: Open PR 1**; CI `test`, `playtest` and GitGuardian green before asking to merge.

---

## Stage 2 (PR 2): faster smoothing

### Task 4: Smooth over a flat byte array

**Files:**
- Modify: `scripts/mine_generator.gd` (`_smooth`, `_count_wall_neighbors`, and the grid they use)
- Test: `tests/test_mine_golden.gd` (existing), `tests/test_mine_generator.gd`

**Interfaces:**
- Consumes: Task 2 generator.
- Produces: `MineGenerator._smooth(grid: PackedByteArray) -> PackedByteArray` (index `x * GRID_HEIGHT + y`, 1 = solid), same result as today for every grid.

- [ ] **Step 1: Write the equivalence test first** `test_smooth_matches_the_reference_on_random_grids` in `tests/test_mine_generator.gd`: keep a copy of the current nested-array `_smooth` inside the test as the reference; for 5 random grids (fixed seeds) compare the new flat result cell by cell. Run it: expect FAIL (new function missing).
- [ ] **Step 2: Implement** the flat `_smooth`: out-of-bounds counts as solid; rows above `SURFACE_ROWS` stay empty; solid stays solid at 4 or more solid neighbours, empty becomes solid at 5 or more. Use a per-pass neighbour count computed with running column sums or direct index arithmetic, not 8 lookups per cell through nested arrays. Convert at the boundaries of the generator so the rest of generation is untouched.
- [ ] **Step 3: Verify.** The equivalence test passes; `test_every_golden_seed_matches` passes (the safety net for the whole generator); full suite `0 failed`; playtest `0 failed`.
- [ ] **Step 4: Measure.** Re-run the profile (mine generation seconds) and the suite; record before and after in the ROADMAP entry (M72). Target: about 0.5 s less per mine; if the gain is under 0.2 s, say so in the PR instead of claiming it.
- [ ] **Step 5: Commit and open PR 2**: "Faster mine smoothing over a flat array (#74, #82)". CI green before asking to merge.
