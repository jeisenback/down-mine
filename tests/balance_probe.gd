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
## In Stone the mine refills the shaft the bot dug; the bot digs up (W + Space) through
## rock over its rope, as a player can since a rope no longer stops digging. "seconds on a
## rope under rock" counts how long it was pinned.
## heart (`-- heart`, only this one runs): with the lantern at level 3, walk the surface to above
## the Heart, dig straight down onto its room, take it, climb home on ropes and extract. No fuel
## detours, no fighting: the worst case for the win. One line per seed. Add `flare` (`-- heart flare`)
## and it also holds Shift while a Stalker is within FLARE_RANGE px and the lantern is at or under a
## quarter, which is when a Stalker strikes unless you flare. Add `detour=N` and it models taking fuel
## pickups near its shaft: each pickup within DETOUR_TILES of the column it passes is removed, adds its
## light and costs N seconds of light (the travel, paid as burned fuel); none is taken when the lantern
## is nearly full. The detour is modelled, not walked: the output is the break-even N for the win.

const SEEDS := [1001, 2002, 3003]
const TRIP_DEPTHS := [50, 100, 150, 200]
const HEART_SEEDS := [1001, 2002, 3003, 1, 2, 3] # the Heart is 19 to 66 tiles off the shaft
const HEART_KIT := {"lantern": 3}
const FLARE_RANGE := 150.0
const DETOUR_TILES := 6
var _detour_cost := -1.0 # seconds of light a detour costs; negative = no detours (`-- heart detour=N`)
var _pickups: Array = []
var _picked := 0
const STRIKE_FUEL_FRACTION := 0.25 # Stalker.STRIKE_FUEL_FRACTION
var _flare_on := false # set by `-- heart flare`
var _flaring := false
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
	if OS.get_cmdline_user_args().has("heart"):
		_flare_on = OS.get_cmdline_user_args().has("flare")
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("detour="):
				_detour_cost = float(arg.substr(7))
		await _run_hearts()
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

## Digs down to `depth` rows, then climbs home (see _climb_home). Returns what happened and when.
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
	await _climb_home(main, report)
	return report

## Climbs on ropes (R every TRIP_ROPE_GAP, W held), digging up through rock that is over it,
## and extracts at the surface. Fills report.up, outcome, and light_left / health on arrival.
func _climb_home(main: Node, report: Dictionary) -> void:
	_key(KEY_W, true)
	var up := 0.0
	var since_rope := TRIP_ROPE_GAP
	var best_row := _row(main)
	var best_at := 0.0
	var pinned := 0.0 # seconds on a rope with rock directly above
	var digging := false # Space held: dig up through rock the mine has refilled over the shaft
	while not main.run_ended and up < 240.0:
		await physics_frame
		up += 1.0 / 60.0
		since_rope += 1.0 / 60.0
		_flare(main)
		_detour(main)
		var blocked: bool = main.mine.is_solid(main.mine.world_to_cell(main.player.global_position) + Vector2i.UP)
		if blocked and main.player.is_on_rope():
			pinned += 1.0 / 60.0
		if blocked != digging:
			digging = blocked
			_key(KEY_SPACE, digging)
		if since_rope >= TRIP_ROPE_GAP:
			since_rope = 0.0
			await _tap(KEY_R)
		if _row(main) < best_row:
			best_row = _row(main)
			best_at = up
		if main._at_surface():
			report.light_left = main.player.light.fuel
			report.health = main.player.health
			_key(KEY_W, false)
			await _tap(KEY_E)
			break
		if up - best_at > TRIP_STUCK_SECONDS:
			report.outcome = "stuck at depth %d (no height gained for %d s; %.0f s of it on a rope under rock)" % [
				best_row, int(TRIP_STUCK_SECONDS), pinned]
			break
	_key(KEY_SPACE, false)
	_key(KEY_W, false)
	_set_flare(false)
	report.up = up
	if report.outcome == "":
		var result: String = main.progress.run_log[0].result if main.run_ended and main.progress.run_log.size() > 0 else ""
		report.outcome = result if result in ["Extracted", "Heart claimed"] else "ended"

## With `flare`: Shift held while a Stalker is within FLARE_RANGE and the lantern is at or under a quarter.
func _flare(main: Node) -> void:
	if not _flare_on:
		return
	var near := false
	if main.player.light.fuel_fraction() <= STRIKE_FUEL_FRACTION:
		for stalker in main.get_tree().get_nodes_in_group(Groups.STALKERS):
			if stalker.global_position.distance_to(main.player.global_position) < FLARE_RANGE:
				near = true
	_set_flare(near)

## With `detour=N`: takes a pickup near the shaft as the player passes its row, paying N seconds of light.
func _detour(main: Node) -> void:
	if _pickups.is_empty():
		return
	var light: MineLight = main.player.light
	if light.max_fuel - light.fuel < 10.0:
		return
	for pickup in _pickups:
		if is_instance_valid(pickup) and absf(pickup.global_position.y - main.player.global_position.y) < 24.0:
			light.fuel = clampf(light.fuel + pickup.fuel_amount - _detour_cost, 0.0, light.max_fuel)
			_pickups.erase(pickup)
			pickup.queue_free()
			_picked += 1
			return

