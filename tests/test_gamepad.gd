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
