# Rhythm of Threat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The mine's waves come in readable cycles (calm, build, peak), the base light slows and damages Burrowers on its own, and the player sees, hears and feels a wave coming.

**Architecture:** `MineClock` (pure state) learns wave numbers, sizes, peaks and a calm after each peak. `Burrower` takes slow and damage from the base light, with a multiplier while the player flares inside it. `Main` spawns each wave's group (spread, capped), shakes the camera and plays a rumble; the HUD shows one wave line built by a pure text function.

**Tech Stack:** Godot 4.5, GDScript. Tests are `tests/test_*.gd` extending `TestCase`, run with `/opt/godot/godot --headless --fixed-fps 60 -s tests/run_tests.gd` (run `--headless --import` once after adding scripts). Playtest: `xvfb-run -a /opt/godot/godot --fixed-fps 60 -s tests/playtest.gd`. Record the baseline counts before Task 1 (currently 161 unit tests, 25 playtest scenarios).

**Spec:** `docs/superpowers/specs/2026-10-10-rhythm-of-threat-design.md` (planning issue #36). Related: #35 workers and jobs (merged), #37 run base as a settlement, #38 hub as a kingdom.

## Global Constraints

- Cycle of five waves; first-cycle sizes 1, 1, 2, 2, 4 (the fifth is the peak); each later cycle adds 1 to every count; after a peak the next wave comes `CALM_MULTIPLIER` (2.0) times the current interval later.
- `MINE_WAKE_SECONDS` (240), `wave_interval` (90 s to 45 s over the ramp), `HEART_INTERVAL_MULTIPLIER` (0.5) and `WAVE_WARNING_SECONDS` (10) are unchanged.
- At most `MAX_LIVE_BURROWERS` (8) alive at once, counting noise-summoned ones; the shortfall is not made up. Spawn spread offsets in tiles, in order: 0, -3, 3, -6, 6, -9, 9, -12 from the base's column; depth rule unchanged (`BURROWER_SPAWN_OFFSET_TILES` below the base, clamped).
- A Burrower inside the base light's current radius (`target.light.current_radius()`) moves at `LIT_SPEED_MULTIPLIER` (0.4) and loses `BASE_LIGHT_DAMAGE_RATE` (0.15) times the base light's `fuel_fraction()` health per second; health is `MAX_HEALTH` (1.5). While the player is inside that radius and `player.light.is_flaring` the damage is multiplied by `PRESENCE_FLARE_MULTIPLIER` (3.0). Nothing else takes damage from it.
- HUD: one line under `BaseLabel`: always the countdown; the size only when the base has the bell; a peak always marked. Wave cue: camera shake `WAVE_SHAKE_SECONDS` (0.5) at `WAVE_SHAKE_PIXELS` (2.0), doubled for a peak, plus a new synthesized `"rumble"` sound (about 0.7 s, louder for a peak).
- Drawing, shaking and the cue must not consume the global random generator (the mine's seeded generation shares it). Saves and the run log: no format change. No emojis anywhere. Every commit message ends with the two attribution lines used on this branch (see `git log -1`).

## Review Focus

1. The calm: `MineClock.tick` clamps the countdown to the interval ("never exceeds it"), which would cut a calm of 2x short. Task 1.
2. The Heart: carried during a calm, the calm and the interval halve; the cycle position does not reset. Task 1.
3. The live cap with noise-summoned Burrowers present, and a wave that fits only partly. Task 3.
4. Base-light damage is per Burrower and only to Burrowers; the boundary of the light's radius; an empty base light still slows inside its 60 px minimum radius but does no damage. Task 2.
5. The camera offset is restored exactly (also if a second wave arrives mid-shake, or the run ends mid-shake) and the shake does not use the global RNG. Task 4.
6. Existing tests built on a single-Burrower wave or on a Burrower reaching the base through a lit area (`test_world` wall chew, `test_main` wave tests) must stay meaningful after the base light starts fighting back. Tasks 2 and 3.

---

### Task 1: The cycle in MineClock

**Files:**
- Modify: `scripts/mine_clock.gd`
- Test: `tests/test_rules.gd` (next to the existing mine clock tests, around lines 161 to 195)

**Interfaces:**
- Produces on `MineClock`:
  - constants `WAVE_CYCLE_SIZES := [1, 1, 2, 2, 4]`, `CALM_MULTIPLIER := 2.0`
  - `var wave_number: int` (0 until the first wave; incremented before `tick` returns `"wave"`)
  - `static func wave_size(n: int) -> int` (n starts at 1: cycle `(n - 1) / 5`, position `(n - 1) % 5`, size `WAVE_CYCLE_SIZES[position] + cycle`)
  - `static func is_peak(n: int) -> bool` (`n % 5 == 0`)
  - `func in_calm() -> bool` (true after a peak wave until the next one spawns)
  - `func seconds_to_next() -> float` (-1.0 before the mine wakes; otherwise the countdown)
  - `func next_wave_number() -> int` (`wave_number + 1`)
- `tick(delta, run_seconds, carrying_heart) -> String` keeps its contract ("", "warn", "wave").

- [ ] **Step 1: Write the failing tests:**
  - `test_wave_sizes_cycle_and_grow`: `wave_size(1..10)` is `[1, 1, 2, 2, 4, 2, 2, 3, 3, 5]`; `wave_size(11)` is 3.
  - `test_every_fifth_wave_is_a_peak`: `is_peak(5)`, `is_peak(10)`, `is_peak(15)` true; `is_peak(1)`, `is_peak(4)`, `is_peak(6)` false.
  - `test_a_calm_follows_each_peak`: tick a clock one second at a time from 240 s with the Heart not carried; after the 5th `"wave"` event `in_calm()` is true and `seconds_to_next()` is `CALM_MULTIPLIER * wave_interval(t)` (within 1 s) and the next wave arrives that much later (not clamped back to one interval: Review Focus 1); after the 6th wave `in_calm()` is false and the gap before the 7th is one interval.
  - `test_seconds_to_next_before_and_after_the_wake`: -1.0 at run time 100; about 90 right after the first tick at 240; decreasing by the delta each tick.
  - `test_the_heart_halves_a_calm_and_keeps_the_cycle_position`: reach the calm after wave 5, start carrying the Heart: within 2 s the countdown is at most `wave_interval(t, true) * CALM_MULTIPLIER`; the next wave is number 6 with size 2.
  - `test_wave_number_counts_each_wave`: `wave_number` is 0 before and equals the count of "wave" events after.
  - Existing mine clock tests (`test_clock_is_silent_until_240_then_warns_then_waves`, `test_taking_the_heart_shortens_a_pending_wave`) still pass unchanged.
- [ ] **Step 2: Run, verify they fail** (`wave_size` not found / does not compile).
- [ ] **Step 3: Implement** the Interfaces. In `tick`, the countdown limit is the current interval, times `CALM_MULTIPLIER` while `in_calm()`; on `"wave"` increment `wave_number`, then set the next countdown to the interval, times `CALM_MULTIPLIER` if the wave just spawned was a peak. Reset the warning flag as today.
- [ ] **Step 4: Run the whole suite, verify it passes.**
- [ ] **Step 5: Commit.**

---

### Task 2: The base light fights Burrowers

**Files:**
- Modify: `scripts/burrower.gd`
- Modify: `tests/test_world.gd:78-95` (the wall-chew Burrower test) and any other Burrower test that relies on an unlit approach
- Test: `tests/test_world.gd`

**Interfaces:**
- Produces on `Burrower`: constants `BASE_LIGHT_DAMAGE_RATE := 0.15`, `PRESENCE_FLARE_MULTIPLIER := 3.0`; `static func base_light_damage_per_second(fuel_fraction: float, presence_flaring: bool) -> float` (`BASE_LIGHT_DAMAGE_RATE * fuel_fraction`, times `PRESENCE_FLARE_MULTIPLIER` when `presence_flaring`).
- Consumes: `RunBase.light: MineLight` (`current_radius()`, `fuel_fraction()`), `Player.light.is_flaring`.

- [ ] **Step 1: Write the failing tests** (a `RunBase`, a `Player` with physics off and a `Burrower` built as the existing wall test does):
  - `test_base_light_damage_rate_scales_with_fuel`: `base_light_damage_per_second(1.0, false)` is 0.15; `(0.4, false)` is 0.06; `(0.0, false)` is 0.0; `(1.0, true)` is 0.45.
  - `test_a_burrower_in_a_full_base_light_dies_in_ten_seconds`: Burrower placed 100 px from the base (inside the radius), base light full: still alive after 9.5 s of physics frames, gone after 10.5 s (it is also slowed, so it has not reached the base's attack range, and the base kept its health).
  - `test_a_burrower_in_the_base_light_is_slowed`: over 1 s it covers about `SPEED * LIT_SPEED_MULTIPLIER` px toward the base; the same Burrower outside the radius covers about `SPEED`.
  - `test_an_empty_base_light_does_no_damage`: base light fuel 0, Burrower inside the 60 px minimum radius: health unchanged after 5 s; it is still slowed inside that radius.
  - `test_presence_flaring_inside_the_base_light_triples_the_damage`: player inside the base light radius and `player.light.is_flaring` true: the Burrower loses health 3x as fast as with the player inside but not flaring; a player flaring outside the base light radius changes nothing.
  - `test_base_light_hurts_only_burrowers`: a Stalker and the player inside a full base light lose no health from it (nothing new applies; assert their health fields are unchanged after 5 s with the base light full).
  - Review Focus 4 boundary: a Burrower exactly at `current_radius()` is not inside; one pixel closer is.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Implement** in `Burrower._physics_process`: `in_base_light = global_position.distance_to(target.global_position) < target.light.current_radius()`; slowed when `in_player_light or in_base_light`; `health -= base_light_damage_per_second(target.light.fuel_fraction(), presence) * delta` while in the base light, with `presence = player is inside the base light radius and player.light.is_flaring`; free the node when health reaches 0 (as the flare branch does). Keep the player-flare branch as it is.
- [ ] **Step 4: Update the existing Burrower tests** that now meet a fighting base light (set the base light's fuel to 0 where the test needs an unlit approach; keep what each test asserts), then run the whole suite and the playtest: both pass.
- [ ] **Step 5: Commit.**

---

### Task 3: Main spawns the groups

**Files:**
- Modify: `scripts/main.gd` (`_spawn_wave` near line 707, `_spawn_burrower`, constants near the top)
- Test: `tests/test_main.gd` (the existing wave tests near lines 375 to 400 keep passing)

**Interfaces:**
- Consumes: `MineClock.wave_number`, `MineClock.wave_size(n)`.
- Produces on `Main`: constants `MAX_LIVE_BURROWERS := 8`, `WAVE_SPREAD_TILES := [0, -3, 3, -6, 6, -9, 9, -12]`; `_spawn_wave()` spawns `min(MineClock.wave_size(max(1, mine_clock.wave_number)), MAX_LIVE_BURROWERS - alive)` Burrowers (alive = size of the `"burrowers"` group; never negative), the i-th at the base's cell shifted by `WAVE_SPREAD_TILES[i]` columns; `waves_spawned` increases by 1 once per wave (not per Burrower).

- [ ] **Step 1: Write the failing tests** (seeded `Main` as the existing wave tests use):
  - `test_a_wave_spawns_its_whole_group_spread_out`: set `main.mine_clock.wave_number = 3` (size 2), `main._spawn_wave()`: two Burrowers in the `"burrowers"` group, at different x, one in the base's column and one 3 tiles left; `waves_spawned` is 1.
  - `test_a_peak_wave_is_four_burrowers`: `wave_number = 5` gives 4, at the four first offsets.
  - `test_the_live_cap_clips_a_wave_and_counts_noise_burrowers` (Review Focus 3): with 6 Burrowers already alive (spawn some through `_on_noise_threshold`), a wave of 4 spawns only 2; with 8 alive it spawns none and still counts as a wave; no error when more than 8 are alive.
  - `test_wave_spawn_positions_are_deterministic`: two Mains with the same seed place the same group at the same positions (compare positions).
  - Existing tests: `waves_spawned == 1` after one `_spawn_wave()` with `wave_number` 0 still holds.
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Implement.** `_spawn_burrower(origin)` already takes a cell; call it with `base_cell + Vector2i(WAVE_SPREAD_TILES[i], 0)` and let its clamping keep the group inside the walls. Count `waves_spawned` before spawning.
- [ ] **Step 4: Run the whole suite, verify it passes.**
- [ ] **Step 5: Commit.**

---

### Task 4: The warning and the cue

**Files:**
- Modify: `scripts/mine_clock.gd` (`hud_text`), `scripts/hud.gd` (`update_wave`), `scenes/HUD.tscn` (a `WaveLabel` under `BaseLabel`), `scripts/main.gd` (feeding the line, `_shake_camera`, the cue), `scripts/sfx.gd` (`"rumble"`)
- Test: `tests/test_rules.gd`, `tests/test_main.gd`, `tests/test_sfx.gd` (the existing every-sound test covers `"rumble"` once it is listed)

**Interfaces:**
- Consumes: `MineClock.seconds_to_next()`, `next_wave_number()`, `in_calm()`, `wave_size`, `is_peak`, `RunBase.has_bell`.
- Produces: `static func MineClock.hud_text(seconds: float, next_number: int, calm: bool, show_size: bool, run_seconds: float) -> String` (the clock owns its wording) with these exact forms:
  - before the wake (`run_seconds < MINE_WAKE_SECONDS`): `"Mine wakes in 42 s"` (seconds `ceili(MINE_WAKE_SECONDS - run_seconds)`)
  - normal: `"Wave in 42 s"`; with a peak `"Wave in 42 s: PEAK"`; with the bell `"Wave in 42 s: 3 Burrowers"`; peak with the bell `"Wave in 42 s: 4 Burrowers, PEAK"`
  - calm: `"Calm: next wave in 42 s"`, and with the bell `"Calm: next wave in 42 s: 2 Burrowers"`
  - seconds are `ceili(seconds)`; one Burrower reads `"1 Burrower"`.
- `HUD.update_wave(text: String, urgent: bool) -> void` sets the label text and turns it red (`Color(1, 0.4, 0.3)`) when `urgent` (10 s or less remain, and not before the wake), white otherwise.
- `Main._shake_camera(seconds: float, pixels: float) -> void`; constants `WAVE_SHAKE_SECONDS := 0.5`, `WAVE_SHAKE_PIXELS := 2.0`; `Sfx.SOUNDS` gains `"rumble"`.

- [ ] **Step 1: Write the failing tests:**
  - `test_wave_line_wording` (every form above, including `"1 Burrower"`, the pre-wake line, the peak without the bell, and rounding up of 41.2 to 42).
  - `test_wave_line_is_urgent_in_the_last_ten_seconds`: `HUD.update_wave("Wave in 9 s", true)` turns the label's `modulate` red and `false` returns it to white.
  - `test_main_shows_the_countdown_always_and_the_size_only_with_the_bell`: a seeded `Main` at run time 300 with a live clock: the HUD line has no "Burrower" before `run_base.build_bell()` and does after.
  - `test_a_wave_shakes_the_camera_and_the_peak_shakes_harder`: after `main._spawn_wave()` with `wave_number` 2 the shake amplitude is `WAVE_SHAKE_PIXELS`; with 5 it is double; mid-shake the player's `Camera2D.offset` differs from its rest value; after `WAVE_SHAKE_SECONDS` of `_process` the offset equals the rest value exactly (Review Focus 5), also when a second wave starts mid-shake and when the run ends mid-shake.
  - `test_the_shake_does_not_touch_the_global_random_generator`: `seed(7)`, draw one `randf()` as expected, `seed(7)`, run a shake for a second, the next `randf()` equals expected.
  - `test_every_sound_is_generated_and_audible` (existing) now covers `"rumble"`; also assert `Sfx.stream("rumble").data.size() > Sfx.SAMPLE_RATE / 2` (longer than half a second).
- [ ] **Step 2: Run, verify they fail.**
- [ ] **Step 3: Implement.** The shake uses its own `RandomNumberGenerator` for jitter and decays linearly to zero; the rest offset is captured when a shake starts only if none is running, and written back exactly when it ends or the run ends. `Main._spawn_wave` plays `Sfx.play("rumble", 0.0 if peak else -6.0)` and starts the shake (doubled for a peak). The HUD line is updated every frame in `_process` from the clock; `show_size = run_base.has_bell`.
- [ ] **Step 4: Run the whole suite and the playtest, verify both pass.**
- [ ] **Step 5: Commit.**

---

### Task 5: Playtest, probe and docs

**Files:**
- Modify: `tests/playtest.gd` (new scenario), `README.md`, `ROADMAP.md`
- Test: `tests/playtest.gd`

**Interfaces:** Consumes everything above.

- [ ] **Step 1: Write the failing playtest scenario `wave_meets_the_base_light`:** start a game; stage a full base light (`base.light.fuel = base.light.max_fuel`), set `main.mine_clock.wave_number = 2` (so the next wave is the third, size 2) and call `main._spawn_wave()`; with `Engine.time_scale = 6.0` run about 25 s of game time. `check` that both Burrowers are gone and the base kept its health. Then stage a nearly empty base light (`fuel = max_fuel * 0.02`), spawn a size-2 wave again, run the same time, and `check` that the base lost health. `shot` both. Restore `Engine.time_scale = 1.0`.
- [ ] **Step 2: Run the playtest, verify the new scenario fails** before Tasks 1 to 4 are in place (if executing in order it should pass now; write it first and confirm its first assertion fails by temporarily disabling the base light damage, then restore).
- [ ] **Step 3: Probe and docs.** Run `tests/balance_probe.gd` on `main` and on this branch (two worktrees, as for milestone 54) and record both in the commit message: the dive and dark bots should be unchanged; the idle bot's "base fell" time will move because waves are bigger; note the new time. Update `README.md` (waves, the calm and peak, the base light fighting back, the wave line and bell, the cue) and `ROADMAP.md` (M55 done; piece 2 of 4 of the Two Crowns design, next #37). Close #36 with links to the spec and this plan.
- [ ] **Step 4: Run the full suite and the playtest; both pass** (record counts).
- [ ] **Step 5: Commit.**

---

## Self-review notes

- Coverage: the cycle and calm (Task 1), the slow, damage and presence rules and their edge cases (Task 2), groups, spread, cap and determinism (Task 3), the HUD line with the bell rule, the tremor and the rumble (Task 4), the playtest, probe and docs the spec lists (Task 5). The spec's two open questions are decided: the HUD line sits under `BaseLabel` (the user chose it), and the cue is both a tremor and a sound.
- Names: `MineClock.wave_number/wave_size/is_peak/in_calm/seconds_to_next/next_wave_number/hud_text`, `Burrower.base_light_damage_per_second`, `Main.MAX_LIVE_BURROWERS/WAVE_SPREAD_TILES/_shake_camera`, `HUD.update_wave`, `Sfx` `"rumble"`.
- Known cost of the order: after Task 2 and before Task 3 a single-Burrower wave meets a fighting base light, so the idle bot's base lasts longer on the branch for a while; do not read probe numbers until Task 3 is in.
