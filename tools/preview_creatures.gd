extends SceneTree

## Renders CreatureArt through 48x48 viewports and writes a contact sheet:
## one row per kind, six samples across an animation cycle, x5 nearest.
##   xvfb-run -a godot --fixed-fps 60 -s tools/preview_creatures.gd

const KINDS := ["stalker", "burrower", "snuffer", "fuel", "ore"]
const COLS := 6
const CELL := 48
const ZOOM := 5

func _initialize() -> void:
	var holders: Array = []
	for kind in KINDS:
		for c in range(COLS):
			var vp := SubViewport.new()
			vp.size = Vector2i(CELL, CELL)
			vp.transparent_bg = false
			vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			var bg := ColorRect.new()
			bg.color = Color8(24, 22, 28)
			bg.size = Vector2(CELL, CELL)
			vp.add_child(bg)
			var art := CreatureArt.new()
			art.kind = kind
			art.animate = false
			art.t = float(c) / COLS * 1.6
			art.pose = 1.0 if c == 3 else 0.0
			art.position = Vector2(CELL / 2, CELL / 2)
			vp.add_child(art)
			root.add_child(vp)
			holders.append(vp)
	for i in range(4):
		await process_frame
	var sheet := Image.create(COLS * CELL, KINDS.size() * CELL, false, Image.FORMAT_RGBA8)
	for i in range(holders.size()):
		var img: Image = holders[i].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i((i % COLS) * CELL, (i / COLS) * CELL))
	sheet.resize(sheet.get_width() * ZOOM, sheet.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	sheet.save_png("res://docs/redraw/proc_creatures.png")
	print("wrote docs/redraw/proc_creatures.png ", sheet.get_size())
	quit()
