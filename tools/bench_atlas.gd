extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for n in [1, 10, 40]:
		var vp := SubViewport.new()
		vp.size = Vector2i(640, 480)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(vp)
		var holder := Node2D.new()
		root.add_child(holder)
		for i in range(n):
			var art := CreatureArt.new()
			art.kind = "stalker"
			art.position = Vector2(32 + (i % 10) * 64, 24 + (i / 10) * 48)
			vp.add_child(art)
			var s := Sprite2D.new()
			var at := AtlasTexture.new()
			at.atlas = vp.get_texture()
			at.region = Rect2((i % 10) * 64, (i / 10) * 48, 64, 48)
			s.texture = at
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.position = Vector2(20 + (i % 10) * 40, 20 + (i / 10) * 40)
			holder.add_child(s)
		for i in range(10):
			await process_frame
		var t0 := Time.get_ticks_usec()
		for i in range(120):
			await process_frame
		print("atlas n=%d: %.2f ms/frame" % [n, (Time.get_ticks_usec() - t0) / 120000.0])
		holder.queue_free()
		vp.queue_free()
		await process_frame
	quit()
