extends SceneTree

## Balance probe (quality pass): bots that play whole runs with real keys
## and everything live, over a few seeds, and print what happened - the
## numbers to compare before and after a tuning change.
##   godot --headless --fixed-fps 60 -s tests/balance_probe.gd
## dive: hold dig-down from the start until the run ends (or 150 s).
## dark: dig down 3 s, then stand still until the light fails.
## idle: do nothing for 600 s - only the mine's clock (waves) can end it.
## trip (run with `-- trip` after the script, and only this one runs): dig straight
## down to a target depth, then climb back out on ropes and extract - can the base kit
## get home from there before the light is gone? One line per depth and seed.
## Known result: in Stone the mine refills the shaft the bot dug, and a player on a rope
## cannot dig (Player._physics_process returns from the rope branch first), so a rope
## that ends under refilled rock strands it (the "on a rope under rock" seconds).

const SEEDS := [1001, 2002, 3003]
const TRIP_DEPTHS := [50, 100, 150, 200]
const TRIP_ROPE_GAP := 1.55 # just over Player.ROPE_PLACE_COOLDOWN
const TRIP_STUCK_SECONDS := 20.0 # no new height this long = give up
const SAVE_PATH := "user://probe_save.cfg"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	HUD.title_seen = true
	Progress.path_override = SAVE_PATH
	if OS.get_cmdline_user_args().has("trip"):
		await _run_trips()
		quit()
		return
	for probe in [["dive", _dive], ["dark", _dark], ["idle", _idle]]:
		for run_seed in SEEDS:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			MineGrid.next_seed = run_seed
			var main: Node = load("res://scenes/Main.tscn").instantiate()
			root.add_child(main)
			await physics_frame
			await probe[1].call(main)
			for key in [KEY_S]:
				_key(key, false)
			var entry: Dictionary = main.progress.run_log[0] if not main.progress.run_log.is_empty() else {
				"result": "Alive", "seconds": int(main.run_seconds), "depth": main.max_depth_reached,
				"ore": main.player.currency, "burrowers": main.burrowers_spawned, "waves": main.waves_spawned, "hits": main.player.hits_by, "seed": run_seed}
			print("%-5s %s" % [probe[0], Progress.run_log_line(entry)])
			paused = false
			root.remove_child(main)
			main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Sfx.stop_all()
	OS.delay_msec(100)
	await process_frame
	quit()

func _key(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func _seconds(main: Node, count: float) -> void:
	for i in range(int(count * 60)):
		await physics_frame
		if main.run_ended:
			return

func _dive(main: Node) -> void:
	_key(KEY_S, true)
	await _seconds(main, 150)

func _dark(main: Node) -> void:
	_key(KEY_S, true)
	await _seconds(main, 3)
	_key(KEY_S, false)
	await _seconds(main, 120)

func _idle(main: Node) -> void:
	await _seconds(main, 600)

func _run_trips() -> void:
	for depth in TRIP_DEPTHS:
		for run_seed in SEEDS:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
			MineGrid.next_seed = run_seed
			var main: Node = load("res://scenes/Main.tscn").instantiate()
			root.add_child(main)
			await physics_frame
			var report: Dictionary = await _trip(main, depth)
			print("trip  depth %3d seed %d: %s" % [depth, run_seed, _trip_line(main, report)])
			_key(KEY_S, false)
			_key(KEY_W, false)
			paused = false
			root.remove_child(main)
			main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Sfx.stop_all()
	OS.delay_msec(100)
	await process_frame

func _row(main: Node) -> int:
	return main.mine.world_to_cell(main.player.global_position).y - MineGrid.SURFACE_ROWS

## Digs down to `depth` rows, then climbs on ropes (R every TRIP_ROPE_GAP, W held) and
## extracts at the surface. Returns what happened and when.
func _trip(main: Node, depth: int) -> Dictionary:
	var report := {"outcome": "", "down": 0.0, "up": 0.0}
	var t := 0.0
	_key(KEY_S, true)
	while _row(main) < depth and not main.run_ended and t < 120.0:
		await physics_frame
		t += 1.0 / 60.0
	_key(KEY_S, false)
	report.down = t
	if main.run_ended:
		report.outcome = "ended on the way down"
		return report
	report.deepest = _row(main)
	_key(KEY_W, true)
	var up := 0.0
	var since_rope := TRIP_ROPE_GAP
	var best_row := _row(main)
	var best_at := 0.0
	var pinned := 0.0 # seconds on a rope with rock directly above
	while not main.run_ended and up < 240.0:
		await physics_frame
		up += 1.0 / 60.0
		since_rope += 1.0 / 60.0
		if main.player.is_on_rope() and main.mine.is_solid(main.mine.world_to_cell(main.player.global_position) + Vector2i.UP):
			pinned += 1.0 / 60.0
		if since_rope >= TRIP_ROPE_GAP:
			since_rope = 0.0
			_key(KEY_R, true)
			await physics_frame
			_key(KEY_R, false)
		if _row(main) < best_row:
			best_row = _row(main)
			best_at = up
		if main._at_surface():
			report.light_left = main.player.light.fuel
			report.health = main.player.health
			_key(KEY_W, false)
			_key(KEY_E, true)
			await physics_frame
			_key(KEY_E, false)
			await physics_frame
			break
		if up - best_at > TRIP_STUCK_SECONDS:
			report.outcome = "stuck at depth %d (no height gained for %d s; %.0f s of it on a rope under rock)" % [
				best_row, int(TRIP_STUCK_SECONDS), pinned]
			break
	report.up = up
	if report.outcome == "":
		report.outcome = "extracted" if main.run_ended and main.progress.run_log.size() > 0 and main.progress.run_log[0].result == "Extracted" else "ended"
	return report

func _trip_line(main: Node, report: Dictionary) -> String:
	var line := "%s - down %.0fs, up %.0fs" % [report.outcome, report.down, report.up]
	if main.progress.run_log.size() > 0:
		var entry: Dictionary = main.progress.run_log[0]
		if entry.result != "Extracted":
			line += ", %s" % entry.result
			if not entry.hits.is_empty():
				line += " (%s)" % ", ".join(entry.hits.keys().map(func(k): return "%s %d" % [k, entry.hits[k]]))
	if report.has("light_left"):
		line += ", %.0fs of light and %d health left" % [report.light_left, report.health]
	return line
