extends TestCase

## The gamepad (controller support): the pure layout rules and the scheme. The node that turns
## joypad events into keys is tested below the "GamepadControls" heading.

func test_stick_keys_follow_the_touch_pad_rule() -> void:
	assert_eq(GamepadMap.stick_keys(Vector2(0.9, 0)), [KEY_D], "right")
	assert_eq(GamepadMap.stick_keys(Vector2(-0.9, 0)), [KEY_A], "left")
	assert_eq(GamepadMap.stick_keys(Vector2(0, -0.9)), [KEY_W], "up")
	assert_eq(GamepadMap.stick_keys(Vector2(0.2, 0.2)), [], "inside the dead zone")
	var stair := GamepadMap.stick_keys(Vector2(0.7, 0.7))
	assert_true(stair.has(KEY_D) and stair.has(KEY_S) and stair.size() == 2, "a deliberate diagonal digs a stair")

func test_cycle_list_adds_base_actions_only_when_they_apply() -> void:
	var tools := ["tool_rope", "tool_grapple"]
	assert_eq(GamepadMap.cycle_list(tools, false, false), ["tool_rope", "tool_grapple"], "tools only")
	assert_eq(GamepadMap.cycle_list(tools, true, false), ["tool_rope", "tool_grapple", "base_plant"], "plant when allowed")
	assert_eq(GamepadMap.cycle_list(tools, false, true), ["tool_rope", "tool_grapple", "base_repair", "base_fortify", "base_grow"], "the base's actions beside it")
	assert_eq(GamepadMap.cycle_list(tools, true, true), ["tool_rope", "tool_grapple", "base_plant", "base_repair", "base_fortify", "base_grow"], "all of them")

func test_cycle_wraps_and_survives_edges() -> void:
	assert_eq(GamepadMap.cycle(["a", "b", "c"], "c", 1), "a", "forward wraps")
	assert_eq(GamepadMap.cycle(["a", "b", "c"], "a", -1), "c", "backward wraps")
	assert_eq(GamepadMap.cycle(["a", "b", "c"], "a", 1), "b", "forward")
	assert_eq(GamepadMap.cycle(["a", "b"], "zzz", 1), "a", "a tool that left the list gives the first")
	assert_eq(GamepadMap.cycle([], "a", 1), "", "an empty list gives nothing")

func test_tool_labels_and_keys() -> void:
	assert_eq(GamepadMap.tool_label("tool_rope"), "Rope", "tool")
	assert_eq(GamepadMap.tool_label("tool_grapple"), "Grapple", "another tool")
	assert_eq(GamepadMap.tool_label("base_repair"), "Repair", "a base action")
	assert_eq(GamepadMap.tool_label("base_plant"), "Plant", "planting")
	assert_eq(GamepadMap.tool_label(""), "", "nothing selected")
	assert_eq(GamepadMap.tool_keys("tool_rope"), [KEY_R], "rope is R")
	assert_eq(GamepadMap.tool_keys("tool_grapple"), [KEY_Q], "grapple is Q")
	assert_true(GamepadMap.tool_holds("base_repair"), "repair is held")
	assert_true(not GamepadMap.tool_holds("tool_rope"), "rope is a tap")

func test_the_scheme_follows_the_last_input() -> void:
	ControlScheme.pad_last = false
	TouchControls.force = false
	assert_eq(ControlScheme.current(), "keys", "keyboard by default")
	ControlScheme.note_joypad()
	assert_eq(ControlScheme.current(), "pad", "a joypad event")
	var press := InputEventKey.new()
	press.physical_keycode = KEY_Z
	press.pressed = true
	ControlScheme.note_key(press)
	assert_eq(ControlScheme.current(), "keys", "a real key press takes it back")
	ControlScheme.note_joypad()
	TouchKeys.set_key(KEY_Z, true, "pad")
	ControlScheme.note_key(press)
	assert_eq(ControlScheme.current(), "pad", "the pad's own injected key does not")
	TouchKeys.release_all()
	var lift := InputEventKey.new()
	lift.physical_keycode = KEY_Z
	lift.pressed = false
	ControlScheme.note_key(lift)
	assert_eq(ControlScheme.current(), "pad", "a release changes nothing")
	ControlScheme.pad_last = false
	TouchControls.force = true
	assert_eq(ControlScheme.current(), "touch", "touch when it is wanted and the pad was not used last")
	TouchControls.force = false

