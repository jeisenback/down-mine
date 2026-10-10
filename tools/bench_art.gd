extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for n in [0, 1, 10, 40]:
		var holder := Node2D.new()
		root.add_child(holder)
		for i in range(n):
			var a := ArtSprite.new()
			a.kind = "stalker"
			a.position = Vector2(20 + (i % 10) * 40, 20 + (i / 10) * 40)
			holder.add_child(a)
		for i in range(10):
			await process_frame
		var t0 := Time.get_ticks_usec()
		for i in range(120):
			await process_frame
		print("n=%d: %.2f ms/frame" % [n, (Time.get_ticks_usec() - t0) / 120000.0])
		holder.queue_free()
		await process_frame
	quit()
