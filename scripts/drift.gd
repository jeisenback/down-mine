extends RefCounted
class_name Drift

## An old gallery off the entrance shaft (milestone 51b; "drift" in code, since Gallery is the
## collapsing ore room): a two-tile tunnel on one side of the shaft, one per worked layer.
var layer: int
## -1 for the shaft's left, 1 for its right.
var side: int
## The standing row; its floor is row + 1.
var row: int
## The first cell beside the shaft, and the far end.
var x0: int
var x1: int
## The collapsed stretches (every drift below Topsoil); empty in Topsoil.
var collapses: Array[Rect2i] = []
## Whether the old shaft feeds this drift (its mouth is beside the shaft).
var from_shaft := true
## What stands at the far end: "camp", or "miner" for the Stone gallery.
var end_kind: String

func _init(drift_layer: int, drift_side: int, drift_row: int, first_x: int, last_x: int, end: String) -> void:
	layer = drift_layer
	side = drift_side
	row = drift_row
	x0 = first_x
	x1 = last_x
	end_kind = end

func length() -> int:
	return absi(x1 - x0) + 1

## Every open cell of the drift, both rows.
func cells() -> Array[Vector2i]:
	var open: Array[Vector2i] = []
	for i in range(length()):
		var x := x0 + side * i
		open.append(Vector2i(x, row - 1))
		open.append(Vector2i(x, row))
	return open

## The dictionary this class replaced, key for key (the golden mine fingerprints hash it).
func to_dict() -> Dictionary:
	return {"layer": layer, "side": side, "row": row, "x0": x0, "x1": x1,
		"features": {"collapse": collapses[0] if not collapses.is_empty() else Rect2i(), "end": end_kind}}
