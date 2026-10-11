extends SceneTree

## Playtest runner (milestone 44): plays scripted scenarios in the real
## game - fixed seed, real key events - checks the outcome and saves a
## screenshot per step to playtest_out/. Needs a display, so run it under
## a virtual one:
##   xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd
## CI runs it on every pull request and attaches the screenshots.
## Exits 1 if any scenario fails.

const SEED := 1001
## A seed whose Topsoil gallery (no collapsed section) crosses caves on planks.
const PLANK_SEED := 8
## A seed whose Topsoil gallery mouth has an old ladder piece at its row.
const LANDING_SEED := 1
const OUT_DIR := "res://playtest_out"
const SAVE_PATH := "user://playtest_save.cfg"

var main: Node
var failures: Array[String] = []
var _scenario: String = ""
var _shot_index: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	Progress.path_override = SAVE_PATH
	var scenarios := [
		["title_and_controls", _title_and_controls],
		["dig_down", _dig_down],
		["step_up_and_mantle", _step_up_and_mantle],
		["camp_search", _camp_search],
		["heart_run", _heart_run],
		["tunnel_and_staircase", _tunnel_and_staircase],
		["ropes_up_a_shaft", _ropes_up_a_shaft],
		["rope_down_a_pit", _rope_down_a_pit],
		["ladder_out_of_a_pit", _ladder_out_of_a_pit],
		["anchor_out_of_a_pit", _anchor_out_of_a_pit],
		["grapple_to_ceiling", _grapple_to_ceiling],
		["bumps_and_dig_rhythm", _bumps_and_dig_rhythm],
		["shaft_ladder_climb", _shaft_ladder_climb],
		["shaft_ladder_gap", _shaft_ladder_gap],
		["shaft_end_from_stone", _shaft_end_from_stone],
		["shaft_end_with_ladder", _shaft_end_with_ladder],
		["drift_to_camp", _drift_to_camp],
		["drift_collapse", _drift_collapse],
		["drift_planks", _drift_planks],
		["drift_from_the_ladder", _drift_from_the_ladder],
		["shaft_lift_ride", _shaft_lift_ride],
		["shaft_lift_from_the_ladder", _shaft_lift_from_the_ladder],
		["shaft_from_below", _shaft_from_below],
		["base_grows_in_tiers", _base_grows_in_tiers],
		["wave_meets_the_base_light", _wave_meets_the_base_light],
		["drawn_art_on_screen", _drawn_art_on_screen],
		["crew_jobs_at_work", _crew_jobs_at_work],
		["hub_buy_crew_and_descend", _hub_buy_crew_and_descend],
		["touch_controls_play", _touch_controls_play],
		["touch_hub_buy", _touch_hub_buy],
	]
	var failed := 0
	for entry in scenarios:
		_scenario = entry[0]
		_shot_index = 0
		failures.clear()
		await entry[1].call()
		_end_game()
		if failures.is_empty():
			print("  ok    ", _scenario)
		else:
			failed += 1
			print("  FAIL  ", _scenario)
			for f in failures:
				print("          ", f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	Sfx.stop_all()
	OS.delay_msec(100)
	await process_frame
	print("%d scenarios, %d failed; screenshots in playtest_out/" % [scenarios.size(), failed])
	quit(1 if failed > 0 else 0)

# --- helpers -------------------------------------------------------------

func _start_game(show_title: bool = false, seed_value: int = SEED) -> void:
	HUD.title_seen = not show_title
	MineGrid.next_seed = seed_value
	paused = false
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await frames(10)

func _end_game() -> void:
	for key in [KEY_A, KEY_D, KEY_W, KEY_S, KEY_E, KEY_SPACE]:
		key_event(key, false)
	paused = false
	if is_instance_valid(main):
		root.remove_child(main)
		main.free()

func frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func key_event(code: int, down: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = down
	Input.parse_input_event(e)

func tap(code: int) -> void:
	key_event(code, true)
	await frames(3)
	key_event(code, false)
	await frames(3)

## Holds the keys for the given number of physics frames (60 per second).
func hold(codes: Array, count: int) -> void:
	for code in codes:
		key_event(code, true)
	await frames(count)
	for code in codes:
		key_event(code, false)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func shot(label: String) -> void:
	await process_frame
	await process_frame
	_shot_index += 1
	var path := "%s/%s_%d_%s.png" % [OUT_DIR, _scenario, _shot_index, label]
	root.get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))

func teleport(cell: Vector2i) -> void:
	main.player.global_position = main.mine.cell_to_world(cell)
	main.player.velocity = Vector2.ZERO

# --- scenarios ------------------------------------------------------------

func _title_and_controls() -> void:
	await _start_game(true)
	check(not TouchControls.wanted(), "a desktop with a keyboard shows no touch controls")
	check(paused and main.hud.overlay.visible, "title shows and pauses")
	await shot("title")
	await tap(KEY_ENTER)
	check(not paused, "Enter starts")
	await tap(KEY_ESCAPE)
	check(paused and main.hud._overlay_label.text.begins_with("CONTROLS"), "Esc shows controls")
	await shot("controls")
	await tap(KEY_ESCAPE)
	check(not paused, "Esc closes controls")

func _dig_down() -> void:
	await _start_game()
	var start_y: float = main.player.global_position.y
	await hold([KEY_S], 120)
	await frames(30)
	check(main.player.global_position.y > start_y + 2 * MineGrid.TILE_SIZE, "holding S digs down")
	await shot("dug_down")

