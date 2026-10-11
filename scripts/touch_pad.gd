extends RefCounted
class_name TouchPad

## The on-screen pad's rule (milestone 58): which of A, D, W and S a thumb
## resting at an offset from the pad's centre presses. Beyond the dead zone
## on both axes it presses two keys, which is how one finger digs a stair.

## Fraction of the pad's radius inside which a thumb presses nothing.
const DEAD_ZONE := 0.3
## The weaker axis of a diagonal needs this much of the radius, so a thumb that
## drifts a little to one side does not start a stair (down and a side together).
const STAIR_ZONE := 0.5

static func keys_for(offset: Vector2, radius: float) -> Array:
	var dead := DEAD_ZONE * radius
	var stair := STAIR_ZONE * radius
	var x_on := absf(offset.x) > dead
	var y_on := absf(offset.y) > dead
	if x_on and y_on:
		# A diagonal: the stronger axis keeps its dead zone, the weaker one needs the stair zone.
		if absf(offset.x) >= absf(offset.y):
			y_on = absf(offset.y) > stair
		else:
			x_on = absf(offset.x) > stair
	var keys: Array = []
	if x_on:
		keys.append(KEY_D if offset.x > 0.0 else KEY_A)
	if y_on:
		keys.append(KEY_S if offset.y > 0.0 else KEY_W)
	return keys
