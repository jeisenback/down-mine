# Measured Testing Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove walkability, movement physics and frame cost by measuring the real game: a bot that walks with real keys, physics numbers measured on the real player, and a frame-time and decay-tick budget.

**Architecture:** Test-only. A `WalkBot` drives the real `Player` through key presses (or the gamepad's named methods) toward a target cell and reports what happened; `test_walk.gd` uses it on real connectors and pits; `test_physics.gd` measures jump, walk, dig and fall on hand-built arenas; `test_perf.gd` times physics frames and a decay tick against generous limits. No gameplay code changes.

**Tech Stack:** Godot 4.5 GDScript; headless tests (`/opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd`; run `--headless --import` first after adding a `class_name` file).

**Spec:** `docs/superpowers/specs/2026-10-16-measured-testing-design.md`

## Global Constraints

- No change to anything under `scripts/` or `scenes/`. If a measurement finds a surprise (a connector that cannot be climbed out of, a number that disagrees with its constant), report it as a finding; do not change gameplay inside this work.
- The bot and the tests press keys only through `TouchKeys` with their own source id (`"bot"`, `"test"`) or through `GamepadControls`' named methods, and release every key on every exit path (success, timeout, stuck). Nothing is left held for the next test.
- The player walks 7.5 tiles a second (`Player.SPEED` 120 px, tile 16 px). Time budgets are `WalkBot.budget_seconds(tiles) = 4.0 + 1.5 * tiles / 7.5`.
- Scenes that load `Main`: `Progress.path_override = TEST_SAVE_PATH` with a fresh save, `main.mine.decay_multiplier = 1000.0` (decay must not refill what the bot walks), `main.player.invincible = true`, `main.player.light.burn_rate = 0.0`, then `await physics_frames(10)`.
- Perf limits (medians over 300 frames, headless; measured baseline 0.85 ms median, 1.3 to 2.7 ms p95, 3.5 to 5.7 ms max): median under 4 ms, p95 under 10 ms, max under 40 ms; a decay tick with 2000 dug cells and every light under 5 ms. All limits are multiplied by `PERF_SLACK` (environment variable, default 1.0). Warm up 60 frames before measuring: the first physics frame after loading `Main` costs 0.7 to 1 s.
- Added suite time stays under about 30 seconds locally. The sweep over every connector is outside the suite.
- No emojis anywhere (user preference).

## Review Focus

1. **A bot that cheats or hangs:** it must not report `reached` without the player's cell being the target's (within one tile), must not jump forever on a flat floor (a jump cap and a stall rule that ignores the first 0.25 s of acceleration), and must not mistake standing still at the target for being stuck.
2. **Held keys after a failure:** a timeout, a stuck report or a failed assertion mid-walk leaves no key down (`TouchKeys.is_down` false for A, D, W afterwards).
3. **Pit table:** a 2-deep and a 3-deep pit are climbable (a jump, and a jump plus the mantle), a 4-deep pit is not; the bot reports the 4-deep one as stuck, so a passing bot means something.
4. **Perf flakiness:** one-off costs after loading `Main` (the first physics frame, the first draw) must not be measured; limits scale with `PERF_SLACK`; every failure prints the measured numbers.
5. **Arena leakage in physics tests:** an arena must be walled and roofed (at least 8 clear tiles above the floor for a jump, solid side walls) so a stray walk or jump measures the player, not the mine around it.

---

## One PR

### Task 1: `WalkBot` and the pit table

**Files:**
- Create: `tests/walk_bot.gd`, `tests/test_walk.gd`

**Interfaces:**
- Produces `WalkBot` (`class_name`, RefCounted, test-only):
  - `const STALL_SECONDS := 0.25`, `const MAX_JUMPS := 40`, `const SOURCE := "bot"`
  - `static func budget_seconds(tiles: int) -> float` (`4.0 + 1.5 * tiles / 7.5`)
  - `class KeyDriver extends RefCounted`: `func go(dir: int, jump: bool) -> void` (A for -1, D for +1, none for 0; W held while `jump`, all through `TouchKeys` source `"bot"`) and `func stop() -> void` (releases source `"bot"`).
  - `class PadDriver extends RefCounted`: `_init(pad: GamepadControls)`; the same `go` and `stop` through `pad.axis(JOY_AXIS_LEFT_X, dir)` and `pad.button(JOY_BUTTON_A, jump)`; `stop` calls `pad.release_all()`.
  - `static func walk_to(tree: SceneTree, player: Player, mine: MineGrid, target: Vector2i, max_seconds: float, driver) -> Dictionary` (a coroutine: call with `await`). Each physics frame: direction toward the target's x (none when the player's cell x equals it), jump when the player's x has not moved by 2 px over `STALL_SECONDS` of intent, count jumps. Returns `{"reached": bool, "seconds": float, "jumps": int, "stuck_at": Vector2i}` where `stuck_at` is the player's cell at the end when not reached (else `Vector2i(-1, -1)`). Always calls `driver.stop()` before returning. Stops at `max_seconds` or `MAX_JUMPS` jumps without progress.
  - `static func walk_connector(tree: SceneTree, player: Player, mine: MineGrid, connector: Connector, driver) -> Dictionary` (a coroutine): puts the player on the spine cell beside the mouth (`connector.mouth + Vector2i(-connector.dir, 0)`), walks to `connector.room.cell` within `budget_seconds(connector.cells.size() + 4)`, then walks back to the start cell with the same budget; returns `{"out": <walk_to result>, "back": <walk_to result>}`.