## A flat course: a 1-tile bump, a 2-tile wall, then a 3-tile wall.
func _step_up_and_mantle() -> void:
	await _start_game()
	var mine: MineGrid = main.mine
	var o := Vector2i(10, 30)
	for x in range(o.x, o.x + 30):
		for y in range(o.y, o.y + 8):
			mine.set_cell(0, Vector2i(x, y), -1)
		mine.fill_cell(Vector2i(x, o.y + 8))
	mine.fill_cell(Vector2i(o.x + 6, o.y + 7))
	for x in range(o.x + 12, o.x + 14):
		for h in range(2):
			mine.fill_cell(Vector2i(x, o.y + 7 - h))
	for x in range(o.x + 20, o.x + 30):
		for h in range(3):
			mine.fill_cell(Vector2i(x, o.y + 7 - h))
	teleport(o + Vector2i(2, 7))
	await frames(20)
	await walk_right_until(o.x + 11, 90)
	check(mine.world_to_cell(main.player.global_position).x >= o.x + 11, "walked over the 1-tile bump")
	await jump_right()
	check(mine.world_to_cell(main.player.global_position).x > o.x + 13, "mantled the 2-tile wall")
	await walk_right_until(o.x + 19, 90)
	await jump_right()
	check(mine.world_to_cell(main.player.global_position).x < o.x + 20, "3-tile wall still blocks")
	await shot("course")

## Holds D until the player reaches cell column x (or the frames run out).
func walk_right_until(x: int, max_frames: int) -> void:
	key_event(KEY_D, true)
	for i in range(max_frames):
		await physics_frame
		if main.mine.world_to_cell(main.player.global_position).x >= x:
			break
	key_event(KEY_D, false)
	await frames(10)

## A full jump while holding right, then time to land.
func jump_right() -> void:
	key_event(KEY_D, true)
	await hold([KEY_W], 30)
	await frames(40)
	key_event(KEY_D, false)
	await frames(10)

func _camp_search() -> void:
	await _start_game()
	var camp: Camp = main.get_tree().get_nodes_in_group("mine_events").filter(func(e): return e is Camp)[0]
	teleport(main.mine.world_to_cell(camp.global_position)) # its own cell: a gallery camp has a cave beside it
	await frames(20)
	var ore: int = main.player.currency
	await tap(KEY_E)
	check(camp.searched, "E searched the camp")
	check(main.player.currency > ore, "camp gave ore")
	check(main.hud.prompt_label.text.contains("Journal"), "journal page shown")
	await shot("searched")

func _heart_run() -> void:
	await _start_game()
	var heart: Heart = main.get_tree().get_nodes_in_group("mine_events").filter(func(e): return e is Heart)[0]
	teleport(main.mine.world_to_cell(heart.global_position) + Vector2i(-1, 0))
	await frames(20)
	await tap(KEY_E)
	check(main.carrying_heart, "E took the Heart")
	await shot("taken")
	var surface := Vector2i(main.mine.world_to_cell(main.run_base.global_position).x, MineGrid.SURFACE_ROWS - 1)
	teleport(surface)
	await frames(20)
	await tap(KEY_E)
	check(main.hud.run_summary.visible and main.hud.run_summary_label.text.contains("The Heart is yours!"), "extracting with the Heart wins")
	await shot("won")
	check(main.hud.run_summary_label.text.contains("Enter: go to the hub"), "the summary leads to the hub")
	check(main.progress.run_log[0].result == "Heart claimed", "the win is in the run log")
	await shot("run_log")

# --- movement courses (movement pass) --------------------------------------
# A solid block with a room 5 tiles tall; the room's floor is row C.y + 10.

const C := Vector2i(20, 40)

func _course() -> void:
	await _start_game()
	main.player.light.burn_rate = 0.0
	main.player.invincible = true # courses test movement, not survival
	main.player.ladders_left = 4
	main.player.anchors_left = 2
	_fill(C.x, C.y, C.x + 40, C.y + 16, true)
	_fill(C.x + 1, C.y + 5, C.x + 39, C.y + 9, false)

func _fill(x0: int, y0: int, x1: int, y1: int, solid: bool) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			if solid:
				main.mine.fill_cell(Vector2i(x, y))
			else:
				main.mine.set_cell(0, Vector2i(x, y), -1)

## Teleports once tile edits have reached the physics server (next frame).
func _place(cell: Vector2i) -> void:
	await frames(3)
	teleport(cell)
	await frames(20)

func _cell() -> Vector2i:
	return main.mine.world_to_cell(main.player.global_position)

func _on_room_floor() -> bool:
	return _cell().y <= C.y + 9

func _tunnel_and_staircase() -> void:
	await _course()
	await _place(C + Vector2i(20, 9))
	await hold([KEY_SPACE, KEY_D], 120)
	check(_cell().x >= C.x + 26 and _cell().y == C.y + 9, "Space+D tunnels sideways")
	await _place(C + Vector2i(3, 9))
	await hold([KEY_S, KEY_D], 120)
	check(_cell().x > C.x + 5 and _cell().y > C.y + 11, "S+D digs a staircase down")
	await shot("dug")

func _ropes_up_a_shaft() -> void:
	await _course()
	_fill(C.x + 10, C.y + 10, C.x + 10, C.y + 16, false) # 7-deep shaft
	await _place(C + Vector2i(10, 16))
	for i in range(3):
		await tap(KEY_R)
		await hold([KEY_W], 80)
		await frames(95) # rope cooldown
	key_event(KEY_W, true)
	await hold([KEY_D], 40)
	key_event(KEY_W, false)
	await frames(30)
	check(_on_room_floor(), "thrown ropes climb out of a 7-deep shaft")
	await shot("out")

