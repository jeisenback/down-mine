extends TestCase

## Touch controls (milestone 58): the pad's rule, synthetic key state, and the
## on-screen widgets that press the same keys the keyboard does.

func test_pad_directions() -> void:
	var r := 60.0
	assert_eq(TouchPad.keys_for(Vector2(0.8 * r, 0), r), [KEY_D], "right")
	assert_eq(TouchPad.keys_for(Vector2(-0.8 * r, 0), r), [KEY_A], "left")
	assert_eq(TouchPad.keys_for(Vector2(0, -0.8 * r), r), [KEY_W], "up")
	assert_eq(TouchPad.keys_for(Vector2(0, 0.8 * r), r), [KEY_S], "down")

func test_pad_diagonals_return_two_keys() -> void:
	var keys := TouchPad.keys_for(Vector2(50, 50), 60.0)
	assert_eq(keys.size(), 2, "two keys")
	assert_true(keys.has(KEY_D) and keys.has(KEY_S), "down and right: the stair dig")

func test_pad_dead_zone_returns_nothing() -> void:
	var r := 60.0
	for offset in [Vector2(0.2 * r, 0), Vector2(0, 0.2 * r), Vector2(-0.2 * r, -0.2 * r), Vector2.ZERO]:
		assert_eq(TouchPad.keys_for(offset, r), [], "inside the dead zone: %s" % offset)

func test_set_key_only_changes_state() -> void:
	TouchKeys.release_all()
	var before := TouchKeys.sent_count
	TouchKeys.set_key(KEY_SPACE, true)
	TouchKeys.set_key(KEY_SPACE, true)
	assert_eq(TouchKeys.sent_count, before + 1, "the second press changed nothing")
	assert_true(TouchKeys.is_down(KEY_SPACE), "held")
	TouchKeys.release_all()
	assert_eq(TouchKeys.sent_count, before + 2, "release_all sent one release")
	assert_true(not TouchKeys.is_down(KEY_SPACE), "let go")

# --- TouchControls: widgets, multi-touch, key output ---------------------------

const ControlsScene := preload("res://scenes/TouchControls.tscn")
const SIZE := Vector2(1152, 648)

func _controls() -> TouchControls:
	TouchControls.force = true
	TouchKeys.release_all()
	var c: TouchControls = add(ControlsScene.instantiate())
	c.layout_size = SIZE
	return c

func _done() -> void:
	TouchKeys.release_all()
	TouchControls.force = false
	TouchControls.seen_touch = false

func _at(widget: String) -> Vector2:
	return TouchControls.layout_for(SIZE)[widget].get_center()

func test_dig_touch_holds_space_until_lifted() -> void:
	var c := _controls()
	c.touch(0, _at("dig"), true)
	assert_true(TouchKeys.is_down(KEY_SPACE), "Dig holds Space")
	c.touch(0, _at("dig"), false)
	assert_true(not TouchKeys.is_down(KEY_SPACE), "lifted: Space released at once")
	_done()

func test_two_fingers_hold_two_widgets() -> void:
	var c := _controls()
	var pad: Rect2 = TouchControls.layout_for(SIZE)["pad"]
	c.touch(0, pad.get_center() + Vector2(pad.size.x * 0.4, 0), true)
	c.touch(1, _at("dig"), true)
	assert_true(TouchKeys.is_down(KEY_D) and TouchKeys.is_down(KEY_SPACE), "both held")
	c.touch(1, _at("dig"), false)
	assert_true(TouchKeys.is_down(KEY_D), "the pad is still held")
	assert_true(not TouchKeys.is_down(KEY_SPACE), "Dig let go")
	_done()

func test_tap_widget_holds_for_hold_frames() -> void:
	var c := _controls()
	c.touch(0, _at("use"), true)
	c.touch(0, _at("use"), false)
	assert_true(TouchKeys.is_down(KEY_E), "E is down right after the tap")
	await physics_frames(TouchControls.TAP_HOLD_FRAMES - 2)
	assert_true(TouchKeys.is_down(KEY_E), "still down inside the hold")
	await physics_frames(3)
	assert_true(not TouchKeys.is_down(KEY_E), "released after the hold")
	_done()

func test_pad_drag_changes_direction() -> void:
	var c := _controls()
	var pad: Rect2 = TouchControls.layout_for(SIZE)["pad"]
	c.touch(0, pad.get_center() + Vector2(pad.size.x * 0.4, 0), true)
	assert_true(TouchKeys.is_down(KEY_D), "right")
	c.drag(0, pad.get_center() + Vector2(0, pad.size.y * 0.4))
	assert_true(not TouchKeys.is_down(KEY_D) and TouchKeys.is_down(KEY_S), "dragged down")
	c.touch(0, pad.get_center(), false)
	assert_true(not TouchKeys.is_down(KEY_S), "lifted")
	_done()