- [ ] **Step 1: Write the failing tests** in `tests/test_walk.gd` (`extends TestCase`; build arenas as `_step_course` in `tests/test_world.gd` does: a `MineScene` instance, cells cleared with `set_cell(0, cell, -1)`, floors with `fill_cell`, `PlayerScene` with `player.mine = mine`, `player.invincible = true`, then `await physics_frames(10)`):
  - `test_the_bot_notices_a_wall`: an arena with a 4-deep, 2-wide pit; the player at the pit bottom, target on the floor 6 tiles beyond the lip; `walk_to(..., 8.0, KeyDriver.new())` gives `reached == false`, `stuck_at` inside the pit, `jumps > 0`, and afterwards `TouchKeys.is_down(KEY_A)`, `KEY_D` and `KEY_W` are all false.
  - `test_a_pit_two_or_three_deep_can_be_climbed_out_of`: the same arena with depth 2 and then depth 3 (a fresh arena each): `reached` is true within 8 s. (Depth 2 is a jump; depth 3 needs the mantle: this pins that a connector's 2-deep pit is climbable and measures the 3-deep margin.)
  - `test_the_bot_stops_when_it_arrives`: a flat floor, target 8 tiles away: reached, `seconds < 3.0`, `jumps == 0`.
  - `test_the_bot_walks_a_connector_down_and_back` over seeds `[1001, 2, 4]`: for the first connector of each seed (`MineGenerator.generate(seed).connectors[0]` for choosing; the live `main.mine.connectors[0]` for walking), load `Main` per the Global Constraints, `walk_connector` with `KeyDriver`; both legs `reached`.
  - `test_the_bot_walks_a_connector_with_the_pad` on seed 1001: the same walk with a `PadDriver` over `main.gamepad_controls`.
  - `test_the_bot_walks_the_open_stretch_of_a_spine` on seed 1001: on the layer 4 spine, from the cell two tiles in from its mouth end to the last open standing cell before its first collapse (or two tiles short of the far end when there is none), out and back, `KeyDriver`.
- [ ] **Step 2:** Run `--headless --import`, then the suite. Expected: FAIL (`WalkBot` does not exist, so `test_walk.gd` does not compile).
- [ ] **Step 3: Implement** `WalkBot` per the Interfaces. The stall rule starts counting only after the player has had `STALL_SECONDS` of intent in the current direction; jumps are a single-frame W press so a jump can be a hop; the loop awaits `tree.physics_frame`.
- [ ] **Step 4:** Run the suite. Expected: pass. If a connector leg is stuck, that is a finding about that connector: record the seed, the connector's layer and the stuck cell in the ledger, mark the test for that seed with the finding in its message, and do not loosen the bot.
- [ ] **Step 5:** Commit `Tests: a walking bot on the real physics`.

### Task 2: A sweep mode in the balance probe

**Files:**
- Modify: `tests/balance_probe.gd`

**Interfaces:**
- Consumes: `WalkBot` (Task 1).
- Produces: `-- walk` mode (and `-- walk seeds=1001,2,4`): for each seed (default: every seed in `tests/test_mine_golden.gd`'s `SEEDS`), loads `Main` per the Global Constraints, walks every connector with `WalkBot.walk_connector` and `KeyDriver`, and prints one line per connector: `walk seed 1001 layer 5 (47 tiles): out 6.8s 1 jumps, back 7.9s 3 jumps` or `... STUCK at (x, y)`; ends with `walk: N connectors, M stuck`.

- [ ] **Step 1:** Add the mode following the existing `trip` and `heart` modes (read their argument handling and `quit()` pattern first).
- [ ] **Step 2:** Run `godot --headless --fixed-fps 60 -s tests/balance_probe.gd -- walk seeds=1001,2,4`. Expected: three seeds' connectors are listed, none stuck, and the last line reports the totals. Then run it over all seeds in the background and record the totals in the ledger.
- [ ] **Step 3:** Commit `Balance probe: walk every connector`.

### Task 3: Measured physics

**Files:**
- Create: `tests/test_physics.gd`

**Interfaces:**
- Produces: tests only; a helper `_arena(mine: MineGrid, origin: Vector2i, width: int, height: int) -> Vector2i` that clears `width x height` cells, fills a floor row under them and solid side walls and a roof 9 tiles above the floor row, and returns the floor-standing cell at the left end.

- [ ] **Step 1: Write the failing tests** (the player is `PlayerScene` with `player.mine = mine`, `player.invincible = false` and `health = Player.MAX_HEALTH` unless stated; keys through `TouchKeys.set_key(code, down, "test")`, released at the end; each test prints its measurement in the assertion message):
  - `test_a_jump_peaks_where_the_constants_say`: hold W from a standing start on the arena floor, track the lowest y reached until landing; apex height in px within `Player.JUMP_VELOCITY * Player.JUMP_VELOCITY / (2.0 * Player.GRAVITY)` plus or minus 3.
  - `test_walking_reaches_full_speed_and_stops_quickly`: hold D for 40 frames (a 40-tile arena), then the next 30 frames' distance divided by 0.5 s is within 5% of `Player.SPEED`; release D and the horizontal speed is under 5 px/s within 0.2 s.
  - `test_digging_straight_down_descends_at_the_measured_rate`: a pocket in a column of `fill_cell`ed rock 12 tiles deep (not the generated rock, which has caves), hold S for 60 frames after the first dig: y descended over the last 45 frames, in tiles per second, within 15% of `Player.DIG_DESCENT_SPEED / MineGrid.TILE_SIZE`.
  - `test_falls_hurt_by_measured_landing_speed`: for drops of 6, 8, 12 and 20 tiles in a roofed column, a fresh player placed at the top: damage taken (health lost) is `0`, `1`, `2` and `Player.MAX_FALL_DAMAGE` respectively (6 tiles is under `SAFE_FALL_TILES` 7; 8 gives `1 + int((8 - 7) / 3.0)`; 12 gives `1 + int((12 - 7) / 3.0)` capped at 2; 20 is capped). If the engine caps the fall speed so that a 20-tile fall lands slower than the formula, report it as a finding and assert what is measured.
  - A comment block at the top of the file lists which movement checks are measured here, which are measured elsewhere (`test_step_up_climbs_one_tile_but_not_two`, `test_releasing_jump_cuts_it_short`, `test_mantle_pulls_up_a_ledge_within_reach` in `tests/test_world.gd`, and the pit table in `tests/test_walk.gd`), and which remain arithmetic on constants (`test_a_plain_jump_clears_a_two_tile_ledge`, `test_a_jump_and_mantle_reach_three_tiles_but_not_four`), with the production change that would fail each measured test (gravity scaled elsewhere, the jump cut changed, the dig hold removed).
- [ ] **Step 2:** Run the suite. Expected: the new tests either pass at once (the engine already does what the constants say) or fail with the measured numbers. A test that passes immediately must be shown capable of failing: temporarily change one constant in `scripts/player.gd` (for example `GRAVITY := 490.0` to `600.0`), run only this file's tests (`tests/run_tests.gd` accepts no filter; use a throwaway copy of the runner or the full suite), confirm the matching test fails with its measured number, then restore the constant (`git diff scripts/` must be empty before committing). Record each such check in the ledger.
- [ ] **Step 3:** Fix tolerances only if a measurement shows a mismatch that is not a bug (for example the first frame's acceleration), and say so in the ledger. Commit `Tests: measured movement physics`.

### Task 4: A performance smoke test

**Files:**
- Create: `tests/test_perf.gd`

**Interfaces:**
- Produces: `static func slack() -> float` (the `PERF_SLACK` environment variable as a float, default 1.0, never under 1.0) and tests only.

- [ ] **Step 1: Write the tests**:
  - `test_a_frame_in_a_deep_gallery_stays_within_budget`: load `Main` on seed 1001 per the Global Constraints, move the player to a layer 4 spine (twenty tiles along it), `await physics_frames(60)` warm-up, then three runs of 300 frames timing each `await tree.physics_frame` with `Time.get_ticks_usec()`: idle, walking (`TouchKeys` D, source `"test"`), digging down (S). For each run assert median under `4.0 * slack()` ms, p95 under `10.0 * slack()`, max under `40.0 * slack()`, and print the three numbers in the message. Release all keys at the end.
  - `test_a_decay_tick_with_many_dug_cells_stays_within_budget`: a `MineScene` instance with the first 2000 open cells below the surface (scanning with `is_solid`) set as `_dug_cells`, 60 `Torch` instances placed at random open cells (use a fixed `RandomNumberGenerator` seed, not the global one), `await physics_frames(2)`, then the mean of 10 `_collapse_tunnel()` calls under `5.0 * slack()` ms (each call removes one cell; refill `_dug_cells` between calls if it empties).
- [ ] **Step 2:** Run the suite. Expected: pass, with the measured numbers visible in a verbose run (print them with `print()` once per test so CI logs show the trend).
- [ ] **Step 3: Show the decay test can fail.** Temporarily put the old implementation back in `MineGrid._collapse_tunnel` (the version that filtered every dug cell before picking one: `var candidates := _dug_cells.filter(func(c): return not is_solid(c) and not is_lit(cell_to_world(c)) and not Support.protects(get_tree(), cell_to_world(c)))`, then `candidates.pick_random()`), run the suite, confirm `test_a_decay_tick_with_many_dug_cells_stays_within_budget` fails with its measured number, then restore the file (`git diff scripts/` empty). Record the measured number and the check in the ledger.
- [ ] **Step 4:** Commit `Tests: a frame and decay-tick budget`.

### Task 5: Docs and the PR

**Files:**
- Modify: `ROADMAP.md`, `README.md` (the testing section, if it has one; otherwise a short "Testing" line under the project layout)

- [ ] **Step 1:** ROADMAP M84: what was added and why (walkability proved on the real body, the pit table, measured movement numbers, the budget), the measured baselines, the tolerances, `PERF_SLACK`, the sweep mode, any findings, and what is still not covered (feel, hardware, image baselines, replay).
- [ ] **Step 2:** Run the full suite (record the count and added time), the full playtest under xvfb (unchanged, expected 34 scenarios pass), and the sweep over all seeds (record the totals). Commit, push, open the PR with: the three additions, the numbers, the "can it fail?" checks from Tasks 3 and 4, the pit table, and every finding. Subscribe to the PR; wait for CI; ask before merging.

---

## Self-review

- **Spec coverage:** walking bot, its negative test, the connector walks (keys and pad), the spine stretch and the sweep (T1, T2); jump, walk, dig, fall measurements and the header that says what is measured where (T3); frame and decay budgets with `PERF_SLACK` (T4); docs, numbers and findings (T5). Out-of-scope items appear in no task.
- **Decisions the spec left open or got wrong, fixed here:** the pit table is 2-deep and 3-deep climbable, 4-deep not (the spec said "not a three-deep one", but the existing mantle test shows a jump plus the mantle reaches 3 tiles, not 4); the pit tests live in `test_walk.gd` because they use the bot; the "can it fail?" checks are explicit steps (T3 step 2, T4 step 3) rather than a general promise; the walking bot's drivers are two small classes so one walk runs on keys and on the pad.
- **Type consistency:** `WalkBot.walk_to` and `walk_connector` take a `driver` with `go(dir, jump)` and `stop()`; `budget_seconds` is used by the tests and the sweep; arenas follow `_step_course`; the bot's key source is `"bot"` and the physics tests' is `"test"`.
- **Proportion:** five tasks, tests named with their assertions, the bot's contract given as signatures and rules rather than code.
