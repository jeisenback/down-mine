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

func test_art_starts_asleep_and_wakes_only_when_seen() -> void:
	var a := _make("ore")
	await tree.process_frame
	# The notifier only reports exits after an entry, so art must not start awake.
	assert_eq(a.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "spawned asleep")
	assert_true(not a.art.is_processing(), "not animating")
	a._on_art_drawn()
	assert_eq(a.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "a stray redraw does not wake it")
	a._on_screen_entered()
	assert_true(a.art.is_processing(), "seen: animating")
	a._on_art_drawn()
	assert_eq(a.viewport.render_target_update_mode, SubViewport.UPDATE_ONCE, "renders once per redraw")
	a._on_screen_exited()
	assert_eq(a.viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "gone again: asleep")
	assert_true(not a.art.is_processing(), "and still")

func test_the_visibility_rect_follows_a_mirrored_sprite() -> void:
	var a := ArtSprite.new()
	a.kind = "burrower"
	a.cell = Vector2i(64, 48)
	a.origin = Vector2i(48, 26)
	add(a)
	await tree.process_frame
	var notifier: VisibleOnScreenNotifier2D = a.get_node("Notifier")
	assert_eq(notifier.rect, Rect2(a.sprite.position - Vector2(32, 24), Vector2(64, 48)), "unmirrored")
	a.flip_h = true
	assert_eq(notifier.rect, Rect2(a.sprite.position - Vector2(32, 24), Vector2(64, 48)), "mirrored")
	assert_eq(a.sprite.position.x, 16.0, "the sprite sits on the mirrored side")
	assert_eq(notifier.rect.position.x, -16.0, "and so does its visibility rect")

func test_art_redraws_at_a_fixed_rate_not_every_frame() -> void:
	var a := _make("stalker")
	await tree.process_frame
	var redraws := [0]
	a.art.draw.connect(func(): redraws[0] += 1)
	for i in range(30):
		a.art._process(1.0 / 60.0)
		await tree.process_frame
	assert_true(redraws[0] > 0 and redraws[0] <= 20, "about REDRAW_FPS draws in half a second, got %d" % redraws[0])

func test_unknown_kind_is_a_blank() -> void:
	var a := _make("nope")
	await tree.process_frame
	assert_true(a.art == null, "no art")
	a.flip_h = true
	a.queue_free()

func test_the_hub_gears_build_gear_art() -> void:
	for name in ["lamp_shop", "smithy", "bunkhouse", "notice_board", "entrance"]:
		var a := _make(name)
		await tree.process_frame
		assert_true(a.art is GearArt, "%s builds a gear art" % name)
		if a.art is GearArt:
			assert_eq(a.art.gear, name, "%s gear" % name)

# --- the unlit glow layer (M92) ----------------------------------------------------------------

func _make_glow(kind: String = "stalker") -> ArtSprite:
	var a := ArtSprite.new()
	a.kind = kind
	a.glow = true
	add(a)
	return a

func test_glow_is_off_by_default() -> void:
	var a := _make("stalker")
	await tree.process_frame
	assert_eq(a.glow_viewport, null, "no glow viewport")
	assert_eq(a.glow_art, null, "no glow art")
	assert_eq(a.glow_sprite, null, "no glow sprite")

func test_a_glow_sprite_is_unshaded_and_shares_the_pixel_grid() -> void:
	var a := _make_glow()
	await tree.process_frame
	assert_true(a.glow_sprite.material is CanvasItemMaterial, "a canvas item material")
	assert_eq((a.glow_sprite.material as CanvasItemMaterial).light_mode, CanvasItemMaterial.LIGHT_MODE_UNSHADED, "unshaded: it ignores the dark")
	assert_eq(a.glow_sprite.texture_filter, CanvasItem.TEXTURE_FILTER_NEAREST, "nearest")
	assert_eq(a.glow_sprite.position, a.sprite.position, "on the lit sprite's pixels")
	assert_eq(a.glow_viewport.size, a.cell, "the same cell")
	assert_true(a.glow_art.glow_only and not a.glow_art.is_processing() and not a.glow_art.animate, "the glow art draws only the glow, on the lit art's clock")

func test_the_glow_mirrors_with_the_sprite() -> void:
	var a := _make_glow()
	await tree.process_frame
	a.flip_h = true
	assert_eq(a.glow_sprite.scale.x, a.sprite.scale.x, "mirrored together")
	assert_eq(a.glow_sprite.position, a.sprite.position, "and placed together")
	a.flip_h = false
	assert_eq(a.glow_sprite.scale.x, 1.0, "restored")

func test_the_glow_follows_the_lit_arts_clock_and_pose() -> void:
	var a := _make_glow()
	await tree.process_frame
	a.art.t = 3.5
	a.art.pose = 1.0
	a.art.variant = 1
	a._on_art_drawn()
	assert_eq(a.glow_art.t, 3.5, "the same clock")
	assert_eq(a.glow_art.pose, 1.0, "the same pose")
	assert_eq(a.glow_art.variant, 1, "the same variant")

func test_the_glow_sleeps_off_screen() -> void:
	var a := _make_glow()
	await tree.process_frame
	assert_eq(a.glow_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "spawned asleep")
	a._on_screen_entered()
	a._on_art_drawn()
	assert_eq(a.glow_viewport.render_target_update_mode, SubViewport.UPDATE_ONCE, "renders once per redraw while seen")
	a._on_screen_exited()
	assert_eq(a.glow_viewport.render_target_update_mode, SubViewport.UPDATE_DISABLED, "gone again: asleep")