func _rope_down_a_pit() -> void:
	await _course()
	_fill(C.x + 10, C.y + 10, C.x + 10, C.y + 14, false) # 5-deep pit
	await _place(C + Vector2i(9, 9))
	await hold([KEY_D], 2) # face the pit
	key_event(KEY_S, true)
	await tap(KEY_R)
	key_event(KEY_S, false)
	await hold([KEY_D], 14)
	await hold([KEY_S], 60)
	check(_cell().y >= C.y + 12, "S+R rope hangs into the pit; climbed down it")
	await shot("in_pit")
	await hold([KEY_W], 120)
	key_event(KEY_W, true)
	await hold([KEY_A], 40)
	key_event(KEY_W, false)
	await frames(20)
	check(_on_room_floor(), "climbed back out")

func _ladder_out_of_a_pit() -> void:
	await _course()
	_fill(C.x + 10, C.y + 10, C.x + 10, C.y + 13, false) # 4-deep pit
	await _place(C + Vector2i(10, 13))
	await tap(KEY_T)
	await hold([KEY_W], 90)
	key_event(KEY_W, true)
	await hold([KEY_D], 40)
	key_event(KEY_W, false)
	await frames(20)
	check(_on_room_floor(), "ladder climbs out of a 4-deep pit")
	await shot("out")

func _anchor_out_of_a_pit() -> void:
	await _course()
	_fill(C.x + 10, C.y + 10, C.x + 10, C.y + 13, false) # 4-deep pit
	await _place(C + Vector2i(9, 9))
	await tap(KEY_G)
	await _place(C + Vector2i(10, 13))
	await tap(KEY_Q)
	await frames(60)
	check(_on_room_floor(), "grapple pulls up the pit and over to the anchor")
	await shot("pulled")

func _grapple_to_ceiling() -> void:
	await _course()
	await _place(C + Vector2i(12, 9))
	var start: Vector2i = _cell()
	await tap(KEY_Q)
	await frames(20)
	check(_cell().y < start.y, "grapple lifts to the ceiling")
	await shot("up")

## Movement quality pass: bumps are stepped over with Space held, a
## staircase drops exactly one row per step, and digging down never
## lands on the undug cell.
func _bumps_and_dig_rhythm() -> void:
	await _course()
	var bumps: Array[Vector2i] = []
	for x in [8, 12, 16, 20]:
		bumps.append(C + Vector2i(x, 9))
		main.mine.fill_cell(bumps[-1])
	await _place(C + Vector2i(4, 9))
	await hold([KEY_SPACE, KEY_D], 150) # 18 tiles at walking speed, 4 of them steps
	check(_cell().x >= C.x + 22, "Space+D walks over 1-tile bumps (reached column %d)" % (_cell().x - C.x))
	check(bumps.all(func(b): return main.mine.is_solid(b)), "bumps stepped over, not dug")
	await shot("bumps")

	await _place(C + Vector2i(26, 9))
	await hold([KEY_S, KEY_D], 120)
	var floors: Array[int] = []
	for x in range(C.x + 27, _cell().x + 1):
		var floor_y := C.y + 9
		for y in range(C.y + 10, C.y + 17):
			if not main.mine.is_solid(Vector2i(x, y)):
				floor_y = y
		floors.append(floor_y)
	var regular := floors.size() >= 3
	for i in range(1, floors.size()):
		regular = regular and floors[i] == floors[i - 1] + 1
	check(regular, "S+D stairs drop one row per column (floors %s)" % [floors])
	await shot("stairs")

	_fill(C.x + 30, C.y + 10, C.x + 32, C.y + 40, true) # a deep solid column
	await _place(C + Vector2i(31, 9))
	var start_y: int = _cell().y
	var landings := 0
	key_event(KEY_S, true)
	for i in range(120):
		await physics_frame
		var below: Vector2i = _cell() + Vector2i.DOWN
		if main.player.is_on_floor() and main.mine.is_solid(below) and not main.mine.is_indestructible(below):
			landings += 1
	key_event(KEY_S, false)
	check(landings <= 2, "digging down never waits on the undug cell (%d floor frames)" % landings)
	check(_cell().y >= start_y + 12, "steady descent keeps its pace (%d rows in 2s)" % (_cell().y - start_y))
	await shot("dug_down")

# --- the old mine (milestone 51) -------------------------------------------

func _in_shaft(seed_value: int = SEED) -> void:
	await _start_game(false, seed_value)
	main.player.light.burn_rate = 0.0
	main.player.invincible = true # these test the climb, not the fall

## Climbs the old ladder where two pieces meet.
func _shaft_ladder_climb() -> void:
	await _in_shaft()
	var rows: Array = main.mine.old_ladder_rows
	var contiguous := -1
	for i in range(rows.size() - 1):
		if rows[i + 1] - rows[i] == MineGrid.OLD_LADDER_PIECE_ROWS:
			contiguous = i
			break
	check(contiguous >= 0, "seed %d has two contiguous ladder pieces" % SEED)
	if contiguous < 0:
		return
	var start := Vector2i(main.mine.shaft_column(), rows[contiguous + 1] + 6)
	await _place(start)
	await shot("bottom")
	await hold([KEY_W], 120)
	check(start.y - _cell().y >= 8, "the old ladder climbs at least 8 rows (from row %d to %d)" % [start.y, _cell().y])
	await shot("top")

## Crosses a missing piece by chaining two thrown ropes onto the next piece.
func _shaft_ladder_gap() -> void:
	await _in_shaft()
	var rows: Array = main.mine.old_ladder_rows
	var gap := -1
	for i in range(rows.size() - 1):
		if rows[i + 1] - rows[i] > MineGrid.OLD_LADDER_PIECE_ROWS:
			gap = i
			break
	check(gap >= 0, "seed %d has a missing piece" % SEED)
	if gap < 0:
		return
	var upper_bottom: int = rows[gap] + MineGrid.OLD_LADDER_PIECE_ROWS - 1 # last row of the piece above the gap
	var lower_top: int = rows[gap + 1]
	await _place(Vector2i(main.mine.shaft_column(), lower_top + 4))
	await hold([KEY_W], 90) # up to the lower piece's top
	await shot("below_the_gap")
	for i in range(2):
		await tap(KEY_R)
		await hold([KEY_W], 80)
		await frames(95) # rope cooldown
	key_event(KEY_W, true)
	await frames(60)
	key_event(KEY_W, false)
	check(_cell().y <= upper_bottom, "two ropes crossed the %d-row gap (now row %d, piece ends row %d)" % [lower_top - upper_bottom - 1, _cell().y, upper_bottom])
	await shot("above_the_gap")