func test_slide_from_pad_onto_dig_does_not_press_dig() -> void:
	var c := _controls()
	var pad: Rect2 = TouchControls.layout_for(SIZE)["pad"]
	c.touch(0, pad.get_center() + Vector2(pad.size.x * 0.4, 0), true)
	c.drag(0, _at("dig"))
	assert_true(not TouchKeys.is_down(KEY_SPACE), "Dig was not pressed by a slide")
	_done()

func test_second_finger_on_a_held_button_is_ignored() -> void:
	var c := _controls()
	c.touch(0, _at("dig"), true)
	c.touch(1, _at("dig"), true)
	c.touch(1, _at("dig"), false)
	assert_true(TouchKeys.is_down(KEY_SPACE), "the first finger still holds Dig")
	_done()

func test_release_all_lets_go_of_everything() -> void:
	var c := _controls()
	c.touch(0, _at("dig"), true)
	c.touch(1, _at("flare"), true)
	c.release_all()
	assert_true(not TouchKeys.is_down(KEY_SPACE) and not TouchKeys.is_down(KEY_SHIFT), "nothing held")
	c.touch(0, _at("dig"), false)
	assert_true(not TouchKeys.is_down(KEY_SPACE), "a late lift changes nothing")
	_done()

func test_layout_rects_are_big_inside_and_do_not_overlap() -> void:
	var groups := {
		"mine": ["pad", "dig", "flare", "use", "tools", "esc", "tool_rope", "tool_ladder", "tool_anchor", "tool_lamp", "tool_beam", "tool_grapple", "base_plant", "base_repair", "base_fortify", "base_grow"],
		"hub": ["pad", "use", "buy1", "buy2", "buy3", "esc"],
		"paused": ["continue", "esc"],
	}
	for size in [SIZE, Vector2(2400, 1080)]:
		var layout := TouchControls.layout_for(size)
		var minimum: float = 56.0 * size.y / 648.0
		for group in groups:
			var names: Array = groups[group]
			for i in range(names.size()):
				var rect: Rect2 = layout[names[i]]
				assert_true(rect.size.x >= minimum and rect.size.y >= minimum, "%s is big enough at %s" % [names[i], size])
				assert_true(Rect2(Vector2.ZERO, size).encloses(rect), "%s is on screen at %s" % [names[i], size])
				for j in range(i + 1, names.size()):
					assert_true(not rect.intersects(layout[names[j]]), "%s and %s overlap in %s at %s" % [names[i], names[j], group, size])

# --- TouchControls: modes, the pause rule, base cluster, detection -------------

func _fresh(mode: String = "mine") -> TouchControls:
	var c := _controls()
	c.layout_size = SIZE
	c.set_mode(mode)
	return c

func test_mine_mode_shows_its_widgets_and_hub_mode_its_own() -> void:
	var c := _fresh("mine")
	var mine := c.visible_widgets()
	for name in ["pad", "dig", "flare", "use", "tools", "esc"]:
		assert_true(mine.has(name), "mine shows %s" % name)
	for name in ["buy1", "continue", "tool_rope", "base_plant"]:
		assert_true(not mine.has(name), "mine hides %s" % name)
	c.set_mode("hub")
	var hub := c.visible_widgets()
	for name in ["pad", "use", "buy1", "buy2", "buy3", "esc"]:
		assert_true(hub.has(name), "hub shows %s" % name)
	for name in ["dig", "flare", "tools"]:
		assert_true(not hub.has(name), "hub hides %s" % name)
	_done()

func _open_menu(c: TouchControls) -> void:
	var tools: Rect2 = TouchControls.layout_for(SIZE)["tools"]
	c.touch(0, tools.get_center(), true)
	c.touch(0, tools.get_center(), false)

func test_tools_menu_opens_and_closes() -> void:
	var c := _fresh()
	_open_menu(c)
	for name in TouchControls.TOOL_ROW:
		assert_true(c.visible_widgets().has(name), "%s is in the open menu" % name)
	var layout := TouchControls.layout_for(SIZE)
	c.touch(0, layout["tool_rope"].get_center(), true)
	assert_true(TouchKeys.is_down(KEY_R), "the rope key is pressed")
	assert_true(not c.visible_widgets().has("tool_rope"), "the menu closed")
	c.touch(0, layout["tool_rope"].get_center(), false)
	_done()

