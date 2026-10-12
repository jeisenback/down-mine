extends RefCounted
class_name KeyEdge

## Edge detection for a polled key: true only on the frame it goes down.
## Call pressed() once per frame, first in any condition, so a later
## `and` never skips the update.
var _was_down: bool = false

func pressed(down: bool) -> bool:
	var edge := down and not _was_down
	_was_down = down
	return edge

## Start as if the key is already held, so that press does not count.
func hold(down: bool) -> void:
	_was_down = down