## Digs down through the collapse at the shaft's end.
func _shaft_end_from_stone() -> void:
	await _in_shaft()
	var open: Vector2i = main.mine.shaft_open_rows()
	var col: int = main.mine.shaft_column()
	await _place(Vector2i(col, open.y))
	check(main.mine.is_solid(Vector2i(col, open.y + 1)), "the collapse is rock under the open shaft")
	await shot("above_the_collapse")
	await hold([KEY_S], 240)
	check(_cell().y > main.mine.shaft_end_row, "dug through the collapse (row %d, collapse ends row %d)" % [_cell().y, main.mine.shaft_end_row])
	check(not main.mine.is_solid(Vector2i(col, main.mine.shaft_end_row)), "the debris in the dug column is gone")
	await shot("through")

## Seed 2002 keeps the ladder piece nearest the collapse: holding S there
## must dig, not climb.
func _shaft_end_with_ladder() -> void:
	await _in_shaft(2002)
	var open: Vector2i = main.mine.shaft_open_rows()
	var col: int = main.mine.shaft_column()
	check(main.mine.old_ladder_rows.has(open.x + MineGrid.OLD_LADDER_PIECE_ROWS * ((open.y - open.x) / MineGrid.OLD_LADDER_PIECE_ROWS)), "seed 2002 has a ladder piece next to the collapse")
	await _place(Vector2i(col, open.y))
	await hold([KEY_S], 240)
	check(_cell().y > main.mine.shaft_end_row, "dug through the collapse past the ladder (row %d, collapse ends row %d)" % [_cell().y, main.mine.shaft_end_row])
	await shot("through")

# --- the old galleries (milestone 51b) ---------------------------------------

func _drift_of(layer: int) -> Dictionary:
	for d in main.mine.drifts:
		if d.layer == layer:
			return d
	return {}

## The walk key that goes along a drift away from the shaft.
func _walk_key(drift: Dictionary) -> int:
	return KEY_D if drift.side > 0 else KEY_A

## Walks along a drift until the player's cell reaches target_x (or the
## frames run out), then stops: walking on would pass its end into a cave.
func _walk_to(drift: Dictionary, target_x: int, max_frames: int) -> void:
	key_event(_walk_key(drift), true)
	for i in range(max_frames):
		await physics_frame
		if (_cell().x - target_x) * drift.side >= 0:
			break
	key_event(_walk_key(drift), false)
	await frames(10)

## Frames to walk a drift's length at 120 px/s, with a third to spare.
func _walk_frames(drift: Dictionary) -> int:
	return int((absi(drift.x1 - drift.x0) + 1) * 16.0 / 120.0 * 60.0 * 1.35)

## Walks the Topsoil gallery to its camp and searches it.
func _drift_to_camp() -> void:
	await _in_shaft()
	var d := _drift_of(0)
	check(not d.is_empty(), "seed %d has a Topsoil gallery" % SEED)
	if d.is_empty():
		return
	await _place(Vector2i(d.x0, d.row))
	await shot("mouth")
	await _walk_to(d, d.x1, _walk_frames(d))
	check(absi(_cell().x - d.x1) <= 1, "walked the gallery to its far end (x %d, end %d)" % [_cell().x, d.x1])
	await tap(KEY_E)
	var camps := main.get_tree().get_nodes_in_group("mine_events").filter(func(e): return e is Camp and main.mine.world_to_cell(e.global_position) == Vector2i(d.x1, d.row))
	check(camps.size() == 1 and camps[0].searched, "the camp at the end was searched")
	await shot("camp")

## Digs through the Clay gallery's collapsed section.
func _drift_collapse() -> void:
	await _in_shaft()
	var d := _drift_of(1)
	check(not d.is_empty(), "seed %d has a Clay gallery" % SEED)
	if d.is_empty():
		return
	var box: Rect2i = d.features.collapse
	var mouth_edge: int = box.position.x if d.side > 0 else box.end.x - 1
	await _place(Vector2i(mouth_edge - d.side * 3, d.row))
	await shot("before")
	await hold([KEY_SPACE, _walk_key(d)], 360)
	var far_edge: int = box.end.x - 1 if d.side > 0 else box.position.x
	var past: bool = _cell().x > far_edge if d.side > 0 else _cell().x < far_edge
	check(past, "dug through the collapsed section (x %d, section %d..%d)" % [_cell().x, box.position.x, box.end.x - 1])
	var open_cells := 0
	for cell in main.mine.drift_cells(d):
		if box.has_point(cell) and not main.mine.is_solid(cell):
			open_cells += 1
	check(open_cells >= box.size.y, "the dug column is open (%d cells)" % open_cells)
	await shot("after")

## Walks a gallery that crosses caves on plank floors without falling.
func _drift_planks() -> void:
	await _in_shaft(PLANK_SEED)
	var d := _drift_of(0)
	var planks := 0
	for i in range(absi(d.x1 - d.x0) + 1):
		if main.mine.get_cell_atlas_coords(0, Vector2i(d.x0 + d.side * i, d.row + 1)) == MineGrid.PLANK_ATLAS_COORDS:
			planks += 1
	check(planks > 0, "seed %d's Topsoil gallery has plank floors" % PLANK_SEED)
	await _place(Vector2i(d.x0, d.row))
	var lowest := _cell().y
	key_event(_walk_key(d), true)
	for i in range(_walk_frames(d)):
		await physics_frame
		lowest = maxi(lowest, _cell().y)
	key_event(_walk_key(d), false)
	check(lowest <= d.row, "never fell below the gallery floor (lowest row %d, floor row %d)" % [lowest, d.row + 1])
	check(absi(_cell().x - d.x1) <= 2, "reached the far end (x %d, end %d)" % [_cell().x, d.x1])
	await shot("end")