# --- GamepadControls -------------------------------------------------------------

func _pad() -> GamepadControls:
	var pad: GamepadControls = add(GamepadControls.new())
	pad.set_tools_available(["tool_rope", "tool_grapple", "tool_beam"])
	return pad

func _tap_frames(pad: GamepadControls) -> void:
	for i in range(GamepadControls.TAP_HOLD_FRAMES):
		pad._physics_process(0.0)

func _done(pad: GamepadControls) -> void:
	pad.release_all()
	tree.paused = false
	TouchKeys.release_all()

func test_the_stick_and_dpad_make_the_direction_keys() -> void:
	var pad := _pad()
	pad.axis(JOY_AXIS_LEFT_X, 0.9)
	assert_true(TouchKeys.is_down(KEY_D), "stick right")
	pad.axis(JOY_AXIS_LEFT_X, 0.0)
	assert_true(not TouchKeys.is_down(KEY_D), "released")
	pad.axis(JOY_AXIS_LEFT_Y, 0.9)
	pad.axis(JOY_AXIS_LEFT_X, 0.8)
	assert_true(TouchKeys.is_down(KEY_S) and TouchKeys.is_down(KEY_D), "down and a side: a stair")
	pad.axis(JOY_AXIS_LEFT_Y, 0.0)
	pad.button(JOY_BUTTON_DPAD_LEFT, true)
	assert_true(TouchKeys.is_down(KEY_A) and TouchKeys.is_down(KEY_D), "the stick and the d-pad add up")
	pad.button(JOY_BUTTON_DPAD_LEFT, false)
	assert_true(not TouchKeys.is_down(KEY_A) and TouchKeys.is_down(KEY_D), "letting go of the d-pad leaves the stick's key")
	_done(pad)

func test_a_is_jump_x_is_dig_rt_is_flare_in_the_mine() -> void:
	var pad := _pad()
	pad.button(JOY_BUTTON_A, true)
	assert_true(TouchKeys.is_down(KEY_W), "A jumps (held, so a jump can be a hop)")
	pad.button(JOY_BUTTON_A, false)
	assert_true(not TouchKeys.is_down(KEY_W), "and lets go")
	pad.button(JOY_BUTTON_X, true)
	assert_true(TouchKeys.is_down(KEY_SPACE), "X digs")
	pad.button(JOY_BUTTON_X, false)
	assert_true(not TouchKeys.is_down(KEY_SPACE), "and stops")
	pad.axis(JOY_AXIS_TRIGGER_RIGHT, 0.4)
	assert_true(not TouchKeys.is_down(KEY_SHIFT), "a light pull is not a flare")
	pad.axis(JOY_AXIS_TRIGGER_RIGHT, 0.6)
	assert_true(TouchKeys.is_down(KEY_SHIFT), "past the threshold it is")
	pad.axis(JOY_AXIS_TRIGGER_RIGHT, 0.0)
	assert_true(not TouchKeys.is_down(KEY_SHIFT), "released")
	_done(pad)

func test_b_uses_and_taps_hold_their_key_three_frames() -> void:
	var pad := _pad()
	pad.button(JOY_BUTTON_B, true)
	assert_true(TouchKeys.is_down(KEY_E), "B uses")
	pad.button(JOY_BUTTON_B, false)
	assert_true(TouchKeys.is_down(KEY_E), "a tap keeps its key for a few physics frames: the game polls at 60 Hz")
	_tap_frames(pad)
	assert_true(not TouchKeys.is_down(KEY_E), "then lets go")
	_done(pad)

