# M50 Two Listeners and the Mine's Clock Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Noise has a position and two listeners (the base, by distance; the Stalker, by proximity), and from 240 s into a run the mine sends Burrowers at the base on a clock whatever the player does.

**Architecture:** `NoiseMeter.add_noise(amount, position)` is the single entry point. It scales the meter by how far the base is from the sound and emits `noise_made` for the Stalker listener, which `Main` forwards to `Stalker.alert()`. A new `MineClock` (pure state machine, no nodes) decides when a wave warns and spawns; `Main` owns the spawning.

**Tech Stack:** Godot 4.5, GDScript. Tests are `tests/test_*.gd` extending `TestCase`, run with `godot --headless --fixed-fps 60 -s tests/run_tests.gd` (the Godot binary for this session is at `/tmp/claude-0/-home-user-down-mine/5ebdb75c-4140-522a-8fa8-1480d465a6fb/scratchpad/godot/godot`; run `--headless --import` once after adding scripts). Baseline: 63 passed.

**Spec:** `docs/superpowers/specs/2026-10-09-run-loop-redesign-design.md`, sections "Noise" and "The mine's clock".

## Global Constraints

- Values from the spec: `BASE_HEARING_TILES = 80`, `STALKER_HEARING_TILES = 30`, `ALERT_SECONDS = 4`, `MINE_WAKE_SECONDS = 240`, `WAVE_INTERVAL` 90 s at wake shrinking to 45 s at `MineGrid.DECAY_RAMP_TIME` (480 s), Heart halves the interval, bell rings 10 s before a wave surfaces.
- `hearing(tiles)` falls linearly from 1 at 0 tiles to 0 at 80; distance is straight-line tiles (`distance_px / MineGrid.TILE_SIZE`).
- A sound made in a quiet layer adds nothing and alerts nothing; "quiet" is judged at the sound's position, not the player's.
- Burrowers never spawn above the quiet floor; noise Burrowers still spawn below the player, wave Burrowers below the base.
- The run log counts waves separately from noise Burrowers (`"waves"` key); `burrowers_spawned` stays noise-only.
- Not touched: dig noise amounts, the `noise_multiplier` crew effects (they still scale what the base hears), Burrower tunnelling (stays silent).
- No emojis anywhere. Every commit message ends with the two attribution lines used on this branch (see `git log -1`).

## Review Focus

Inputs the spec implies but no task's own happy path exercises, most likely to bite first. Each has its test in the owning task.

1. The base is replanted mid-run (P): the listener must follow it at once, not stay at the spawn point. Task 2.
2. A sound at or beyond 80 tiles must add exactly 0, never negative. Task 1.
3. The player digs in Stone while a surface base listens: quiet is judged at the dig, not the base. A sound in a quiet layer while the player stands deep adds nothing. Task 1 and Task 2.
4. An alerted Stalker inside the base's light must still be pushed out, and one retreating after a strike has its retreat cleared. Task 3.
5. A wave for a surface base must not spawn inside the quiet layers; no wave after the run ends; old run-log entries without `"waves"` still print. Task 4.

---

### Task 1: Positioned noise and base hearing

**Files:**
- Modify: `scripts/noise_meter.gd`
- Test: `tests/test_rules.gd`

**Interfaces:**
- Produces: `const NoiseMeter.BASE_HEARING_TILES := 80.0`; `static func NoiseMeter.hearing(tiles: float) -> float`; `var NoiseMeter.base_position: Callable` (returns `Vector2`, default `Vector2.ZERO`); `var NoiseMeter.quiet_at: Callable` (takes `Vector2`, returns `bool`, default false; replaces `quiet_check`); `signal NoiseMeter.noise_made(position: Vector2, amount: float)`; `func NoiseMeter.add_noise(amount: float, position: Vector2) -> void`.

- [ ] **Step 1: Write the failing tests** in `tests/test_rules.gd`:

```gdscript
func test_hearing_falls_linearly_to_zero_at_80_tiles() -> void:
	assert_eq(NoiseMeter.hearing(0.0), 1.0, "full at the base")
	assert_eq(NoiseMeter.hearing(40.0), 0.5, "half at 40 tiles")
	assert_eq(NoiseMeter.hearing(80.0), 0.0, "nothing at 80")
	assert_eq(NoiseMeter.hearing(500.0), 0.0, "never negative")

func test_noise_is_scaled_by_distance_from_the_base() -> void:
	var meter: NoiseMeter = add(NoiseMeter.new())
	meter.decay_rate = 0.0
	meter.base_position = func(): return Vector2.ZERO
	meter.add_noise(40.0, Vector2.ZERO)
	assert_eq(meter.noise, 40.0, "at the base: full")
	meter.noise = 0.0
	meter.add_noise(40.0, Vector2(40 * MineGrid.TILE_SIZE, 0))
	assert_eq(meter.noise, 20.0, "40 tiles away: half")
	meter.noise = 0.0
	meter.noise_multiplier = 0.5
	meter.add_noise(40.0, Vector2.ZERO)
	assert_eq(meter.noise, 20.0, "crew multiplier still applies after hearing")

func test_quiet_layers_are_judged_at_the_sound() -> void:
	var meter: NoiseMeter = add(NoiseMeter.new())
	meter.decay_rate = 0.0
	meter.quiet_at = func(pos: Vector2): return pos.y < 100.0
	var heard: Array = []
	meter.noise_made.connect(func(pos, amount): heard.append(pos))
	meter.add_noise(30.0, Vector2(0, 50))
	assert_eq(meter.noise, 0.0, "sound in a quiet layer adds nothing")
	assert_eq(heard.size(), 0, "and alerts nothing")
	meter.add_noise(30.0, Vector2(0, 500))
	assert_eq(heard.size(), 1, "sound below the quiet floor is announced")
```

- [ ] **Step 2: Run to verify they fail.** Run: `godot --headless --fixed-fps 60 -s tests/run_tests.gd 2>&1 | grep -E "hearing|distance_from|judged"`. Expected: FAIL / script error, `hearing` and the two-argument `add_noise` do not exist.