## Steps off the old ladder, sideways, into a gallery's mouth.
func _drift_from_the_ladder() -> void:
	await _in_shaft(LANDING_SEED)
	var d := _drift_of(0)
	await _place(Vector2i(main.mine.shaft_column(), d.row))
	check(main.player.is_on_rope(), "seed %d: the player starts on the old ladder at the gallery's row" % LANDING_SEED)
	await shot("on_the_ladder")
	var lowest := _cell().y
	key_event(_walk_key(d), true)
	for i in range(240):
		await physics_frame
		lowest = maxi(lowest, _cell().y)
		if (_cell().x - (d.x0 + d.side * 4)) * d.side >= 0:
			break
	key_event(_walk_key(d), false)
	check((_cell().x - (d.x0 + d.side * 4)) * d.side >= 0, "walked 4 tiles into the gallery (x %d, mouth %d)" % [_cell().x, d.x0])
	check(lowest <= d.row, "stepped onto the landing without dropping down the shaft (lowest row %d, floor row %d)" % [lowest, d.row + 1])
	await shot("in_the_mouth")

# --- the works' contents (milestone 51c) -------------------------------------

## Repairs the old cage at the bottom of Clay and rides it to the surface.
func _shaft_lift_ride() -> void:
	await _in_shaft()
	var lifts := main.get_tree().get_nodes_in_group("mine_events").filter(func(e): return e is Lift)
	check(lifts.size() == 1, "one lift")
	if lifts.size() != 1:
		return
	var lift: Lift = lifts[0]
	main.player.currency = 100
	await _place(main.mine.world_to_cell(lift.global_position))
	await shot("at_the_cage")
	await tap(KEY_E)
	check(lift.state == Lift.State.READY and main.player.currency == 100 - Lift.REPAIR_ORE, "E repaired the lift for %d ore" % Lift.REPAIR_ORE)
	await tap(KEY_E)
	check(lift.state == Lift.State.USED, "E rode it")
	check(_cell().y < MineGrid.SURFACE_ROWS, "the ride ended at the surface (row %d)" % _cell().y)
	await shot("at_the_surface")

## Steps off the old ladder, sideways, into the lift's cage and repairs it.
func _shaft_lift_from_the_ladder() -> void:
	await _in_shaft()
	var lifts := main.get_tree().get_nodes_in_group("mine_events").filter(func(e): return e is Lift)
	check(lifts.size() == 1, "one lift")
	if lifts.size() != 1:
		return
	var lift: Lift = lifts[0]
	var lift_cell: Vector2i = main.mine.world_to_cell(lift.global_position)
	var col: int = main.mine.shaft_column()
	main.player.currency = 100
	await _place(Vector2i(col, lift_cell.y))
	check(main.player.is_on_rope(), "seed %d: the player starts on the old ladder at the lift's row" % SEED)
	await shot("on_the_ladder")
	var side: int = signi(lift_cell.x - col)
	key_event(KEY_D if side > 0 else KEY_A, true)
	for i in range(120):
		await physics_frame
		if absf(main.player.global_position.x - lift.global_position.x) < 4.0:
			break
	key_event(KEY_D if side > 0 else KEY_A, false)
	await frames(10)
	check(absf(main.player.global_position.x - lift.global_position.x) < 12.0 and _cell().y <= lift_cell.y, "stepped into the cage (x %d, lift %d, row %d)" % [int(main.player.global_position.x), int(lift.global_position.x), _cell().y])
	check(main._action_prompts().any(func(p): return str(p).contains("repair the lift")), "the lift's repair prompt shows (%s)" % [main._action_prompts()])
	await tap(KEY_E)
	check(lift.state == Lift.State.READY, "E repaired it")
	await shot("repaired")

## One step of a stair climbed beside the collapse: dig two cells overhead,
## jump, dig the notch ahead at the apex, walk into it. (Straight dig-up
## reaches only about two rows - a jump rises 1.8 tiles and nothing digs on a
## rope - so the 6-row collapse is climbed on a stair, as the journal's last
## page says.)
func _stair_step(dir: int) -> void:
	var walk := KEY_D if dir > 0 else KEY_A
	await hold([KEY_SPACE, KEY_W], 40)
	await frames(30)
	await hold([KEY_SPACE, KEY_W], 40)
	await frames(30)
	key_event(KEY_W, true)
	await frames(16)
	key_event(KEY_W, false)
	key_event(KEY_SPACE, true)
	key_event(walk, true)
	await frames(8)
	key_event(KEY_SPACE, false)
	await frames(40)
	key_event(walk, false)
	await frames(10)

