class_name MineFingerprint

## A hash of everything observable about a generated MineGrid, so a refactor of
## generation can prove every seed still builds the same mine (issue #74).

## The MineGrid members the fingerprint covers; a test checks this list stays complete.
const FIELDS := [
	"mine_seed", "shaft_end_row", "lost_miner_cell", "old_ladder_rows", "drifts", "event_rooms", "torches",
	"_room_cells", "_reserved_floors", "_plank_cells", "_debris_cells", "_vault_cells", "_spare_floor_cells",
]

static func of(mine: MineGrid) -> String:
	var parts: PackedStringArray = []
	for layer in [0, MineGrid.DECOR_LAYER]:
		var row_parts: PackedStringArray = []
		for x in range(MineGrid.GRID_WIDTH):
			for y in range(MineGrid.GRID_HEIGHT):
				row_parts.append(str(mine.get_cell_atlas_coords(layer, Vector2i(x, y))))
		parts.append("\n".join(row_parts))
	for field in FIELDS:
		var value = mine.get(field)
		if value is Dictionary and field.ends_with("_cells") or field == "_reserved_floors":
			parts.append(field + var_to_str(_sorted_cells(value.keys())))
		else:
			parts.append(field + var_to_str(value))
	for child in mine.get_children():
		if child is FuelPickup or child is OrePickup or child is Torch:
			parts.append("%s %s %s" % [child.get_script().get_global_name(), child.position, child.get("value")])
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update("\n".join(parts).to_utf8_buffer())
	return hasher.finish().hex_encode()

static func _sorted_cells(cells: Array) -> Array:
	var sorted := cells.duplicate()
	sorted.sort_custom(func(a: Vector2i, b: Vector2i): return a.x < b.x or (a.x == b.x and a.y < b.y))
	return sorted