func test_the_tool_cycle_and_y() -> void:
	var pad := _pad()
	assert_eq(pad.selected_tool(), "tool_rope", "the first tool is selected")
	pad.button(JOY_BUTTON_RIGHT_SHOULDER, true)
	pad.button(JOY_BUTTON_RIGHT_SHOULDER, false)
	assert_eq(pad.selected_tool(), "tool_grapple", "RB goes forward")
	pad.button(JOY_BUTTON_LEFT_SHOULDER, true)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, false)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, true)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, false)
	assert_eq(pad.selected_tool(), "tool_beam", "LB goes back and wraps")
	pad.button(JOY_BUTTON_LEFT_SHOULDER, true)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, false)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, true)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, false)
	assert_eq(pad.selected_tool(), "tool_rope", "back to Rope")
	pad.button(JOY_BUTTON_Y, true)
	assert_true(TouchKeys.is_down(KEY_R), "Y uses the selected tool: Rope is R")
	pad.button(JOY_BUTTON_Y, false)
	_tap_frames(pad)
	assert_true(not TouchKeys.is_down(KEY_R), "a tap")
	pad.button(JOY_BUTTON_RIGHT_SHOULDER, true)
	pad.button(JOY_BUTTON_RIGHT_SHOULDER, false)
	pad.button(JOY_BUTTON_Y, true)
	assert_true(TouchKeys.is_down(KEY_Q), "Grapple is Q")
	pad.button(JOY_BUTTON_Y, false)
	_tap_frames(pad)
	pad.set_base_nearby(true)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, true) # Grapple -> Rope
	pad.button(JOY_BUTTON_LEFT_SHOULDER, false)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, true) # Rope -> Grow (the last)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, false)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, true) # Grow -> Fortify
	pad.button(JOY_BUTTON_LEFT_SHOULDER, false)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, true) # Fortify -> Repair
	pad.button(JOY_BUTTON_LEFT_SHOULDER, false)
	assert_eq(pad.selected_tool(), "base_repair", "the base's actions join the cycle beside it")
	pad.button(JOY_BUTTON_Y, true)
	assert_true(TouchKeys.is_down(KEY_F), "Repair is F, held")
	_tap_frames(pad)
	assert_true(TouchKeys.is_down(KEY_F), "and it stays down while Y is held")
	pad.button(JOY_BUTTON_Y, false)
	assert_true(not TouchKeys.is_down(KEY_F), "lifted at once")
	_done(pad)

func test_the_selected_tool_falls_back_when_it_leaves_the_list() -> void:
	var pad := _pad()
	pad.set_base_nearby(true)
	pad.button(JOY_BUTTON_LEFT_SHOULDER, true) # Rope -> Grow
	pad.button(JOY_BUTTON_LEFT_SHOULDER, false)
	assert_eq(pad.selected_tool(), "base_grow", "the last base action")
	pad.set_base_nearby(false)
	assert_eq(pad.selected_tool(), "tool_rope", "the base is behind: back to the first tool")
	pad.set_tools_available([])
	assert_eq(pad.selected_tool(), "", "no tools at all")
	pad.button(JOY_BUTTON_Y, true)
	pad.button(JOY_BUTTON_RIGHT_SHOULDER, true)
	assert_true(not TouchKeys.is_down(KEY_R) and not TouchKeys.is_down(KEY_Q), "Y and the bumpers do nothing, and do not crash")
	_done(pad)

func test_hub_buttons() -> void:
	var pad := _pad()
	pad.set_mode("hub")
	pad.button(JOY_BUTTON_X, true)
	assert_true(TouchKeys.is_down(KEY_1) and not TouchKeys.is_down(KEY_SPACE), "X buys the first, it does not dig")
	pad.button(JOY_BUTTON_X, false)
	_tap_frames(pad)
	pad.button(JOY_BUTTON_Y, true)
	assert_true(TouchKeys.is_down(KEY_2), "Y buys the second")
	pad.button(JOY_BUTTON_Y, false)
	_tap_frames(pad)
	pad.button(JOY_BUTTON_RIGHT_SHOULDER, true)
	assert_true(TouchKeys.is_down(KEY_3), "RB buys the third")
	pad.button(JOY_BUTTON_RIGHT_SHOULDER, false)
	_tap_frames(pad)
	pad.button(JOY_BUTTON_B, true)
	assert_true(TouchKeys.is_down(KEY_E), "B uses")
	_done(pad)

