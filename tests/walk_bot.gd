extends RefCounted
class_name WalkBot

## A test-only bot that walks the real Player toward a cell with real key presses (or the
## gamepad's named methods), so a passage is proved walkable on the real body and not only
## on tile data. It holds A or D toward the target, jumps when it stops making progress, and
## reports what happened. It never digs. Every exit path releases every key it holds.
##   var result = await WalkBot.walk_to(tree, player, mine, target, 8.0, WalkBot.KeyDriver.new())

const STALL_SECONDS := 0.25
const MAX_JUMPS := 40
const SOURCE := "bot"
## A jump holds W this long: the apex comes at 0.41 s, and a held jump is a full one.
const JUMP_HOLD_SECONDS := 0.4
## Progress means moving this far along x within the stall window.
const PROGRESS_PX := 2.0
const NOT_STUCK := Vector2i(-1, -1)

static func budget_seconds(tiles: int) -> float:
	return 4.0 + 1.5 * tiles / 7.5

## Presses A, D and W through TouchKeys under its own source.
class KeyDriver extends RefCounted:
	func go(dir: int, jump: bool) -> void:
		TouchKeys.set_key(KEY_A, dir < 0, WalkBot.SOURCE)
		TouchKeys.set_key(KEY_D, dir > 0, WalkBot.SOURCE)
		TouchKeys.set_key(KEY_W, jump, WalkBot.SOURCE)

	func stop() -> void:
		TouchKeys.release_all(WalkBot.SOURCE)

## The same through the gamepad's left stick and A button.
class PadDriver extends RefCounted:
	var _pad: GamepadControls

	func _init(pad: GamepadControls) -> void:
		_pad = pad

	func go(dir: int, jump: bool) -> void:
		_pad.axis(JOY_AXIS_LEFT_X, float(dir))
		_pad.button(JOY_BUTTON_A, jump)

	func stop() -> void:
		_pad.release_all()

## Walks `player` toward `target` for at most `max_seconds`. Returns
## {reached, seconds, jumps, stuck_at}; stuck_at is the player's cell when not reached. Reached
## means within `x_slack` cells of the target along x and `y_slack` along y (both default 1). With the right
## column but the wrong row it stops pushing sideways and jumps when it makes no progress.
static func walk_to(tree: SceneTree, player: Player, mine: MineGrid, target: Vector2i, max_seconds: float, driver, y_slack: int = 1, x_slack: int = 1) -> Dictionary:
	var elapsed := 0.0
	var jumps := 0
	var stalled_jumps := 0
	var jump_left := 0.0
	var window_x := player.global_position.x
	var window_dir := 0
	var window_time := 0.0
	var reached := false
	while elapsed < max_seconds and stalled_jumps < MAX_JUMPS:
		var cell := mine.world_to_cell(player.global_position)
		if absi(cell.x - target.x) <= x_slack and absi(cell.y - target.y) <= y_slack:
			reached = true
			break
		var dir := signi(target.x - cell.x)
		if dir != window_dir:
			window_dir = dir
			window_x = player.global_position.x
			window_time = 0.0
		if jump_left <= 0.0 and window_time >= STALL_SECONDS:
			if absf(player.global_position.x - window_x) < PROGRESS_PX:
				jump_left = JUMP_HOLD_SECONDS
				jumps += 1
				stalled_jumps += 1
			else:
				stalled_jumps = 0
			window_x = player.global_position.x
			window_time = 0.0
		driver.go(dir, jump_left > 0.0)
		await tree.physics_frame
		var step := 1.0 / Engine.physics_ticks_per_second
		elapsed += step
		window_time += step
		jump_left -= step
	driver.stop()
	var end_cell := mine.world_to_cell(player.global_position)
	return {"reached": reached, "seconds": elapsed, "jumps": jumps,
		"stuck_at": NOT_STUCK if reached else end_cell}

## Puts the player on the spine cell beside the connector's mouth, walks to the room's cell, then
## back up to the mouth itself (standing on the spine, not just in the pit under it). Returns {out, back}, each a walk_to result.
static func walk_connector(tree: SceneTree, player: Player, mine: MineGrid, connector: Connector, driver) -> Dictionary:
	var start: Vector2i = connector.mouth + Vector2i(-connector.dir, 0)
	player.global_position = mine.cell_to_world(start)
	player.velocity = Vector2.ZERO
	await tree.physics_frame
	var budget := budget_seconds(connector.cells.size() + 4)
	# A runner crosses the two-wide pit without falling in (the rim steps it over), so the bot
	# first stops over the opening, as a player entering the passage does, then follows it.
	var to_mouth := await walk_to(tree, player, mine, connector.mouth, budget, driver, 3, 0)
	for i in range(30): # let it settle into the pit
		if mine.world_to_cell(player.global_position).y > connector.mouth.y:
			break
		await tree.physics_frame
	var out := await walk_to(tree, player, mine, connector.room.cell, budget, driver)
	out["seconds"] += to_mouth["seconds"]
	out["jumps"] += to_mouth["jumps"]
	if not to_mouth["reached"]:
		out = to_mouth
	var back := await walk_to(tree, player, mine, connector.mouth, budget, driver, 0)
	return {"out": out, "back": back}