func _set_flare(on: bool) -> void:
	if on != _flaring:
		_flaring = on
		_key(KEY_SHIFT, on)

func _tap(code: int) -> void:
	_key(code, true)
	await physics_frame
	_key(code, false)
	await physics_frame

func _trip_line(main: Node, report: Dictionary) -> String:
	var line := "%s - down %.0fs, up %.0fs" % [report.outcome, report.down, report.up]
	if report.has("across"):
		line = "%s - across %.0fs, down %.0fs, up %.0fs" % [report.outcome, report.across, report.down, report.up]
	if main.progress.run_log.size() > 0:
		var entry: Dictionary = main.progress.run_log[0]
		if entry.result != "Extracted" and entry.result != "Heart claimed":
			line += ", %s" % entry.result
			if not entry.hits.is_empty():
				line += " (%s)" % ", ".join(entry.hits.keys().map(func(k): return "%s %d" % [k, entry.hits[k]]))
	if report.has("light_left"):
		line += ", %.0fs of light and %d health left" % [report.light_left, report.health]
	if _detour_cost >= 0.0:
		line += ", %d pickups at %.0fs each" % [_picked, _detour_cost]
	return line

# --- the Heart run -----------------------------------------------------------------

func _run_hearts() -> void:
	for run_seed in HEART_SEEDS:
		var cfg := ConfigFile.new()
		for id in HEART_KIT:
			cfg.set_value("upgrades", id, HEART_KIT[id])
		cfg.save(SAVE_PATH)
		MineGrid.next_seed = run_seed
		var main: Node = load("res://scenes/Main.tscn").instantiate()
		root.add_child(main)
		await physics_frame
		var across := absi(_heart_cell(main).x - main.mine.shaft_column())
		var report: Dictionary = await _heart(main)
		print("heart seed %d (%d across): %s" % [run_seed, across, _trip_line(main, report)])
		for code in [KEY_S, KEY_W, KEY_A, KEY_D, KEY_SPACE]:
			_key(code, false)
		paused = false
		root.remove_child(main)
		main.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Sfx.stop_all()
	OS.delay_msec(100)
	await process_frame

func _heart_node(main: Node) -> Node2D:
	return main.get_tree().get_nodes_in_group(Groups.MINE_EVENTS).filter(func(e): return e is Heart)[0]

func _heart_cell(main: Node) -> Vector2i:
	return main.mine.world_to_cell(_heart_node(main).global_position)

## Walks the surface to above the Heart, digs straight down onto its room, takes it, and climbs the
## same shaft home. (The bot knows where the Heart is; a tunnel across at the bottom was tried first
## and the bottom layer's caves drop the player well past the Heart's row, so it could not be aimed.)
func _heart(main: Node) -> Dictionary:
	var report := {"outcome": "", "across": 0.0, "down": 0.0, "up": 0.0}
	var heart_cell := _heart_cell(main)
	var heart_x: float = main.mine.cell_to_world(heart_cell).x
	_pickups = []
	_picked = 0
	if _detour_cost >= 0.0:
		_pickups = main.mine.get_children().filter(func(c): return c is FuelPickup and absf(c.global_position.x - heart_x) <= DETOUR_TILES * MineGrid.TILE_SIZE)
	report.across = await _walk_to(main, heart_x)
	if report.across < 0.0:
		report.across = 0.0
		report.outcome = "could not walk to above the Heart"
		return report
	var t := 0.0
	_key(KEY_S, true)
	# Into the room's open rows (it is 4 tall; its floor is the Heart's row + 1), then let go and land.
	while main.mine.world_to_cell(main.player.global_position).y < heart_cell.y - 2 and not main.run_ended and t < 150.0:
		await physics_frame
		t += 1.0 / 60.0
		_flare(main)
		_detour(main)
	_key(KEY_S, false)
	var waited := 0
	while not main.player.is_on_floor() and waited < 120 and not main.run_ended:
		await physics_frame
		waited += 1
		_flare(main)
	report.down = t
	if main.run_ended:
		report.outcome = "ended on the way down"
		return report
	await _tap(KEY_E)
	if not main.carrying_heart:
		report.outcome = "could not take the Heart (%d px away)" % int(main.player.global_position.distance_to(_heart_node(main).global_position))
		return report
	await _climb_home(main, report)
	return report

## Holds A or D until the player is within 8 px of x. Returns the seconds taken, or -1 if it gets
## nowhere in 30 s or the run ends.
func _walk_to(main: Node, x: float) -> float:
	var key := KEY_A if x < main.player.global_position.x else KEY_D
	_key(key, true)
	var t := 0.0
	while not main.run_ended and t < 30.0:
		await physics_frame
		t += 1.0 / 60.0
		if absf(x - main.player.global_position.x) < 8.0:
			_key(key, false)
			return t
	_key(key, false)
	return -1.0
