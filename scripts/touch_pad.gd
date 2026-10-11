extends RefCounted
class_name TouchPad

## The on-screen pad's rule (milestone 58): which of A, D, W and S a thumb
## resting at an offset from the pad's centre presses. Beyond the dead zone
## on both axes it presses two keys, which is how one finger digs a stair.

## Fraction of the pad's radius inside which a thumb presses nothing.
const DEAD_ZONE := 0.3

static func keys_for(offset: Vector2, radius: float) -> Array:
	var keys: Array = []
	var dead := DEAD_ZONE * radius
	if offset.x > dead:
		keys.append(KEY_D)
	elif offset.x < -dead:
		keys.append(KEY_A)
	if offset.y < -dead:
		keys.append(KEY_W)
	elif offset.y > dead:
		keys.append(KEY_S)
	return keys