func test_tools_menu_lists_only_available_tools() -> void:
	var c := _fresh()
	c.set_tools_available(["tool_rope", "tool_grapple", "tool_beam"])
	_open_menu(c)
	var shown := c.visible_widgets()
	for name in ["tool_rope", "tool_grapple", "tool_beam"]:
		assert_true(shown.has(name), "%s is available" % name)
	for name in ["tool_ladder", "tool_lamp", "tool_anchor"]:
		assert_true(not shown.has(name), "%s is not unlocked yet" % name)
	_done()

func test_base_items_are_in_the_menu_only_near_the_base() -> void:
	var c := _fresh()
	assert_true(not c.visible_widgets().has("base_plant"), "not shown with the menu closed")
	_open_menu(c)
	assert_true(not c.visible_widgets().has("base_plant"), "not in the menu away from the base")
	c.set_base_nearby(true)
	for name in ["base_plant", "base_repair", "base_fortify", "base_grow"]:
		assert_true(c.visible_widgets().has(name), "%s is in the menu at the base" % name)
	c.touch(0, TouchControls.layout_for(SIZE)["base_repair"].get_center(), true)
	assert_true(TouchKeys.is_down(KEY_F), "Repair is held")
	assert_true(not c.visible_widgets().has("base_repair"), "the menu closed, the key stays down")
	assert_true(TouchKeys.is_down(KEY_F), "still held until the finger lifts")
	c.set_base_nearby(false)
	assert_true(not TouchKeys.is_down(KEY_F), "leaving the base lets go of Repair")
	_done()

func test_paused_shows_only_continue_and_esc() -> void:
	var c := _fresh()
	tree.paused = true
	assert_eq(c.visible_widgets().size(), 2, "two widgets")
	assert_true(c.visible_widgets().has("continue") and c.visible_widgets().has("esc"), "Continue and Esc")
	tree.paused = false
	_done()

func test_pausing_releases_held_keys() -> void:
	var c := _fresh()
	c.touch(0, _at("dig"), true)
	assert_true(TouchKeys.is_down(KEY_SPACE), "held")
	tree.paused = true
	await tree.process_frame
	await tree.process_frame # the awaited signal can fire before the node's own _process
	assert_true(not TouchKeys.is_down(KEY_SPACE), "pausing let go")
	tree.paused = false
	_done()

func test_esc_tap_with_the_pad_held_leaves_no_key_stuck() -> void:
	var c := _fresh()
	var pad: Rect2 = TouchControls.layout_for(SIZE)["pad"]
	c.touch(0, pad.get_center() + Vector2(pad.size.x * 0.4, 0), true)
	c.touch(1, _at("esc"), true)
	c.touch(1, _at("esc"), false)
	tree.paused = true # what the controls overlay does
	await tree.process_frame
	await tree.process_frame
	assert_true(not TouchKeys.is_down(KEY_D), "the pad's key is not stuck")
	tree.paused = false
	_done()

func test_wanted_for_each_source() -> void:
	TouchControls.force = false
	TouchControls.seen_touch = false
	assert_true(not TouchControls.wanted(), "off by default on a desktop")
	TouchControls.force = true
	assert_true(TouchControls.wanted(), "forced on")
	TouchControls.force = false
	var c: TouchControls = add(ControlsScene.instantiate())
	var emulated := InputEventScreenTouch.new()
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	emulated.pressed = true
	c._input(emulated)
	assert_true(not TouchControls.wanted(), "a touch emulated from the mouse does not reveal the controls")
	var real := InputEventScreenTouch.new()
	real.device = 0
	real.pressed = true
	c._input(real)
	assert_true(TouchControls.wanted(), "a real first touch does")
	_done()

func test_portrait_hides_controls_and_shows_the_hint() -> void:
	assert_true(TouchControls.is_portrait(Vector2(648, 1152)), "taller than wide")
	assert_true(not TouchControls.is_portrait(SIZE), "wider than tall")
	var c := _fresh()
	c.layout_size = Vector2(648, 1152)
	await tree.process_frame
	assert_eq(c.visible_widgets(), [], "no widgets in portrait")
	assert_true(c.get_node("RotateHint").visible, "the rotate hint shows")
	_done()

func test_hidden_controls_ignore_touches() -> void:
	var c := _fresh()
	TouchControls.force = false
	c.touch(0, _at("dig"), true)
	assert_true(not TouchKeys.is_down(KEY_SPACE), "nothing pressed while hidden")
	_done()

# --- wired into the mine and the hub --------------------------------------------

