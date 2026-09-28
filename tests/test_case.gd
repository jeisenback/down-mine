extends RefCounted
class_name TestCase

## Base for test scripts run by tests/run_tests.gd. GDScript has no
## exceptions, so assertions record failures instead of aborting; the
## runner reports them per test. `tree` is set before each test so
## scene tests can add nodes and await frames.

const TEST_SAVE_PATH := "user://test_save.cfg"

var tree: SceneTree
var failures: Array[String] = []

func assert_eq(actual, expected, message: String = "") -> void:
	if actual != expected:
		failures.append("%s: expected %s, got %s" % [message, str(expected), str(actual)])

func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		failures.append(message if message != "" else "expected true")

## Nodes added here are freed after the test.
func add(node: Node) -> Node:
	tree.root.add_child(node)
	return node

func physics_frames(count: int) -> void:
	for i in range(count):
		await tree.physics_frame
