extends RefCounted
class_name TestCase

## Base for test scripts run by tests/run_tests.gd. GDScript has no
## exceptions, so assertions record failures instead of aborting; the
## runner reports them per test. `tree` is set before each test so
## scene tests can add nodes and await frames.

const TEST_SAVE_PATH := "user://test_save.cfg"

const SHARED_MINE_OFFSET := 10000000.0

## Mines generated once and shared by tests that only read them (see shared_mine).
static var _shared_mines: Dictionary = {}

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

## A mine for `mine_seed`, generated once per run and shared: generation costs
## about a second, and many tests only read the same seeds. READ ONLY - a test
## that digs, decays, or compares two mines of one seed uses a fresh mine.
func shared_mine(mine_seed: int) -> MineGrid:
	var cached = _shared_mines.get(mine_seed)
	if is_instance_valid(cached):
		return cached
	var holder: Node = tree.root.get_node_or_null("SharedMines")
	if holder == null: # the runner makes it first so the per-test cleanup leaves it alone
		holder = Node.new()
		holder.name = "SharedMines"
		tree.root.add_child(holder)
	MineGrid.next_seed = mine_seed
	var mine: MineGrid = load("res://scenes/Mine.tscn").instantiate()
	mine.position = Vector2(SHARED_MINE_OFFSET, SHARED_MINE_OFFSET) # its collision must not meet other tests' players
	holder.add_child(mine)
	_shared_mines[mine_seed] = mine
	return mine