- [ ] **Step 3: Implement** in `scripts/noise_meter.gd`: add the constant, `hearing`, the two callables and the signal; replace `quiet_check` with `quiet_at`; `add_noise` returns early (no add, no signal) when `quiet_at.call(position)`, otherwise emits `noise_made(position, amount)` when `amount > 0.0`, then adds `amount * hearing(tiles) * noise_multiplier` with the existing threshold logic untouched. Do not touch callers yet (the suite will not compile until Task 2; run only this task's tests by name, then commit together with Task 2 if the runner aborts).

- [ ] **Step 4: Run the three tests.** Expected: PASS.

- [ ] **Step 5: Commit** `scripts/noise_meter.gd tests/test_rules.gd`: "M50: noise has a position; the base hears by distance".

### Task 2: Every noise event carries its position

**Files:**
- Modify: `scripts/mine.gd` (`tile_dug` signal, `dig_cells`, `tick_decay`), `scripts/player.gd` (none: `made_noise` stays, Main supplies the position), `scripts/main.gd`, `scripts/outpost.gd`, `scripts/vault_door.gd`, `scripts/gallery.gd`, `scripts/lift.gd`, `scripts/nest.gd`
- Modify: `tests/test_main.gd` (existing `add_noise(x)` calls get a position)
- Test: `tests/test_main.gd`

**Interfaces:**
- Consumes: Task 1's `add_noise(amount, position)`, `base_position`, `quiet_at`.
- Produces: `signal MineGrid.tile_dug(noise_amount: float, world_pos: Vector2)` (position of the last cell cleared); `func MineGrid.tick_decay(delta: float, player_pos: Vector2) -> Array` returning one `Vector2` world position per collapsed or crumbled cell (empty when no tick); `Main._on_tile_dug(noise_amount: float, world_pos: Vector2)`.

- [ ] **Step 1: Write the failing tests** in `tests/test_main.gd` and fix the three existing calls (`add_noise(50.0)` becomes `add_noise(50.0, main.player.global_position)`, likewise `add_noise(0.0, ...)`):

```gdscript
func test_the_base_hears_by_distance_below_the_quiet_floor() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.noise_meter.decay_rate = 0.0
	# The quiet layers reach about 150 rows down: plant the base below them so
	# only distance decides what it hears.
	var base_pos: Vector2 = main.mine.cell_to_world(Vector2i(80, main.mine.quiet_floor_row() + 10))
	main.run_base.global_position = base_pos
	main.noise_meter.add_noise(40.0, base_pos + Vector2(0, 20 * MineGrid.TILE_SIZE))
	assert_eq(main.noise_meter.noise, 30.0, "20 tiles from the base: three quarters")
	main.noise_meter.noise = 0.0
	main.noise_meter.add_noise(50.0, base_pos + Vector2(0, 90 * MineGrid.TILE_SIZE))
	assert_eq(main.noise_meter.noise, 0.0, "90 tiles from the base: inaudible")
	Progress.path_override = ""

func test_a_surface_base_hears_nothing_made_in_a_quiet_layer_and_replanting_moves_the_listener() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.noise_meter.decay_rate = 0.0
	var deep: Vector2 = main.mine.cell_to_world(Vector2i(80, main.mine.quiet_floor_row() + 40))
	main.noise_meter.add_noise(50.0, deep)
	assert_eq(main.noise_meter.noise, 0.0, "surface base: the deep is out of earshot")
	main.run_base.global_position = deep
	main.noise_meter.add_noise(50.0, deep)
	assert_eq(main.noise_meter.noise, 50.0, "replanted beside it: heard in full")
	Progress.path_override = ""

func test_digging_reports_where_it_happened() -> void:
	var mine: MineGrid = add(load("res://scenes/Mine.tscn").instantiate())
	var reports: Array = []
	mine.tile_dug.connect(func(amount, pos): reports.append(pos))
	var cell := Vector2i(40, 60)
	mine.fill_cell(cell)
	mine.dig_cells([cell])
	assert_eq(reports.size(), 1, "one dig, one report")
	assert_eq(reports[0], mine.cell_to_world(cell), "reported at the dug cell")
```

- [ ] **Step 2: Run to verify they fail.** Expected: script errors on the old signatures.

- [ ] **Step 3: Implement.** `MineGrid.dig_cells` emits `tile_dug(DIG_NOISE * dug_count, cell_to_world(last_dug_cell))`. `tick_decay` returns the cell positions instead of a float; `Main._process` calls `noise_meter.add_noise(MineGrid.DECAY_NOISE, pos)` per entry. In `Main._ready`: `noise_meter.quiet_at = func(pos): return mine.is_quiet_at(pos)` and `noise_meter.base_position = func(): return run_base.global_position`; `player.made_noise` connects to `func(amount): _on_tile_dug(amount, player.global_position)`. Positions for the other callers: gas cloud `world_pos`; `take_heart`, base plant, lamp, support, repair, fortify and bell/beacon builds use `player.global_position` (the player is at the act); `Outpost`, `VaultDoor`, `Gallery`, `Lift`, `Nest` pass their own `global_position`.

- [ ] **Step 4: Run the suite.** Expected: `69 passed, 0 failed` (63 + 3 from Task 1 + 3 here). Every pre-existing noise test (`test_quiet_layers...`, bell, outpost, vault, gallery, nest, heart, lift) still passes unchanged apart from the position argument.

- [ ] **Step 5: Commit** the listed files: "M50: every noise event carries its position".

### Task 3: The Stalker listens

**Files:**
- Modify: `scripts/stalker.gd`, `scripts/main.gd`
- Test: `tests/test_world.gd`

**Interfaces:**
- Consumes: `NoiseMeter.noise_made(position, amount)`.
- Produces: `const Stalker.HEARING_TILES := 30.0`; `const Stalker.ALERT_SECONDS := 4.0`; `var Stalker.alert_timer: float`; `func Stalker.alert() -> void` (sets `alert_timer = ALERT_SECONDS`, `retreat_timer = 0.0`); `Main._on_noise_made(position: Vector2, amount: float)`, connected in `_ready`, alerting every node in group `"stalkers"` within `Stalker.HEARING_TILES` tiles of `position`.

- [ ] **Step 1: Write the failing tests** in `tests/test_world.gd`:

```gdscript
func test_alerted_stalker_hunts_at_full_speed_and_stops_retreating() -> void:
	var player := _still_player(Vector2(1000, 1000), 0.0)
	var stalker: Stalker = add(StalkerScene.instantiate())
	stalker.player = player
	stalker.run_base = _base(Vector2(-5000, -5000))
	stalker.global_position = player.global_position + Vector2(400, 0) # far: lurking
	await physics_frames(3)
	assert_true(absf(stalker.velocity.length() - Stalker.HUNT_SPEED) < 1.0, "lurks at hunt speed")
	stalker.retreat_timer = 2.0
	stalker.alert()
	assert_eq(stalker.retreat_timer, 0.0, "alert clears the retreat")
	await physics_frames(3)
	assert_true(absf(stalker.velocity.length() - Stalker.SPEED) < 1.0, "alerted: full speed")
	stalker.alert_timer = 0.02
	await physics_frames(5)
	assert_true(absf(stalker.velocity.length() - Stalker.HUNT_SPEED) < 1.0, "alert wears off")

func test_alert_does_not_pull_a_stalker_into_the_base_light() -> void:
	var player := _still_player(Vector2(1000, 1000), 0.5)
	var base := _base(Vector2(1000, 1000))
	var stalker: Stalker = add(StalkerScene.instantiate())
	stalker.player = player
	stalker.run_base = base
	stalker.global_position = base.global_position + Vector2(20, 0) # inside the base light
	stalker.alert()
	var before := stalker.global_position.distance_to(base.global_position)
	await physics_frames(10)
	assert_true(stalker.global_position.distance_to(base.global_position) > before, "still pushed out of the base")
```

and in `tests/test_main.gd`:

```gdscript
func test_noise_alerts_only_stalkers_within_30_tiles() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.player.global_position = main.mine.cell_to_world(Vector2i(40, main.mine.quiet_floor_row() + 10))
	await tree.create_timer(0.2).timeout # wakes the first Stalker
	var stalker: Stalker = main.get_tree().get_nodes_in_group("stalkers")[0]
	stalker.global_position = main.player.global_position + Vector2(20 * MineGrid.TILE_SIZE, 0)
	main.noise_meter.add_noise(5.0, main.player.global_position)
	assert_eq(stalker.alert_timer, Stalker.ALERT_SECONDS, "20 tiles away hears it")
	stalker.alert_timer = 0.0
	stalker.global_position = main.player.global_position + Vector2(40 * MineGrid.TILE_SIZE, 0)
	main.noise_meter.add_noise(5.0, main.player.global_position)
	assert_eq(stalker.alert_timer, 0.0, "40 tiles away does not")
	Progress.path_override = ""
```

- [ ] **Step 2: Run to verify they fail.** Expected: `alert` / `alert_timer` not found.

- [ ] **Step 3: Implement.** In `Stalker._physics_process` decrement `alert_timer` with the other timers; in the `State.LURK` branch use `SPEED` while `alert_timer > 0.0` else `HUNT_SPEED`. The base-light push-out branch runs before everything and is left alone, which is what the second test pins.

- [ ] **Step 4: Run the suite.** Expected: `72 passed, 0 failed`.

- [ ] **Step 5: Commit** `scripts/stalker.gd scripts/main.gd tests/test_world.gd tests/test_main.gd`: "M50: loud acts alert a Stalker within 30 tiles for 4 s".

### Task 4: The mine's clock

**Files:**
- Create: `scripts/mine_clock.gd`
- Modify: `scripts/main.gd` (tick, `_spawn_wave`, shared Burrower spawn, `waves_spawned`, `_record_run`), `scripts/progress.gd:run_log_line`
- Test: `tests/test_rules.gd`, `tests/test_main.gd`

**Interfaces:**
- Produces: `class_name MineClock extends RefCounted` with `const MINE_WAKE_SECONDS := 240.0`, `WAVE_INTERVAL_START := 90.0`, `WAVE_INTERVAL_END := 45.0`, `WAVE_WARNING_SECONDS := 10.0`, `HEART_INTERVAL_MULTIPLIER := 0.5`; `static func wave_interval(run_seconds: float, carrying_heart: bool) -> float` (linear from 90 at 240 s to 45 at `MineGrid.DECAY_RAMP_TIME`, clamped, times 0.5 when carrying the Heart); `func tick(delta: float, run_seconds: float, carrying_heart: bool) -> String` returning `""`, `"warn"` (once per wave, when 10 s remain) or `"wave"`. Before `MINE_WAKE_SECONDS` it returns `""`; the first tick at or after it starts a countdown of `wave_interval`; each tick the countdown is capped at the current `wave_interval` so taking the Heart shortens a pending wave.
- Produces: `var Main.waves_spawned: int`; `func Main._spawn_wave() -> void` (a Burrower targeting the base, spawned `BURROWER_SPAWN_OFFSET_TILES` below the base); `"waves"` in the run record; both noise and wave spawns clamp their row to at least `mine.quiet_floor_row() + 1`.

- [ ] **Step 1: Write the failing tests** in `tests/test_rules.gd`:

```gdscript
func test_wave_interval_shrinks_with_the_decay_ramp_and_halves_with_the_heart() -> void:
	assert_eq(MineClock.wave_interval(240.0, false), 90.0, "starts at 90 s")
	assert_eq(MineClock.wave_interval(360.0, false), 67.5, "halfway down the ramp")
	assert_eq(MineClock.wave_interval(480.0, false), 45.0, "45 s at the end of the ramp")
	assert_eq(MineClock.wave_interval(2000.0, false), 45.0, "clamped after")
	assert_eq(MineClock.wave_interval(240.0, true), 45.0, "Heart halves it")

func test_clock_is_silent_until_240_then_warns_then_waves() -> void:
	var clock := MineClock.new()
	var t := 0.0
	var events: Array = []
	while t < 239.0:
		t += 1.0
		assert_eq(clock.tick(1.0, t, false), "", "silent before the mine wakes (t=%d)" % t)
	while t < 340.0 and events.size() < 2:
		t += 1.0
		var event := clock.tick(1.0, t, false)
		if event != "":
			events.append([event, t])
	assert_eq(events[0][0], "warn", "warning first")
	assert_eq(events[1][0], "wave", "then the wave")
	assert_true(absf((events[1][1] - events[0][1]) - MineClock.WAVE_WARNING_SECONDS) <= 1.0, "warning comes 10 s ahead")
	assert_true(events[1][1] >= 240.0 + 89.0 and events[1][1] <= 240.0 + 92.0, "first wave about 90 s after waking")

func test_taking_the_heart_shortens_a_pending_wave() -> void:
	var clock := MineClock.new()
	clock.tick(1.0, 240.0, false) # starts a 90 s countdown
	var event := ""
	var t := 240.0
	while event != "wave" and t < 300.0:
		t += 1.0
		event = clock.tick(1.0, t, true)
	assert_eq(event, "wave", "wave arrives within the halved interval")
	assert_true(t < 240.0 + 46.0, "about 45 s, not 90 (t=%d)" % t)

func test_run_log_counts_waves_and_old_entries_still_print() -> void:
	var line := Progress.run_log_line({"result": "Base fell", "seconds": 300, "depth": 50, "ore": 3, "burrowers": 1, "waves": 2, "seed": 7})
	assert_true(line.contains("2 waves"), "waves are shown")
	var old := Progress.run_log_line({"result": "Extracted", "seconds": 60, "depth": 5, "ore": 0, "burrowers": 0, "seed": 7})
	assert_true(not old.contains("wave"), "old entries unchanged")
```

and in `tests/test_main.gd`:

```gdscript
func test_a_wave_spawns_below_the_quiet_floor_and_is_counted_apart() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	var before: int = main.get_tree().get_nodes_in_group("burrowers").size()
	main._spawn_wave()
	var burrowers := main.get_tree().get_nodes_in_group("burrowers")
	assert_eq(burrowers.size(), before + 1, "one Burrower")
	assert_eq(main.waves_spawned, 1, "counted as a wave")
	assert_eq(main.burrowers_spawned, 0, "not as a noise Burrower")
	var floor_y: float = main.mine.cell_to_world(Vector2i(0, main.mine.quiet_floor_row())).y
	assert_true(burrowers[burrowers.size() - 1].global_position.y > floor_y, "never inside the quiet layers, even for a surface base")
	Progress.path_override = ""

func test_no_waves_after_the_run_ends() -> void:
	Progress.path_override = TEST_SAVE_PATH
	var main: Node = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(5)
	main.run_ended = true
	main.run_seconds = 1000.0
	var before: int = main.get_tree().get_nodes_in_group("burrowers").size()
	await physics_frames(30)
	assert_eq(main.get_tree().get_nodes_in_group("burrowers").size(), before, "a finished run sends nothing")
	Progress.path_override = ""
```

- [ ] **Step 2: Run to verify they fail.** Expected: `MineClock` not found.

- [ ] **Step 3: Implement.** Create `scripts/mine_clock.gd` to the interface above. In `Main._process`, after `run_seconds += delta` (already behind the `run_ended` guard): `match mine_clock.tick(delta, run_seconds, carrying_heart)` with `"warn"` playing `Sfx.play("alarm", -4.0)` only when `run_base.has_bell`, and `"wave"` calling `_spawn_wave()`. Factor the Burrower construction in `_on_noise_threshold` into one helper taking the spawn cell, used by both paths; `_burrower_spawn_position` clamps `cell.y` to `max(SURFACE_ROWS, quiet_floor_row() + 1)`. `_spawn_wave` increments `waves_spawned` (not `burrowers_spawned`) and spawns at the base's cell plus `(0, BURROWER_SPAWN_OFFSET_TILES)`. `_record_run` adds `"waves": waves_spawned`; `run_log_line` appends `", %d wave%s"` only when `waves > 0`.

- [ ] **Step 4: Run the suite.** Expected: `78 passed, 0 failed`.

- [ ] **Step 5: Commit** `scripts/mine_clock.gd scripts/main.gd scripts/progress.gd tests/test_rules.gd tests/test_main.gd`: "M50: the mine sends Burrowers on a clock from 240 s".

### Task 5: Docs, probe, playtest

**Files:**
- Modify: `README.md` (noise paragraph; add a "The mine's clock" paragraph after "The dark"), `ROADMAP.md` (M50 line under Quality pass), `tests/balance_probe.gd`
- Verify: `tests/playtest.gd`

- [ ] **Step 1: README and ROADMAP.** README: noise is positioned; the base hears by distance (full at the base, nothing at 80 tiles); a Stalker within 30 tiles of a loud act closes in at full speed for 4 s; from 240 s the mine sends a Burrower at the base every 90 s shrinking to 45 s (halved while carrying the Heart), the bell rings 10 s ahead. ROADMAP: "~~**M50 - Two listeners and the mine's clock.**~~ Done: noise carries a position, the base hears by distance, Stalkers hear loud acts, and the mine sends waves from 240 s. Spec: `docs/superpowers/specs/2026-10-09-run-loop-redesign-design.md`."

- [ ] **Step 2: Probe.** Record the current output first (`godot --headless --fixed-fps 60 -s tests/balance_probe.gd 2>&1 | grep -E "^(dive|dark)"`; the M49 numbers are dive 9/8/8 Burrowers). Add an `idle` bot to `tests/balance_probe.gd` that does nothing for 600 s (`_seconds(main, 600)`), and make the probe print waves (`"waves": main.waves_spawned` in the fallback entry). Expected after: dive bots' Burrower counts fall below 9/8/8 (deep digging is quiet to a surface base); the idle bot's log shows waves from about 330 s (240 s plus the first interval) and ends "Base fell" after 240 s if the waves can take the base within 600 s. If the idle bot survives to 600 s, report the numbers and do not retune (that is the M22 tuning pass). Paste before and after into the commit message.

- [ ] **Step 3: Playtest.** Run `xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd 2>&1 | grep -E "ok|FAIL|scenarios"`. Expected: `12 scenarios, 0 failed`.

- [ ] **Step 4: Commit and push** `README.md ROADMAP.md tests/balance_probe.gd`: "M50: two listeners and the mine's clock - docs and probe", then `git push -u origin ccr-55f79164-j8wgrv`.