## Climbs back up past the collapse on a dug stair, from 12 tiles out in
## solid rock to the open shaft above it: the way home the journal points at.
func _shaft_from_below() -> void:
	await _in_shaft()
	var col: int = main.mine.shaft_column()
	var end_row: int = main.mine.shaft_end_row
	var open: Vector2i = main.mine.shaft_open_rows()
	# Solid rock beside the collapse (no caves), the open shaft above kept open.
	_fill(col + 2, open.y - 8, col + 16, end_row + 4, true)
	_fill(col - 1, open.y + 1, col + 1, end_row + 4, true)
	_fill(col + 12, end_row + 1, col + 12, end_row + 2, false)
	await _place(Vector2i(col + 12, end_row + 2))
	await shot("below_the_collapse")
	var steps := 0
	for i in range(16):
		await _stair_step(-1)
		steps += 1
		if _cell().y <= open.y and _cell().x <= col + 3:
			break
	key_event(KEY_SPACE, true)
	key_event(KEY_A, true)
	await frames(90)
	key_event(KEY_SPACE, false)
	key_event(KEY_A, false)
	await frames(30)
	check(_cell().y <= open.y and main.mine.is_in_shaft(_cell()), "climbed the collapse on a dug stair into the open shaft (cell %s, open rows end at %d, %d steps)" % [_cell(), open.y, steps])
	await shot("in_the_shaft")

## Every drawn thing, set out in a row near the player: each ArtSprite's
## viewport must hold painted pixels, be exactly its cell in size, and the
## frame must show them (a screenshot is saved to look at).
func _drawn_art_on_screen() -> void:
	await _start_game()
	var scenes := ["Stalker", "Burrower", "Snuffer", "FuelPickup", "OrePickup", "Lamp", "Support", "Ladder",
		"Rope", "Anchor", "Camp", "Outpost", "Lift", "Nest", "Heart", "Relic", "VaultDoor", "StrandedSign", "GasCloud", "LostMiner"]
	var origin: Vector2 = main.player.global_position + Vector2(-100, -44)
	var placed: Array[Node] = []
	for i in range(scenes.size()):
		var node: Node = load("res://scenes/%s.tscn" % scenes[i]).instantiate()
		if "player" in node:
			node.player = main.player
		if "target" in node:
			node.target = main.run_base
		if "main" in node:
			node.main = main
		main.mine.add_child(node)
		node.global_position = origin + Vector2((i % 10) * 22, (i / 10) * 50)
		if node.has_method("set_physics_process"):
			node.set_physics_process(false) # hold creatures still
		placed.append(node)
	var far := ArtSprite.new() # spawned far off screen: it must stay asleep
	far.kind = "fuel"
	main.mine.add_child(far)
	far.global_position = main.player.global_position + Vector2(5000, 5000)
	await frames(40)
	check(far.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED and not far.art.is_processing(), "art spawned off screen stays asleep")
	far.queue_free()
	var arts := 0
	for node in placed:
		for art in node.find_children("*", "ArtSprite", true, false):
			if not art.is_visible_in_tree() or art.art == null:
				continue
			arts += 1
			var image: Image = art.viewport.get_texture().get_image()
			check(image.get_size() == Vector2i(art.cell), "%s viewport is its cell size" % art.kind)
			var painted := 0
			for x in range(image.get_width()):
				for y in range(image.get_height()):
					if image.get_pixel(x, y).a > 0.05:
						painted += 1
			check(painted > 10, "%s paints pixels (%d)" % [art.kind, painted])
	check(arts >= scenes.size(), "all %d drawn things found, got %d" % [scenes.size(), arts])
	await shot("everything")
	_end_game()

## A full crew (one of each type) at the base for about 75 s of game time
## (time scaled 6x): the jobs change the base, the ore and the tool stocks,
## the miners stand at their stations digging while they work, and work done
## below the quiet layers is heard by the noise meter.
func _crew_jobs_at_work() -> void:
	var saved := Progress.new()
	saved.save_path = SAVE_PATH
	saved.roster = [
		{"name": "Ana", "type": "repair", "runs": 0}, {"name": "Bo", "type": "light", "runs": 0},
		{"name": "Cy", "type": "noise", "runs": 0}, {"name": "Di", "type": "traversal", "runs": 5},
	]
	saved.crew_names = ["Ana", "Bo", "Cy", "Di"]
	saved.levels = {"lamps": 1, "ladders": 1, "anchors": 1, "crew_bunk": 3}
	saved.save()
	await _start_game()
	var base: RunBase = main.run_base
	base.health = 1
	base.light.fuel = base.light.max_fuel * 0.5
	var fuel_before: float = base.light.fuel
	main.player.currency = 200
	var tools_before: int = main.player.ladders_left + main.player.anchors_left + main.lamps_left
	check(main.stations.size() == 4, "a station for each of the four jobs")
	Engine.time_scale = 6.0
	await frames(100) # about 10 s: the Mender has not finished its first point yet
	var ana: LostMiner = main.crew_at_base.filter(func(m): return m.miner_name == "Ana")[0]
	check(ana.art.art.state == "dig", "the Mender digs while the base needs mending")
	await shot("crew at work")
	await frames(650) # about 65 s more
	Engine.time_scale = 1.0
	check(base.health >= 2, "the Mender mended the base (health %d)" % base.health)
	check(base.light.fuel > fuel_before, "the Lamplighter's fuel outran the burn (%.0f > %.0f)" % [base.light.fuel, fuel_before])
	var tools_after: int = main.player.ladders_left + main.player.anchors_left + main.lamps_left
	check(tools_after > tools_before, "the Climber made something (%d > %d)" % [tools_after, tools_before])
	check(main.player.currency < 200, "the jobs spent ore (%d left)" % main.player.currency)
	# Below the quiet layers the same work is heard.
	base.global_position = main.mine.cell_to_world(Vector2i(40, MineGrid.GRID_HEIGHT - 2))
	main._place_crew_at_base()
	base.health = 1
	main.player.currency = 200
	main.noise_meter.decay_rate = 0.0
	main.noise_meter.noise = 0.0
	Engine.time_scale = 6.0
	await frames(160)
	Engine.time_scale = 1.0
	check(main.noise_meter.noise > 0.0, "work below the quiet layers makes noise the base hears (%.1f)" % main.noise_meter.noise)

