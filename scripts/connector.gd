extends RefCounted
class_name Connector

## A passage from a spine down to a room (old workings, phase 2). It leaves the spine through a
## two-column pit in its floor, then descends one tile every two columns, below the spine's own
## floor, and ends beside the room. Only rooms at least two rows under their spine get one.
var room: EventRoom
var layer: int
## +1 runs toward larger x, -1 toward smaller.
var dir: int
## The standing cells in order: the pit first, the cell beside the room last.
var cells: Array[Vector2i] = []
## The spine's standing cell directly above the first cell: where the passage is entered.
var mouth: Vector2i

func _init(target: EventRoom, room_layer: int, run_dir: int, first_cells: Array[Vector2i], spine_cell: Vector2i) -> void:
	room = target
	layer = room_layer
	dir = run_dir
	cells = first_cells
	mouth = spine_cell

## The dictionary the golden mine fingerprints hash.
func to_dict() -> Dictionary:
	return {"room": room.to_dict(), "layer": layer, "dir": dir, "cells": cells, "mouth": mouth}
