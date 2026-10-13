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
		if not layout.is_solid(Vector2i(x, drift.row + 1)):
			problems.append("no floor under (%d, %d)" % [x, drift.row])
	return problems

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