## A base planted deep, a wave of two Burrowers (the third wave) surfacing below
## it: a full base light slows and kills them before they reach the walls, a
## nearly empty one does not and the base is hit.
func _wave_meets_the_base_light() -> void:
	await _start_game()
	var base: RunBase = main.run_base
	base.light.burn_rate = 0.0
	# Below the quiet floor, where a wave surfaces 10 tiles under the base.
	base.global_position = main.mine.cell_to_world(Vector2i(40, main.mine.quiet_floor_row() + 8))
	base.light.fuel = base.light.max_fuel
	main.mine_clock.wave_number = 3 # a wave of two
	main._spawn_wave()
	check(main.get_tree().get_nodes_in_group("burrowers").size() == 2, "two Burrowers surfaced")
	Engine.time_scale = 6.0
	await frames(250) # about 25 s
	Engine.time_scale = 1.0
	check(main.get_tree().get_nodes_in_group("burrowers").is_empty(), "a full base light killed them both")
	check(base.health == RunBase.MAX_HEALTH, "and the base kept every point of health (%d)" % base.health)
	await shot("full light")
	base.light.fuel = base.light.max_fuel * 0.02
	main._spawn_wave()
	Engine.time_scale = 6.0
	await frames(120) # about 12 s
	Engine.time_scale = 1.0
	check(base.health < RunBase.MAX_HEALTH, "a nearly empty light let them through (%d)" % base.health)
	await shot("thin light")

## U at the base buys the Outpost and then the Fort with the real key: the HUD
## line, max health, light capacity, props and ore all follow the table, a
## third press changes nothing, and replanting keeps the tier.
func _base_grows_in_tiers() -> void:
	await _start_game()
	var base: RunBase = main.run_base
	main.player.currency = 250
	main.player.global_position = base.global_position + Vector2(0, 15) # a run starts 40 px off: stand at the base
	main.player.velocity = Vector2.ZERO
	await frames(5)
	check(main.hud.base_label.text.begins_with("Base: Camp 3/3"), "starts as a Camp (%s)" % main.hud.base_label.text)
	await tap(KEY_U)
	await frames(2)
	check(base.tier == 1 and base.max_health() == 4 and base.health == 4, "an Outpost at 4/4 (tier %d health %d)" % [base.tier, base.health])
	check(base.light.max_fuel == 260.0 and base.light.fuel > 255.0, "its light holds 260 and was filled (%.1f)" % base.light.fuel)
	check(main.player.currency == 180, "70 ore paid (%d left)" % main.player.currency)
	check(main.hud.base_label.text.begins_with("Base: Outpost 4/4"), "the HUD says so (%s)" % main.hud.base_label.text)
	check(base.get_node("Palisade").visible and base.get_node("Beacon").visible and not base.get_node("Rampart").visible, "palisade and beacon, no rampart")
	await shot("outpost")
	await tap(KEY_U)
	await frames(2)
	check(base.tier == 2 and base.health == 5 and base.light.max_fuel == 340.0, "a Fort at 5/5 with a 340 light")
	check(main.player.currency == 60, "120 more ore paid (%d left)" % main.player.currency)
	check(main.hud.base_label.text.begins_with("Base: Fort 5/5"), "the HUD says so (%s)" % main.hud.base_label.text)
	check(base.get_node("Rampart").visible and not base.get_node("Palisade").visible and base.get_node("Bell").visible, "rampart and bell, the palisade is gone")
	await shot("fort")
	main.player.currency = 500
	await tap(KEY_U)
	check(base.tier == 2 and main.player.currency == 500, "a third press changes nothing")
	var rampart_offset: Vector2 = base.get_node("Rampart").global_position - base.global_position
	base.global_position += Vector2(200, 0)
	main._place_crew_at_base()
	check(base.tier == 2 and base.get_node("Rampart").global_position - base.global_position == rampart_offset, "replanting keeps the tier and the props follow")

## The hub (milestone 57): walk the settlement with real keys, buy a lantern
## level, put a miner on the crew, read the board, and go down the mine.
func _hub_buy_crew_and_descend() -> void:
	var saved := Progress.new()
	saved.save_path = SAVE_PATH
	saved.banked_ore = 100
	saved.roster = [{"name": "Ana", "type": "repair", "runs": 0, "found_in": 0}, {"name": "Bo", "type": "light", "runs": 0, "found_in": 0}]
	saved.crew_names = []
	saved.save()
	HUD.title_seen = true
	paused = false
	main = load("res://scenes/Hub.tscn").instantiate() # _end_game frees it like a run
	root.add_child(main)
	await frames(10)
	check(main.get_node_or_null("Mine") == null and main.get_node_or_null("RunBase") == null, "no mine and no run base in the hub")
	check(main.miners.size() == 2, "a figure for each rostered miner")
	await _hub_walk_to(Hub.BUILDING_X["lamp_shop"])
	check(main.hud.prompt_label.text.contains("Lantern tank"), "the lamp shop offers the lantern")
	await shot("lamp shop")
	await tap(KEY_1)
	check(main.progress.level("lantern") == 1 and main.progress.banked_ore == 70, "1 bought a lantern level for 30 ore")
	check(main.hud.banked_label.text == "Banked: 70", "the banked ore updated")
	await _hub_walk_to(main.miners[0].global_position.x)
	check(main.hud.prompt_label.text.contains("Ana"), "the prompt names the miner")
	await tap(KEY_E)
	check(main.progress.crew_names.has("Ana"), "E put Ana on the crew")
	await shot("crew")
	await _hub_walk_to(Hub.BUILDING_X["notice_board"])
	await tap(KEY_E)
	check(main.board_label.visible and main.board_label.text.contains("RECENT RUNS"), "the notice board opens")
	await shot("board")
	await tap(KEY_E)
	check(not main.board_label.visible, "and closes")
	var seen: Array = []
	main.change_scene = func(path: String): seen.append(path)
	await _hub_walk_to(Hub.ENTRANCE_X)
	await shot("entrance")
	await tap(KEY_E)
	check(seen == ["res://scenes/Main.tscn"], "the entrance starts a run")

