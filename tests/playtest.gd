extends SceneTree

## Playtest runner (milestone 44): plays scripted scenarios in the real
## game - fixed seed, real key events - checks the outcome and saves a
## screenshot per step to playtest_out/. Needs a display, so run it under
## a virtual one:
##   xvfb-run -a godot --fixed-fps 60 -s tests/playtest.gd
## CI runs it on every pull request and attaches the screenshots.
## Exits 1 if any scenario fails.

const SEED := 1001
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

func _start_game(show_title: bool = false) -> void:
	HUD.title_seen = not show_title
	MineGrid.next_seed = SEED
	paused = false
	main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	await frames(10)
	main.stalker.process_mode = Node.PROCESS_MODE_DISABLED # scenarios test mechanics, not survival

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
	teleport(main.mine.world_to_cell(camp.global_position) + Vector2i(-1, 0))
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
