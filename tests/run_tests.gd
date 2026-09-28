extends SceneTree

## Headless test runner:
##   godot --headless --fixed-fps 60 -s tests/run_tests.gd
## Runs every test_* method in tests/test_*.gd and exits 1 on any failure.

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var failed := 0
	var passed := 0
	for file in DirAccess.get_files_at("res://tests"):
		if not (file.begins_with("test_") and file.ends_with(".gd")):
			continue
		var script: GDScript = load("res://tests/" + file)
		for method in script.get_script_method_list():
			var name: String = method.name
			if not name.begins_with("test_"):
				continue
			var case: TestCase = script.new()
			case.tree = self
			var before := root.get_child_count()
			await case.call(name)
			while root.get_child_count() > before:
				var node := root.get_child(root.get_child_count() - 1)
				root.remove_child(node)
				node.free()
			if case.failures.is_empty():
				passed += 1
				print("  ok    %s.%s" % [file.get_basename(), name])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [file.get_basename(), name])
				for f in case.failures:
					print("          " + f)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TestCase.TEST_SAVE_PATH))
	print("%d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
