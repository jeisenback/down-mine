extends SceneTree

## Balance probe (quality pass): bots that play whole runs with real keys
## and everything live, over a few seeds, and print what happened - the
## numbers to compare before and after a tuning change.
##   godot --headless --fixed-fps 60 -s tests/balance_probe.gd
## dive: hold dig-down from the start until the run ends (or 150 s).
## dark: dig down 3 s, then stand still until the light fails.
## idle: do nothing for 600 s - only the mine's clock (waves) can end it.

const SEEDS := [1001, 2002, 3003]
const SAVE_PATH := "user://probe_save.cfg"

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	HUD.title_seen = true
	Progress.path_override = SAVE_PATH
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