func test_menu_mode_remaps_the_buttons_while_paused() -> void:
	var pad := _pad()
	tree.paused = true
	pad.button(JOY_BUTTON_A, true)
	assert_true(TouchKeys.is_down(KEY_ENTER) and not TouchKeys.is_down(KEY_W), "A confirms, it does not jump")
	pad.button(JOY_BUTTON_A, false)
	_tap_frames(pad)
	pad.button(JOY_BUTTON_B, true)
	assert_true(TouchKeys.is_down(KEY_ESCAPE), "B closes")
	pad.button(JOY_BUTTON_B, false)
	_tap_frames(pad)
	pad.button(JOY_BUTTON_X, true)
	assert_true(TouchKeys.is_down(KEY_X) and not TouchKeys.is_down(KEY_SPACE), "X abandons, it does not dig")
	pad.button(JOY_BUTTON_X, false)
	_tap_frames(pad)
	pad.button(JOY_BUTTON_START, true)
	assert_true(TouchKeys.is_down(KEY_ESCAPE), "Start closes too")
	pad.button(JOY_BUTTON_START, false)
	_tap_frames(pad)
	pad.axis(JOY_AXIS_LEFT_X, 0.9)
	assert_true(not TouchKeys.is_down(KEY_D), "the stick walks nowhere in a menu")
	_done(pad)

func test_a_button_releases_what_it_pressed_even_after_the_mode_changed() -> void:
	var pad := _pad()
	pad.button(JOY_BUTTON_X, true)
	assert_true(TouchKeys.is_down(KEY_SPACE), "digging")
	tree.paused = true
	pad.button(JOY_BUTTON_X, false)
	assert_true(not TouchKeys.is_down(KEY_SPACE), "lifting X in the menu lets go of the dig key")
	assert_true(not TouchKeys.is_down(KEY_X), "and does not press the abandon key")
	_done(pad)

func test_pausing_lets_go_of_the_directions() -> void:
	var pad := _pad()
	pad.axis(JOY_AXIS_LEFT_X, 0.9)
	assert_true(TouchKeys.is_down(KEY_D), "walking")
	tree.paused = true
	pad._physics_process(0.0)
	assert_true(not TouchKeys.is_down(KEY_D), "an overlay opened: no more walking")
	tree.paused = false
	pad._physics_process(0.0)
	assert_true(TouchKeys.is_down(KEY_D), "and it resumes with the stick still held")
	_done(pad)

func test_release_all_and_disconnect_let_go() -> void:
	var pad := _pad()
	pad.button(JOY_BUTTON_X, true)
	pad.button(JOY_BUTTON_A, true)
	pad.axis(JOY_AXIS_LEFT_X, 0.9)
	pad.release_all()
	assert_true(not TouchKeys.is_down(KEY_SPACE) and not TouchKeys.is_down(KEY_W) and not TouchKeys.is_down(KEY_D), "release_all lets go of everything")
	pad.button(JOY_BUTTON_X, true)
	pad.axis(JOY_AXIS_LEFT_X, 0.9)
	pad._on_joy_connection_changed(0, false)
	assert_true(not TouchKeys.is_down(KEY_SPACE) and not TouchKeys.is_down(KEY_D), "unplugging lets go too")
	_done(pad)

func test_pad_and_touch_share_a_key() -> void:
	var pad := _pad()
	TouchKeys.set_key(KEY_D, true) # a thumb on the on-screen pad
	pad.axis(JOY_AXIS_LEFT_X, 0.9)
	pad.axis(JOY_AXIS_LEFT_X, 0.0)
	assert_true(TouchKeys.is_down(KEY_D), "the thumb still holds D")
	TouchKeys.set_key(KEY_D, false)
	assert_true(not TouchKeys.is_down(KEY_D), "now nobody does")
	_done(pad)

func test_a_joypad_event_switches_the_scheme() -> void:
	var pad := _pad()
	ControlScheme.pad_last = false
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	pad._input(press)
	assert_eq(ControlScheme.current(), "pad", "the first button press")
	_done(pad)
	ControlScheme.pad_last = false
	var drift := InputEventJoypadMotion.new()
	drift.axis = JOY_AXIS_LEFT_X
	drift.axis_value = 0.1
	pad._input(drift)
	assert_eq(ControlScheme.current(), "keys", "stick noise is not a pad being used")
