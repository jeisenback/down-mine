# Pure mine generator (issue #74)

From the architecture review of 2026-10-12. Part of issue #82 (faster tests).

## Goal

Pull the seed-to-layout logic out of `MineGrid` into plain data, so that:

- generation can be read, tested and extended without a scene (adding an event type is a change in one place);
- the generation tests can run on data instead of a live tile map;
- the smoothing step can be rewritten for speed against a safety net.

Hard constraint: **every existing seed produces exactly the same mine.** The seed is user-visible ("Seed 1001"), so a changed layout is a visible break.

## Measured starting point

One mine takes about 1.1 s to generate (seed 5, headless): smoothing 0.65 s, random fill 0.01 s, the `set_cell` loop 0.02 s, the rest (carving, rooms, pickups, torches) about 0.4 s. Extracting the generator alone therefore does not make a single generation faster; the speed gain is the smoothing rewrite in stage 2.

## Units

### `MineLayout` (new, `scripts/mine_layout.gd`, RefCounted, data only)

- `mine_seed: int`
- `kinds`: a flat `PackedByteArray` of `GRID_WIDTH * GRID_HEIGHT` tile kinds: EMPTY, ROCK (the layer's rock), BEDROCK, VAULT, PLANK, DEBRIS, GAS.
- `decor: Dictionary` cell -> FRAME or POST (the decor layer).
- `drifts`, `event_rooms`, `torches`: the same dictionaries as today (typed classes are #75).
- `room_cells`, `reserved_floors`, `plank_cells`, `debris_cells`, `vault_cells`: sets (Dictionary cell -> true), as today.
- `fuel_cells: Array[Vector2i]`, `ore_cells: Array` of `{"cell", "value"}`.
- `spare_floor_cells: Array`, `lost_miner_cell: Vector2i`, `shaft_end_row: int`, `old_ladder_rows: Array`.

### `MineGenerator` (new, `scripts/mine_generator.gd`, RefCounted)

- `static func generate(mine_seed: int) -> MineLayout`.
- Takes the pure code from `mine.gd`: random fill, `_smooth`, `_count_wall_neighbors`, `_reinforce_boundaries`, `_carve_old_mine`, `_carve_drifts`, `_place_lift`, `_collapse_drift`, `_carve_event_rooms`, `_seal_vault`, `_place_gas_pockets`, `_find_floor_cells`, the fuel/ore/torch/lost-miner choices.
- The layer and shaft helpers it needs (`layer_rows`, `layer_index_for_row`, `shaft_column`, `shaft_open_rows`, the old-mine rectangles) become static functions here. `MineGrid` keeps its public methods and delegates to them.
- Constants stay on `MineGrid` (`MineGrid.GRID_WIDTH`, `LAYERS`, ...): no constant moves in this change.
- Gas pockets read "is this cell plain layer rock?" from `kinds` instead of reading the tile map back. The ore value is a pure function of the row (today it goes through a world position).
- `MineGenerator` owns its own take-a-spare-floor-cell helper for the lost-miner choice (no RNG involved).

### `MineGrid` (changed)

- Keeps the tileset, dig, decay, walls, queries, and the launch-seed / random-seed handling (the seed is resolved in `MineGrid` and passed in).
- `_ready`: build tileset, `layout = MineGenerator.generate(mine_seed)`, `_apply(layout)`.
- `_apply`: the `set_cell` calls (kind -> atlas coords, per layer), the decor cells, then instantiates fuel pickups, ore pickups and torches in the same order as today.
- Copies the layout into the same public/private fields as today (`drifts`, `event_rooms`, `torches`, `lost_miner_cell`, `shaft_end_row`, `old_ladder_rows`, `_room_cells`, `_reserved_floors`, `_plank_cells`, `_debris_cells`, `_vault_cells`, `_spare_floor_cells`). Mutable sets and arrays are duplicated, because runtime code claims floor cells and spare cells. No other file changes.

## Keeping every seed identical

1. **Golden test first.** Before any code moves, record a fingerprint for about 30 seeds from the current code and commit it (`tests/test_mine_golden.gd`). The fingerprint is a hash over `MineGrid`'s observable state: every cell's atlas coords on both layers, plus `drifts`, `event_rooms`, `torches`, `lost_miner_cell`, `shaft_end_row`, `old_ladder_rows`, the cell sets and the spare floor cells. It reads only `MineGrid`, so the same test checks the old code and the new.
2. **Same random sources, same order.** Local generator seeded with `mine_seed`; `mine_seed + 51` for the old mine; `mine_seed + 52` for torches; the global generator seeded with `seed(mine_seed)` and then `shuffle()` of the floor cells in the same place. The generator calls these in exactly the current sequence. (The global generator stays as is: issue #76.)
3. The existing `test_world` generation tests stay as they are in stage 1 and run on `MineGrid`: a second net.

## Stages

**PR 1 (this spec's first deliverable):**
1. Golden fingerprints test, passing on the current code (no code moved).
2. Extract `MineLayout` and `MineGenerator`; `MineGrid` applies the layout. Golden test and the whole suite pass unchanged.
3. Port the slowest seed-loop generation tests (old ladder pieces, lost miner at the Stone drift, lift in Clay, drifts, event rooms and pickups out of the shaft and drifts, torches) to run on `MineGenerator.generate(seed)` with no scene, cached per seed. Record the time saved.
4. ROADMAP entry.

**PR 2:** rewrite `_smooth` / `_count_wall_neighbors` over a flat `PackedByteArray`, guarded by the golden test. Expected to remove about 0.5 s from every mine.

## Out of scope

- Typed `Drift` / `EventRoom` / `TorchSite` classes (#75).
- Moving dig, decay or walls out of `MineGrid`.
- The global random generator (#76) and any seed-version change.
- Any gameplay change.

## Risks

- Gas pockets and the tile-map read-back: covered by the golden fingerprint, which includes the gas cells.
- Order of `add_child` for pickups and torches changes group iteration order: keep the order of today's calls (fuel, ore, torches).
- Runtime code mutates the spare-floor and reserved-floor sets: `MineGrid` must copy, not alias, the layout's sets (a test builds two mines from one layout to check).
- A fingerprint that misses a field would let a change through: the fingerprint test also asserts it covers every public layout field (a list of field names kept next to it).
