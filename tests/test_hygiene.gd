extends TestCase

## Test isolation and structure guards (milestone 67): the static hooks are reset in one place,
## every new static variable has to be accounted for, and groups are named by constants.

func test_reset_puts_every_static_hook_back() -> void:
	HUD.title_seen = false
	TouchControls.force = true
	TouchControls.seen_touch = true
	MineGrid.next_seed = 77
	Progress.path_override = "user://somewhere_else.cfg"
	TouchKeys.set_key(KEY_X, true)
	TestHooks.reset("user://a_test_save.cfg")
	assert_true(HUD.title_seen, "scene tests must not start paused on the title")
	assert_true(not TouchControls.force and not TouchControls.seen_touch, "touch controls are not forced or revealed")
	assert_eq(MineGrid.next_seed, 0, "no seed is queued")
	assert_eq(Progress.path_override, "user://a_test_save.cfg", "the save path is the one given")
	assert_true(not TouchKeys.is_down(KEY_X), "no key is held")
	TestHooks.reset(TEST_SAVE_PATH)

func test_every_static_variable_is_reset_or_explained() -> void:
	for found in _static_vars():
		var covered: bool = TestHooks.RESET.has(found) or TestHooks.EXPLAINED.has(found)
		assert_true(covered, "%s is a static variable: reset it in TestHooks.reset or explain it in TestHooks.EXPLAINED" % found)
	for listed in TestHooks.RESET + TestHooks.EXPLAINED.keys():
		assert_true(_static_vars().has(listed), "%s is listed in TestHooks but is not a static variable any more" % listed)

func test_groups_are_named_by_constants_not_strings() -> void:
	var pattern := RegEx.create_from_string("(add_to_group|remove_from_group|get_nodes_in_group|get_first_node_in_group|is_in_group|call_group)\\(\\s*[\"']")
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd"):
			continue
		var text := FileAccess.get_file_as_string("res://scripts/" + file)
		var lines := text.split("\n")
		for i in range(lines.size()):
			if pattern.search(lines[i]) != null:
				assert_true(false, "%s:%d names a group with a string: %s" % [file, i + 1, lines[i].strip_edges()])

func test_key_edge_fires_once_per_press() -> void:
	var key := KeyEdge.new()
	assert_true(not key.pressed(false), "up: no edge")
	assert_true(key.pressed(true), "goes down: edge")
	assert_true(not key.pressed(true), "held: no second edge")
	assert_true(not key.pressed(false), "released: no edge")
	assert_true(key.pressed(true), "pressed again: edge")
	key.hold(true)
	assert_true(not key.pressed(true), "a key held at the start is not a press")

func test_run_context_hands_events_the_run() -> void:
	var run := RunContext.new()
	var seen: Array = []
	run.bind(func(): seen.append("heart"), func(x: float): seen.append(x), func(): return "page",
			func(n: int): seen.append(n), func(): seen.append("nest"))
	run.take_heart()
	run.ride_to_surface(12.5)
	run.add_lamps(3)
	run.nest_destroyed()
	assert_eq(seen, ["heart", 12.5, 3, "nest"], "each action reaches what Main bound")
	assert_eq(run.read_journal_page(), "page", "the page comes back")

func test_events_take_the_run_context_not_a_bare_node() -> void:
	var pattern := RegEx.create_from_string("func (use|prompt)\\(\\w+: Node\\)")
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd"):
			continue
		var lines := FileAccess.get_file_as_string("res://scripts/" + file).split("\n")
		for i in range(lines.size()):
			if pattern.search(lines[i]) != null:
				assert_true(false, "%s:%d takes an untyped Node: use RunContext" % [file, i + 1])

## "Class.name" for every `static var` in the scripts.
func _static_vars() -> Array:
	var found: Array = []
	var declaration := RegEx.create_from_string("^static var (\\w+)")
	var class_line := RegEx.create_from_string("^class_name (\\w+)")
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd"):
			continue
		var owner_name := file.get_basename()
		var names: Array = []
		for line in FileAccess.get_file_as_string("res://scripts/" + file).split("\n"):
			var named := class_line.search(line)
			if named != null:
				owner_name = named.get_string(1)
			var decl := declaration.search(line)
			if decl != null:
				names.append(decl.get_string(1))
		for n in names:
			found.append("%s.%s" % [owner_name, n])
	return found