## Walks the hub's player to x with real keys, then settles it exactly there.
func _hub_walk_to(x: float) -> void:
	for i in range(900):
		var dx: float = x - main.player.global_position.x
		if absf(dx) < 3.0:
			break
		var code := KEY_D if dx > 0.0 else KEY_A
		key_event(code, true)
		await frames(1)
		key_event(code, false)
	await frames(12)
	main.player.global_position.x = x
	main.player.velocity = Vector2.ZERO
	await frames(3)

## Touch controls (milestone 58): play with fingers only. Dig down with the
## pad, open the Tools menu and tap Rope, plant the base from the menu, pause
## with Esc and close it again.
func _touch_controls_play() -> void:
	TouchControls.force = true
	await _start_game()
	var tc: TouchControls = main.touch_controls
	tc.layout_size = Vector2(1152, 648)
	var layout := TouchControls.layout_for(tc.layout_size)
	var pad: Rect2 = layout["pad"]
	await shot("controls")
	# Walk left, away from the old ladder shaft (a rope or ladder is not a floor), then dig down.
	tc.touch(0, pad.get_center() + Vector2(-pad.size.x * 0.4, 0), true)
	await frames(60)
	tc.touch(0, pad.get_center(), false)
	var start_y: float = main.player.global_position.y
	tc.touch(0, pad.get_center() + Vector2(0, pad.size.x * 0.4), true)
	await frames(90)
	tc.touch(0, pad.get_center(), false)
	check(main.player.global_position.y > start_y + 2.0 * MineGrid.TILE_SIZE, "the pad's down dug down")
	await shot("dug_down")
	await frames(40) # settle on the floor of the shaft
	tc.touch(1, layout["tools"].get_center(), true)
	tc.touch(1, layout["tools"].get_center(), false)
	await frames(3)
	check(tc.visible_widgets().has("base_plant") and not tc.visible_widgets().has("base_repair"), "deep in the mine the menu lists Plant, not the base's own items")
	await shot("plant_menu")
	tc.touch(1, tc._rect("base_plant").get_center(), true)
	tc.touch(1, tc._rect("base_plant").get_center(), false)
	await frames(10)
	check(main.base_planted and main.run_base.global_position.distance_to(main.player.global_position) < 60.0, "Plant moved the base to the player")
	tc.touch(1, layout["tools"].get_center(), true)
	tc.touch(1, layout["tools"].get_center(), false)
	await frames(3)
	check(tc.visible_widgets().has("tool_rope"), "the Tools menu lists Rope")
	await shot("tools_menu")
	tc.touch(1, tc._rect("tool_rope").get_center(), true)
	tc.touch(1, tc._rect("tool_rope").get_center(), false)
	await frames(10)
	check(not tc.visible_widgets().has("tool_rope"), "picking Rope closed the menu")
	check(main.mine.find_children("*", "Rope", true, false).size() > 0, "Rope was placed")
	main.player.global_position = main.run_base.global_position + Vector2(0, 15)
	await frames(10)
	tc.touch(2, layout["tools"].get_center(), true)
	tc.touch(2, layout["tools"].get_center(), false)
	await frames(3)
	check(tc.visible_widgets().has("base_repair"), "at the base the menu lists Repair")
	await shot("base_menu")
	tc.touch(2, layout["tools"].get_center(), true) # close it again
	tc.touch(2, layout["tools"].get_center(), false)
	tc.touch(3, layout["esc"].get_center(), true)
	tc.touch(3, layout["esc"].get_center(), false)
	await frames(10)
	check(paused and main.hud.overlay.visible, "Esc paused the game and showed the controls")
	check(tc.visible_widgets().has("continue") and tc.visible_widgets().size() == 2, "paused: only Continue and Esc")
	await shot("paused")
	tc.touch(3, layout["esc"].get_center(), true)
	tc.touch(3, layout["esc"].get_center(), false)
	await frames(10)
	check(not paused, "Esc again closed the overlay")
	TouchKeys.release_all()
	TouchControls.force = false

## The hub with touch: buy a lantern level at the lamp shop with the on-screen
## 1 button, then use the entrance.
func _touch_hub_buy() -> void:
	var saved := Progress.new()
	saved.save_path = SAVE_PATH
	saved.banked_ore = 100
	saved.save()
	TouchControls.force = true
	HUD.title_seen = true
	paused = false
	main = load("res://scenes/Hub.tscn").instantiate()
	root.add_child(main)
	await frames(10)
	var tc: TouchControls = main.touch_controls
	tc.layout_size = Vector2(1152, 648)
	var layout := TouchControls.layout_for(tc.layout_size)
	main.player.global_position = Vector2(Hub.BUILDING_X["lamp_shop"], Hub.PLAYER_Y)
	await frames(10)
	await shot("hub")
	tc.touch(0, layout["buy1"].get_center(), true)
	tc.touch(0, layout["buy1"].get_center(), false)
	await frames(10)
	check(main.progress.level("lantern") == 1 and main.progress.banked_ore == 70, "the on-screen 1 bought a lantern level")
	var seen: Array = []
	main.change_scene = func(path: String): seen.append(path)
	main.player.global_position = Vector2(Hub.ENTRANCE_X, Hub.PLAYER_Y)
	await frames(5)
	tc.touch(0, layout["use"].get_center(), true)
	tc.touch(0, layout["use"].get_center(), false)
	await frames(10)
	check(seen == ["res://scenes/Main.tscn"], "Use at the entrance starts a run")
	TouchKeys.release_all()
	TouchControls.force = false
