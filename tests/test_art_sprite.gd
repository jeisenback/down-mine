extends TestCase

## ArtSprite: procedural art drawn in a small viewport and shown pixelated.

func _make(kind: String, length: float = 64.0) -> ArtSprite:
	var a := ArtSprite.new()
	a.kind = kind
	a.length = length
	add(a)
	return a

func test_a_creature_kind_builds_a_creature_art() -> void:
	var a := _make("stalker")
	await tree.process_frame
	assert_true(a.art is CreatureArt and not (a.art is GearArt), "creature art")
	assert_eq(a.art.kind, "stalker", "kind")

func test_a_gear_kind_builds_a_gear_art_with_its_length() -> void:
	var a := _make("ladder", 40.0)
	await tree.process_frame
	assert_true(a.art is GearArt, "gear art")
	assert_eq(a.art.gear, "ladder", "gear")
	assert_eq(a.art.length, 40.0, "length")
	var p := _make("player")
	await tree.process_frame
	assert_eq(p.art.gear, "player", "player gear")

func test_origin_is_the_nodes_position() -> void:
	var a := ArtSprite.new()
	a.kind = "stalker"
	a.cell = Vector2i(48, 48)
	a.origin = Vector2i(24, 36)
	add(a)
	await tree.process_frame
	assert_eq(a.sprite.position, Vector2(0, -12), "cell centre sits above the origin")
	assert_true(a.sprite.centered, "centered")

func test_flip_h_mirrors_about_the_origin() -> void:
	var a := _make("burrower")
	await tree.process_frame
	var y := a.sprite.position.y
	a.flip_h = true
	assert_eq(a.sprite.scale.x, -1.0, "mirrored")
	assert_eq(a.sprite.position.y, y, "y unchanged")
	a.flip_h = false
	assert_eq(a.sprite.scale.x, 1.0, "restored")

func test_pixel_settings() -> void:
	var a := _make("snuffer")
	await tree.process_frame
	assert_true(a.viewport.transparent_bg, "transparent")
	assert_eq(a.viewport.size, a.cell, "viewport matches cell")
	assert_eq(a.viewport.msaa_2d, Viewport.MSAA_DISABLED, "no msaa")
	assert_eq(a.sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "nearest")

func test_clock_phase_differs_per_instance() -> void:
	var phases := {}
	for i in range(10):
		var a := _make("fuel")
		await tree.process_frame
		phases[a.art.t] = true
	assert_true(phases.size() > 1, "phases differ")

func test_offscreen_art_does_not_render() -> void:
	var a := _make("ore")
	await tree.process_frame
	a._on_screen_exited()
	assert_eq(a.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "off screen")
	a._on_screen_entered()
	assert_eq(a.viewport.render_target_update_mode, SubViewport.UPDATE_ALWAYS, "on screen")

func test_unknown_kind_is_a_blank() -> void:
	var a := _make("nope")
	await tree.process_frame
	assert_true(a.art == null, "no art")
	a.flip_h = true
	a.queue_free()
