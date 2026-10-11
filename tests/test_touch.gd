extends TestCase

## Touch controls (milestone 58): the pad's rule, synthetic key state, and the
## on-screen widgets that press the same keys the keyboard does.

func test_pad_directions() -> void:
	var r := 60.0
	assert_eq(TouchPad.keys_for(Vector2(0.8 * r, 0), r), [KEY_D], "right")
	assert_eq(TouchPad.keys_for(Vector2(-0.8 * r, 0), r), [KEY_A], "left")
	assert_eq(TouchPad.keys_for(Vector2(0, -0.8 * r), r), [KEY_W], "up")
	assert_eq(TouchPad.keys_for(Vector2(0, 0.8 * r), r), [KEY_S], "down")

func test_pad_diagonals_return_two_keys() -> void:
	var keys := TouchPad.keys_for(Vector2(50, 50), 60.0)
	assert_eq(keys.size(), 2, "two keys")
	assert_true(keys.has(KEY_D) and keys.has(KEY_S), "down and right: the stair dig")

func test_pad_dead_zone_returns_nothing() -> void:
	var r := 60.0
	for offset in [Vector2(0.2 * r, 0), Vector2(0, 0.2 * r), Vector2(-0.2 * r, -0.2 * r), Vector2.ZERO]:
		assert_eq(TouchPad.keys_for(offset, r), [], "inside the dead zone: %s" % offset)

func test_set_key_only_changes_state() -> void:
	TouchKeys.release_all()
	var before := TouchKeys.sent_count
	TouchKeys.set_key(KEY_SPACE, true)
	TouchKeys.set_key(KEY_SPACE, true)
	assert_eq(TouchKeys.sent_count, before + 1, "the second press changed nothing")
	assert_true(TouchKeys.is_down(KEY_SPACE), "held")
	TouchKeys.release_all()
	assert_eq(TouchKeys.sent_count, before + 2, "release_all sent one release")
	assert_true(not TouchKeys.is_down(KEY_SPACE), "let go")