func test_project_has_the_phone_display_settings() -> void:
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 1152, "base width")
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_height"), 648, "base height")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode"), "canvas_items", "stretch mode")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "expand", "aspect")
	assert_eq(ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"), true, "a mouse click acts as a touch for testing")

func _main() -> Main:
	Progress.path_override = TestCase.TEST_SAVE_PATH
	var fresh := Progress.new() # earlier tests leave unlocks in the shared test save
	fresh.save_path = TestCase.TEST_SAVE_PATH
	fresh.save()
	TouchControls.force = true
	var main: Main = add(load("res://scenes/Main.tscn").instantiate())
	await physics_frames(10)
	main.touch_controls.layout_size = SIZE
	return main

func test_main_and_hub_each_have_touch_controls_in_their_mode() -> void:
	var main := await _main()
	assert_eq(main.touch_controls.mode, "mine", "the mine's mode")
	Progress.path_override = TEST_SAVE_PATH
	var hub: Hub = add(load("res://scenes/Hub.tscn").instantiate())
	await physics_frames(3)
	assert_eq(hub.touch_controls.mode, "hub", "the hub's mode")
	_done()
	Progress.path_override = ""

func test_the_pad_down_digs_down_in_the_mine() -> void:
	var main := await _main()
	var start_y: float = main.player.global_position.y
	var pad: Rect2 = TouchControls.layout_for(SIZE)["pad"]
	main.touch_controls.touch(0, pad.get_center() + Vector2(0, pad.size.x * 0.4), true)
	await physics_frames(60)
	main.touch_controls.touch(0, pad.get_center(), false)
	assert_true(main.player.global_position.y > start_y + 2.0 * MineGrid.TILE_SIZE, "the pad's down dug down: %s to %s" % [start_y, main.player.global_position.y])
	_done()
	Progress.path_override = ""

func test_the_pad_down_and_side_digs_a_stair() -> void:
	var main := await _main()
	var start: Vector2 = main.player.global_position
	var pad: Rect2 = TouchControls.layout_for(SIZE)["pad"]
	main.touch_controls.touch(0, pad.get_center() + Vector2(pad.size.x * 0.4, pad.size.x * 0.4), true)
	await physics_frames(90)
	main.touch_controls.touch(0, pad.get_center(), false)
	assert_true(main.player.global_position.y > start.y + MineGrid.TILE_SIZE and main.player.global_position.x > start.x + MineGrid.TILE_SIZE, "down and right made a stair: %s to %s" % [start, main.player.global_position])
	_done()
	Progress.path_override = ""

func test_the_menu_lists_only_unlocked_tools_and_base_items_only_at_the_base() -> void:
	var main := await _main()
	var tools: Rect2 = TouchControls.layout_for(SIZE)["tools"]
	main.touch_controls.touch(0, tools.get_center(), true)
	main.touch_controls.touch(0, tools.get_center(), false)
	var shown: Array = main.touch_controls.visible_widgets()
	for name in ["tool_rope", "tool_grapple", "tool_beam"]:
		assert_true(shown.has(name), "%s is always there" % name)
	for name in ["tool_ladder", "tool_lamp", "tool_anchor"]:
		assert_true(not shown.has(name), "%s is not unlocked on a fresh save" % name)
	assert_true(not shown.has("base_plant"), "no base items away from the base")
	main.player.global_position = main.run_base.global_position
	await physics_frames(3)
	assert_true(main.touch_controls.visible_widgets().has("base_plant"), "base items at the base")
	_done()
	Progress.path_override = ""

func test_use_at_the_hub_entrance_changes_scene() -> void:
	Progress.path_override = TEST_SAVE_PATH
	TouchControls.force = true
	var hub: Hub = add(load("res://scenes/Hub.tscn").instantiate())
	await physics_frames(3)
	hub.touch_controls.layout_size = SIZE
	var seen: Array = []
	hub.change_scene = func(path: String): seen.append(path)
	hub.player.global_position = Vector2(Hub.ENTRANCE_X, Hub.PLAYER_Y)
	hub.touch_controls.touch(0, _at("use"), true)
	hub.touch_controls.touch(0, _at("use"), false)
	await physics_frames(8)
	assert_eq(seen, ["res://scenes/Main.tscn"], "Use at the entrance starts a run")
	_done()
	Progress.path_override = ""

func test_continue_on_the_summary_leaves_for_the_hub() -> void:
	var main := await _main()
	var seen: Array = []
	main.change_scene = func(path: String): seen.append(path)
	main.player.take_hit(Player.MAX_HEALTH, "fall")
	await physics_frames(3)
	assert_true(tree.paused, "the summary pauses the game")
	await tree.process_frame
	assert_eq(main.touch_controls.visible_widgets().size(), 2, "only Continue and Esc")
	main.touch_controls.touch(0, _at("continue"), true)
	main.touch_controls.touch(0, _at("continue"), false)
	await tree.process_frame
	await tree.process_frame
	await tree.process_frame
	assert_eq(seen, ["res://scenes/Hub.tscn"], "Continue goes to the hub")
	tree.paused = false
	_done()
	Progress.path_override = ""
