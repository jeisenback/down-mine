class_name GalleryChecks

## Layout-only checks for the old workings (see docs/superpowers/specs/2026-10-13-galleries-and-clues-design.md).
## Each returns a list of problems; an empty list means the passage is sound.

## A spine's open cells: standing row and the row above are open (inside a collapse both are debris),
## a solid floor lies under every column, and the floor row never changes along a spine.
static func passage_problems(layout: MineLayout, drift: Drift) -> Array[String]:
	var problems: Array[String] = []
	for i in range(drift.length()):
		var x: int = drift.x0 + drift.side * i
		var collapsed := false
		for box in drift.collapses:
			if x >= box.position.x and x < box.end.x:
				collapsed = true
		for y in [drift.row - 1, drift.row]:
			var cell := Vector2i(x, y)
			if collapsed:
				if layout.kind_at(cell) != MineLayout.Kind.DEBRIS:
					problems.append("collapsed cell %s is not debris" % cell)
			elif layout.is_solid(cell):
				problems.append("cell %s should be open" % cell)
		if not layout.is_solid(Vector2i(x, drift.row + 1)) and not in_a_junction_pit(layout, drift, x):
			problems.append("no floor under (%d, %d)" % [x, drift.row])
	return problems

## Whether column x is one of the two columns where a connector drops out of this spine's floor.
static func in_a_junction_pit(layout: MineLayout, drift: Drift, x: int) -> bool:
	return layout.connectors.any(func(c: Connector): return c.mouth.y == drift.row and (x == c.mouth.x or x == c.mouth.x + c.dir))

## Collapse count and sizes within the constants (layer 0 has none), and at least
## MineGrid.DRIFT_END_CLEAR open tiles at each end and between collapses.
static func collapse_problems(drift: Drift) -> Array[String]:
	var problems: Array[String] = []
	if drift.layer == 0:
		if not drift.collapses.is_empty():
			problems.append("Topsoil must have no collapse")
		return problems
	if drift.collapses.size() < MineGrid.SPINE_COLLAPSES_MIN or drift.collapses.size() > MineGrid.SPINE_COLLAPSES_MAX:
		problems.append("%d collapses" % drift.collapses.size())
	var spans: Array = [] # first and last offset along the spine
	for box in drift.collapses:
		if box.size.x < MineGrid.SPINE_COLLAPSE_MIN or box.size.x > MineGrid.SPINE_COLLAPSE_MAX or box.size.y != 2:
			problems.append("collapse %s has a bad size" % box)
		var first: int = box.position.x - drift.x0 if drift.side > 0 else drift.x0 - (box.end.x - 1)
		spans.append(Vector2i(first, first + box.size.x - 1))
	spans.sort_custom(func(p: Vector2i, q: Vector2i): return p.x < q.x)
	var prev_end := -1
	for span in spans:
		if span.x - prev_end - 1 < MineGrid.DRIFT_END_CLEAR:
			problems.append("a collapse at %s leaves too little open before it" % span)
		prev_end = span.y
	if drift.length() - 1 - prev_end < MineGrid.DRIFT_END_CLEAR:
		problems.append("a collapse is too close to the far end")
	return problems

## Whether a spine runs toward the Heart's column from the far side of the map: it starts on the
## side away from the Heart and its far end is nearer to the Heart's column than its start.
static func heads_toward(drift: Drift, heart: Rect2i) -> bool:
	var heart_x: int = heart.position.x + heart.size.x / 2
	return absi(drift.x1 - heart_x) < absi(drift.x0 - heart_x) and drift.side == (1 if drift.x1 > drift.x0 else -1)

## A connector's problems: the junction pit under its spine, a descent of at most one tile every
## two columns with two open rows and a floor everywhere, and its far end beside its room.
static func connector_problems(layout: MineLayout, c: Connector, spine: Drift) -> Array[String]:
	var problems: Array[String] = []
	var n := c.cells.size()
	var dy: int = c.room.cell.y - spine.row
	if n < 2 * dy - 2 or n > MineGrid.CONNECTOR_MAX_LENGTH:
		problems.append("length %d for a drop of %d" % [n, dy])
	if c.mouth != Vector2i(c.cells[0].x, spine.row):
		problems.append("the mouth %s is not above the first cell" % c.mouth)
	for i in range(n):
		var cell: Vector2i = c.cells[i]
		if cell.x != c.cells[0].x + c.dir * i or cell.y != spine.row + 2 + mini(i / 2, dy - 2):
			problems.append("cell %d at %s is off the staircase" % [i, cell])
		for y in [cell.y - 1, cell.y]:
			if layout.is_solid(Vector2i(cell.x, y)):
				problems.append("cell %s should be open" % Vector2i(cell.x, y))
		if not layout.is_solid(Vector2i(cell.x, cell.y + 1)):
			problems.append("no floor under %s" % cell)
	var last: Vector2i = c.cells[n - 1]
	if last.y != c.room.cell.y or not c.room.rect.has_point(last + Vector2i(c.dir, 0)):
		problems.append("the far end %s does not meet the room" % last)
	return problems

## Whether a player can walk from one standing cell to another: along a floor, up a one-tile step,
## or down any drop of at most Player.SAFE_FALL_TILES. Searches the cells within `limit` rows.
static func reachable(layout: MineLayout, from: Vector2i, to: Vector2i, rows: Vector2i) -> bool:
	var seen := {from: true}
	var queue: Array[Vector2i] = [from]
	while not queue.is_empty():
		var at: Vector2i = queue.pop_back()
		if at == to:
			return true
		for dx in [-1, 1]:
			var x: int = at.x + dx
			var next := Vector2i(-1, -1)
			if not layout.is_solid(Vector2i(x, at.y)):
				var y: int = at.y # walk or fall to the first floor
				while y < rows.y and not layout.is_solid(Vector2i(x, y + 1)) and y - at.y <= int(Player.SAFE_FALL_TILES):
					y += 1
				if layout.is_solid(Vector2i(x, y + 1)):
					next = Vector2i(x, y)
			elif not layout.is_solid(Vector2i(x, at.y - 1)): # a one-tile step up
				next = Vector2i(x, at.y - 1)
			if next.x >= 0 and next.y >= rows.x and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return false
