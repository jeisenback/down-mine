# Measured testing: a walking bot, measured physics, a performance smoke test

## Why

Three things we rely on are checked only on paper, and each has already cost us a surprise:

- **Walkability.** The connectors, stairs and spines are checked by a flood fill over tile data (`GalleryChecks.reachable`). It assumes a one-tile step up and a drop of up to 7 tiles. It never uses the real player body, so it cannot say whether a player can actually climb back out of a two-deep pit, or whether a steeper stair would feel like a ladder. That question is open today.
- **Physics.** `test_a_plain_jump_clears_a_two_tile_ledge`, `test_a_jump_and_mantle_reach_three_tiles_but_not_four` and `test_digging_down_descends_about_five_tiles_a_second` compute from the constants (apex = v squared over 2g). They pass even if the engine's integration, the jump cut or the dig hold changed what the player does. Step-up, the jump cut and the mantle are measured on the real player; the rest are not.
- **Performance.** The 126 ms decay hitch (#94) was found by accident. Nothing would catch the next one.

Goal: three small, test-only additions that measure the real thing. No gameplay code changes.

Success looks like: a connector's walkability and the pit climb-out are proved with real keys and real collisions on at least three seeds; the headline movement numbers are measured and pinned within tolerance; a frame-time and decay-tick budget fails loudly when exceeded.

## What exists

- The playtest scenarios (`tests/playtest.gd`) drive real key events under a virtual display, and I can read their screenshots. They gate CI.
- `tests/balance_probe.gd` plays whole runs with real keys, headless, over a few seeds. It is a report, not a gate.
- Physics tests in `tests/test_world.gd` build an arena by clearing cells of a real `MineGrid` and add a `Player` (for example `test_step_up_climbs_one_tile_but_not_two`).
- `TouchKeys` (key sources) and `GamepadControls` (named methods) are a clean way to press keys from a test with no leftover state.
- Measured on this machine, headless, seed 1001, a deep gallery with 47 lights: median 0.85 ms a frame, p95 1.3 to 2.7 ms, max 3.5 to 5.7 ms (idle, walking, digging down). The decay tick with 2000 dug cells is 0.05 to 0.11 ms.

## Design

### 1. The walking bot (`tests/walk_bot.gd`, `tests/test_walk.gd`)

`WalkBot` (RefCounted, test-only) drives the real player toward a target cell with real keys through `TouchKeys` source `"bot"`, so nothing is left held:

- `static func walk_to(tree: SceneTree, player: Player, target: Vector2i, mine: MineGrid, max_seconds: float) -> Dictionary` (a coroutine: call it with `await`). Each physics frame it holds A or D toward the target's x, taps W (jump) when the player's x has not progressed for `STALL_SECONDS` (0.25), holds S never (it never digs), and returns `{reached, seconds, jumps, stuck_at}`. `reached` means the player's cell equals the target within one tile. It stops at `max_seconds` or when it has jumped `MAX_JUMPS` (40) times without progress, and reports where.
- `static func walk_connector(...)`: from the spine cell beside `connector.mouth`, walk to the room's centre cell, then back to the same spine cell. Returns both legs' results.

`tests/test_walk.gd` (in the unit suite, headless, seeds 1001, 2 and 4 that have connectors; each leg within `1.5 * length / 7.5 + 4` seconds, since the player walks 7.5 tiles a second):

- `test_the_bot_walks_down_a_connector_and_back`: both legs reach, no `stuck_at`. This is the proof that the pit can be climbed out of and the stairs walked up, on the real body.
- `test_the_bot_walks_the_open_stretches_of_a_spine`: from a spine's first open standing cell to the cell before its first collapse, and across plank-floored cave crossings, in both directions.
- `test_the_bot_can_use_the_pad`: one connector leg driven by `GamepadControls.axis(JOY_AXIS_LEFT_X, ±1)` and `button(JOY_BUTTON_A, ...)` instead of keys, so the controller's walk path is exercised on real physics.
- `test_the_bot_notices_a_wall`: a hand-built 2-wide, 3-deep pit the bot cannot jump out of: `reached == false` with `stuck_at` set (so a passing bot means something).

A sweep mode in `tests/balance_probe.gd` (`-- walk`, outside the suite, not a gate) walks every connector over the 31 golden seeds and prints, per connector, the seconds each way, jumps used and any stuck point. It is how a steeper stair or a changed layout gets judged before it ships.

### 2. Measured physics (`tests/test_physics.gd`)

The real player on a real arena (the existing pattern: a `MineGrid` with cleared cells), each measurement over physics frames, tolerance from the measured value:

- `test_a_jump_peaks_where_the_constants_say`: apex height over `[40.8 - 3, 40.8 + 3]` px (v squared over 2g is 40.8). Catches a changed integration or jump cut.
- `test_walking_reaches_full_speed`: after 30 frames of D, speed within 5% of `Player.SPEED` (120), and stops within `DECELERATION`'s 0.1 s.
- `test_digging_straight_down_descends_at_the_measured_rate`: through solid rock, 1 s of S gives 5.4 tiles within 15%.
- `test_falls_hurt_by_measured_landing_speed`: drop the player from 6, 8, 12 and 20 tiles in an open column; health lost is 0 up to the safe fall and never more than `MAX_FALL_DAMAGE`; the 20-tile fall costs exactly `MAX_FALL_DAMAGE`. Pins the rule as the engine applies it, not as `fall_damage()` computes it.
- `test_a_jump_climbs_out_of_a_two_deep_pit_but_not_a_three_deep_one`: the pit a connector opens in a spine floor, measured.
- `test_step_up_and_mantle_still_hold`: kept as they are (already measured); noted here so the file's header says what is measured where.

### 3. A performance smoke test (`tests/test_perf.gd`)

Generous limits, from the measured baseline with about 5 to 10 times headroom, because CI machines are slower and noisy:

- `test_a_frame_in_a_deep_gallery_stays_within_budget`: Main on seed 1001, player on a layer-4 spine with its torches around; 300 physics frames idle, 300 walking, 300 digging down; each run's median under 4 ms, p95 under 10 ms, max under 40 ms.
- `test_a_decay_tick_with_many_dug_cells_stays_within_budget`: 2000 dug open cells and every light in the mine, `_collapse_tunnel` under 5 ms.
- All limits scale with the environment variable `PERF_SLACK` (default 1.0), so a slow machine can relax them without editing the test, and every failure message prints the measured number.

## Testing the tests

- The bot's negative test (the impassable pit) fails if the bot reports success without moving.
- Each measured-physics test names the production change that would fail it (a gravity multiplied elsewhere, a changed jump cut, a dig hold removed); the perf test fails if the decay filter goes back to scanning every dug cell (the #94 regression), checked once by hand before it is committed.
- Added suite time must stay under about 30 seconds locally.

## Out of scope

- Image baselines and visual diffs; input record and replay; real hardware and phones; any judgement of feel.
- Changing gameplay, constants or the generator. If a measurement shows a surprise (for example a connector that cannot be climbed out of), that is a finding reported on its own, not fixed inside this work.

## Risks and open questions

- **Bot stability.** Jump-when-stalled can oscillate on a step; the cap on jumps and the negative test bound it. If one seed's stairs prove flaky it is reported as a finding about that connector, not hidden by a looser bot.
- **Perf noise on CI.** The slack factor and the loose limits are the answer; if a limit still flakes it is raised with the measured number in the commit, never skipped.
- **Suite time.** Three Main loads and some seconds of simulated walking are the cost; the sweep stays outside the suite for that reason.
