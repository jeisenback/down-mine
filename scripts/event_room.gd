extends RefCounted
class_name EventRoom

## A chamber carved for one mine event that Main places (Main._spawn_events), or an event
## standing in the old mine.
var kind: String
## The floor-standing centre of the room.
var cell: Vector2i
var rect: Rect2i
## The lift: it stands in the shaft's own edge column.
var in_shaft := false
## A camp at the far end of a drift.
var at_drift_end := false
## A vault's doorway (its lower cell); (-1, -1) for every other room.
var door := Vector2i(-1, -1)

func _init(room_kind: String, room_cell: Vector2i, room_rect: Rect2i) -> void:
	kind = room_kind
	cell = room_cell
	rect = room_rect

## The dictionary this class replaced, key for key (the golden mine fingerprints hash it).
func to_dict() -> Dictionary:
	var entry := {"kind": kind, "cell": cell, "rect": rect}
	if kind == "vault":
		entry["door"] = door
	elif in_shaft:
		entry["shaft"] = true
	elif at_drift_end:
		entry["drift"] = true
	return entry
