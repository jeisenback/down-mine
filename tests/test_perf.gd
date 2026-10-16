extends TestCase

## A performance smoke test: generous limits, from a measured baseline (headless, seed 1001, a
## deep gallery with 47 lights: median 0.85 ms a frame, p95 1.3 to 2.7 ms, max 3.5 to 5.7 ms;
## a decay tick with 2000 dug cells 0.05 to 0.11 ms when most are eligible, about 8 ms in the
## worst case this test builds: 1990 of 2000 dug cells lit, so the lazy scan skips about 200 of
## them). Limits leave 3 to 10 times of headroom, because CI machines are slower and noisy. Set PERF_SLACK (a number, default 1) to relax every limit on a
## slow machine. Every failure prints the measured numbers.

const SOURCE := "test"
const WARM_UP_FRAMES := 60
const RUN_FRAMES := 300
const MEDIAN_MS := 4.0
const P95_MS := 10.0
const MAX_MS := 40.0
const DECAY_TICK_MS := 25.0 # the worst case measured below is about 7 ms; the #94 filter took about 90
const DUG_CELLS := 2000
const TORCHES := 60
const MIN_LIT_CELLS := 300
const DARK_CELLS := 10

static func slack() -> float:
	return maxf(1.0, float(OS.get_environment("PERF_SLACK")) if OS.get_environment("PERF_SLACK") != "" else 1.0)

func _main() -> Main:
	Progress.path_override = TEST_SAVE_PATH
	var fresh := Progress.new()
	fresh.save_path = TEST_SAVE_PATH
	fresh.save()
	HUD.title_seen = true
	MineGrid.next_seed = 1001
	var main: Main = add(load("res://scenes/Main.tscn").instantiate())
	main.mine.decay_multiplier = 1000.0
	main.player.invincible = true
	main.player.light.burn_rate = 0.0
	return main

## Milliseconds of each of `frames` physics frames.
func _frame_times(frames: int) -> Array[float]:
	var times: Array[float] = []
	for i in range(frames):
		var started := Time.get_ticks_usec()
		await tree.physics_frame
		times.append((Time.get_ticks_usec() - started) / 1000.0)
	return times

func _check_run(label: String, times: Array[float]) -> void:
	var sorted := times.duplicate()
	sorted.sort()
	var median: float = sorted[sorted.size() / 2]
	var p95: float = sorted[int(sorted.size() * 0.95)]
	var worst: float = sorted[-1]
	print("perf %s: median %.2f ms, p95 %.2f ms, max %.2f ms" % [label, median, p95, worst])
	var s := slack()
	assert_true(median < MEDIAN_MS * s, "%s: median %.2f ms over %.1f" % [label, median, MEDIAN_MS * s])
	assert_true(p95 < P95_MS * s, "%s: p95 %.2f ms over %.1f" % [label, p95, P95_MS * s])
	assert_true(worst < MAX_MS * s, "%s: max %.2f ms over %.1f" % [label, worst, MAX_MS * s])

func test_a_frame_in_a_deep_gallery_stays_within_budget() -> void:
	var main := await _main()
	var spine: Drift = null
	for drift in main.mine.drifts:
		if drift.layer == 4 and not drift.from_shaft:
			spine = drift
	assert_true(spine != null, "a layer 4 spine")
	if spine == null:
		Progress.path_override = ""
		return
	# The first open stretch of the spine (the mid-spine cells can lie inside a collapse, which is rock).
	main.player.global_position = main.mine.cell_to_world(Vector2i(spine.x0 + spine.side * 2, spine.row))
	await physics_frames(WARM_UP_FRAMES) # the first frames after loading Main cost up to a second
	_check_run("idle", await _frame_times(RUN_FRAMES))
	var before := main.player.global_position
	TouchKeys.set_key(KEY_D if spine.side > 0 else KEY_A, true, SOURCE)
	_check_run("walking", await _frame_times(RUN_FRAMES))
	TouchKeys.release_all(SOURCE)
	var walked := absf(main.player.global_position.x - before.x) / MineGrid.TILE_SIZE
	assert_true(walked >= 3.0, "the walking run really walked: %.1f tiles" % walked)
	before = main.player.global_position
	TouchKeys.set_key(KEY_S, true, SOURCE)
	_check_run("digging down", await _frame_times(RUN_FRAMES))
	TouchKeys.release_all(SOURCE)
	var dug := (main.player.global_position.y - before.y) / MineGrid.TILE_SIZE
	assert_true(dug >= 2.0, "the digging run really descended: %.1f tiles" % dug)
	Progress.path_override = ""

func test_a_decay_tick_with_many_dug_cells_stays_within_budget() -> void:
	var mine: MineGrid = add(load("res://scenes/Mine.tscn").instantiate())
	var open: Array[Vector2i] = []
	for y in range(MineGrid.SURFACE_ROWS + 1, MineGrid.GRID_HEIGHT):
		for x in range(MineGrid.GRID_WIDTH):
			if not mine.is_solid(Vector2i(x, y)):
				open.append(Vector2i(x, y))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(TORCHES):
		var torch: Node2D = add(load("res://scenes/Torch.tscn").instantiate())
		torch.global_position = mine.cell_to_world(open[rng.randi_range(0, open.size() - 1)])
	await physics_frames(2)
	# The slow case: nearly every dug cell is lit (so skipped), a few are dark and eligible.
	var lit: Array[Vector2i] = []
	var dark: Array[Vector2i] = []
	for cell in open:
		if mine.is_lit(mine.cell_to_world(cell)):
			lit.append(cell)
		elif dark.size() < DARK_CELLS:
			dark.append(cell)
	assert_true(lit.size() >= MIN_LIT_CELLS, "enough lit cells to skip: %d" % lit.size())
	var dug: Array[Vector2i] = []
	dug.append_array(lit.slice(0, DUG_CELLS - DARK_CELLS))
	dug.append_array(dark)
	var total_ms := 0.0
	for i in range(10):
		mine._dug_cells.assign(dug)
		var started := Time.get_ticks_usec()
		var picked := mine._collapse_tunnel()
		total_ms += (Time.get_ticks_usec() - started) / 1000.0
		assert_true(picked in dark, "picked one of the few dark cells")
	var mean := total_ms / 10.0
	print("perf decay tick with %d dug cells (%d lit, %d dark), %d torches: mean %.3f ms" % [dug.size(), dug.size() - DARK_CELLS, DARK_CELLS, TORCHES, mean])
	assert_true(mean < DECAY_TICK_MS * slack(), "decay tick mean %.3f ms over %.1f" % [mean, DECAY_TICK_MS * slack()])
