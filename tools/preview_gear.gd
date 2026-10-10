extends SceneTree

## Contact sheet for GearArt: the miner in each state, then the base and
## buildings, next to nothing else. xvfb-run -a godot --fixed-fps 60 -s tools/preview_gear.gd

const ROWS := [
	["player", "idle", 0.0], ["player", "run", 0.0], ["player", "run", 0.13], ["player", "run", 0.26],
	["player", "dig", 0.0], ["player", "dig", 0.4], ["player", "jump", 0.0], ["player", "fall", 0.0],
	["flag", "idle", 0.0], ["flag", "idle", 0.5], ["beacon", "idle", 0.0], ["bell", "idle", 0.0],
	["support", "idle", 0.0], ["lamp", "idle", 0.0], ["lamp", "idle", 0.3], ["bell", "idle", 1.0],
	["support", "idle", 0.5], ["support", "idle", 1.0],
]
const COLS := 8
const CELL := 48
const ZOOM := 5

func _initialize() -> void:
	var vps: Array = []
	for r in ROWS:
		var vp := SubViewport.new()
		vp.size = Vector2i(CELL, CELL)
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		var bg := ColorRect.new()
		bg.color = Color8(24, 22, 28)
		bg.size = Vector2(CELL, CELL)
		vp.add_child(bg)
		var art := GearArt.new()
		art.gear = r[0]
		art.state = r[1]
		art.animate = false
		art.t = r[2]
		art.pose = 1.0 if r[0] == "bell" and r[2] == 1.0 else (r[2] if r[0] == "support" else 0.0)
		art.position = Vector2(CELL / 2, CELL / 2 + (14 if r[0] in ["player", "flag", "support", "lamp"] else 0))
		vp.add_child(art)
		root.add_child(vp)
		vps.append(vp)
	for i in range(4):
		await process_frame
	var sheet := Image.create(COLS * CELL, ((ROWS.size() + COLS - 1) / COLS) * CELL, false, Image.FORMAT_RGBA8)
	sheet.fill(Color8(24, 22, 28))
	for i in range(vps.size()):
		var img: Image = vps[i].get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		sheet.blit_rect(img, Rect2i(0, 0, CELL, CELL), Vector2i((i % COLS) * CELL, (i / COLS) * CELL))
	sheet.resize(sheet.get_width() * ZOOM, sheet.get_height() * ZOOM, Image.INTERPOLATE_NEAREST)
	sheet.save_png("res://docs/redraw/proc_player_base.png")
	print("wrote docs/redraw/proc_player_base.png ", sheet.get_size())
	quit()
