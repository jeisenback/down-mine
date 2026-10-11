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
	return add(ControlsScene.instantiate())

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
