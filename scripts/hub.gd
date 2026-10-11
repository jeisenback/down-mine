extends Node2D
class_name Hub

## The settlement between runs (milestone 57): a flat strip you walk as the
## miner. Buildings sell the hub upgrades, the bunkhouse's figures are the
## rostered miners, the notice board shows the log, and the entrance starts
## a run. No purchase rules live here: key presses call named methods
## (press_number, press_use, enter_mine), which call the buildings and
## miners, which call Progress.

const STRIP_WIDTH := 720.0
const BUILDING_X := {"lamp_shop": 100.0, "smithy": 200.0, "bunkhouse": 300.0, "notice_board": 540.0}
const ENTRANCE_X := 640.0
## Ten figures stand 14 px apart from here, ending before the notice board.
const MINER_X0 := 340.0
const MINER_STEP := 14.0
## The player's centre when standing on the ground (the ground's top is y = 0).
const PLAYER_Y := -8.0
const MINER_Y := -7.0 # the drawn miner's feet sit 7 px below its centre
const MAIN_SCENE := "res://scenes/Main.tscn"

@onready var player: Player = $Player
@onready var hud: HUD = $HUD

var progress: Progress
var buildings: Array[HubBuilding] = []
var miners: Array[HubMiner] = []
var board_label: Label
var board_panel: ColorRect
var change_scene: Callable = func(path: String): Engine.get_main_loop().change_scene_to_file(path)

func _ready() -> void:
	progress = Progress.load_saved()
	_build_ground()
	for kind in BUILDING_X:
		_add_building(kind, BUILDING_X[kind])
	_add_entrance()
	for i in range(min(progress.roster.size(), 10)):
		_add_miner(progress.roster[i], MINER_X0 + i * MINER_STEP)
	_build_board_panel()
	player.global_position = Vector2(60.0, PLAYER_Y)
	player.light.set_process(false) # nothing burns down here
	player.light.point_light.visible = false # the hub is lit by day, not by the lantern
	var camera: Camera2D = player.get_node("Camera2D")
	camera.limit_left = 0
	camera.limit_right = int(STRIP_WIDTH)
	camera.limit_top = -170
	camera.limit_bottom = 46
	hud.set_hub_mode()
	hud.update_banked(progress.banked_ore)
	Sfx.warm_up()

func _build_ground() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color8(72, 66, 88)
	backdrop.position = Vector2(-200, -400)
	backdrop.size = Vector2(STRIP_WIDTH + 400.0, 400.0)
	backdrop.z_index = -10
	add_child(backdrop)
	var ground := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(STRIP_WIDTH + 400.0, 40.0)
	shape.shape = rect
	ground.add_child(shape)
	ground.position = Vector2(STRIP_WIDTH / 2.0, 20.0)
	add_child(ground)
	for wall_x in [-8.0, STRIP_WIDTH + 8.0]: # the strip's ends: nothing to fall into past them
		var wall := StaticBody2D.new()
		var wall_shape := CollisionShape2D.new()
		var wall_rect := RectangleShape2D.new()
		wall_rect.size = Vector2(16.0, 400.0)
		wall_shape.shape = wall_rect
		wall.add_child(wall_shape)
		wall.position = Vector2(wall_x, -200.0)
		add_child(wall)
	var floor_art := ColorRect.new()
	floor_art.color = Color8(104, 88, 70)
	floor_art.position = Vector2(-200, 0)
	floor_art.size = Vector2(STRIP_WIDTH + 400.0, 40.0)
	floor_art.z_index = -5
	add_child(floor_art)

func _art(kind: String, parent: Node2D, cell: Vector2i, origin: Vector2i) -> ArtSprite:
	var art := ArtSprite.new()
	art.name = "Art"
	art.kind = kind
	art.cell = cell
	art.origin = origin
	parent.add_child(art)
	return art

func _add_building(kind: String, x: float) -> void:
	var building := HubBuilding.new()
	building.kind = kind
	building.progress = progress
	building.position = Vector2(x, 0.0)
	add_child(building)
	_art(kind, building, Vector2i(64, 64), Vector2i(32, 56))
	buildings.append(building)

func _add_entrance() -> void:
	var entrance := Node2D.new()
	entrance.name = "Entrance"
	entrance.position = Vector2(ENTRANCE_X, 0.0)
	add_child(entrance)
	_art("entrance", entrance, Vector2i(64, 64), Vector2i(32, 56))

func _add_miner(member: Dictionary, x: float) -> void:
	var miner := HubMiner.new()
	miner.member = member
	miner.progress = progress
	miner.position = Vector2(x, MINER_Y)
	add_child(miner)
	var art := _art("player", miner, Vector2i(48, 48), Vector2i(24, 24))
	art.coat = Main.MINER_COLORS.get(member.name, Color(1, 1, 1)).darkened(0.2)
	var lantern := _art("lamp", miner, Vector2i(32, 32), Vector2i(16, 24))
	lantern.name = "Lantern"
	lantern.position = Vector2(5.0, 7.0)
	miners.append(miner)

func _build_board_panel() -> void:
	var layer := CanvasLayer.new()
	var panel := ColorRect.new()
	board_panel = panel
	panel.color = Color(0, 0, 0, 0.8)
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.visible = false # only while the notice board is open
	board_label = Label.new()
	board_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	board_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	board_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	board_label.add_theme_font_size_override("font_size", 16)
	board_label.visible = false
	panel.add_child(board_label)
	layer.add_child(panel)
	add_child(layer)

func _building_of(kind: String) -> HubBuilding:
	for b in buildings:
		if b.kind == kind:
			return b
	return null

func nearest_building() -> HubBuilding:
	var best: HubBuilding = null
	for b in buildings:
		if b.in_range(player.global_position) and (best == null or absf(b.global_position.x - player.global_position.x) < absf(best.global_position.x - player.global_position.x)):
			best = b
	return best

func nearest_miner() -> HubMiner:
	var best: HubMiner = null
	for m in miners:
		if m.in_range(player.global_position) and (best == null or absf(m.global_position.x - player.global_position.x) < absf(best.global_position.x - player.global_position.x)):
			best = m
	return best

func at_entrance() -> bool:
	return absf(player.global_position.x - ENTRANCE_X) < HubBuilding.RANGE

## Buys slot n at the building the player stands beside.
func press_number(n: int) -> bool:
	var building := nearest_building()
	if building == null or not building.buy(n):
		return false
	hud.update_banked(progress.banked_ore)
	return true

## E: a miner joins or leaves the crew, the notice board opens or closes, or the run starts.
func press_use() -> bool:
	var miner := nearest_miner()
	if miner != null:
		return miner.toggle_crew()
	var building := nearest_building()
	if building != null and building.kind == "notice_board":
		building.toggle()
		return true
	if at_entrance():
		enter_mine()
		return true
	return false

func enter_mine() -> void:
	change_scene.call(MAIN_SCENE)

func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or key.echo:
		return
	var n := key.physical_keycode - KEY_1
	if n >= 0 and n < 3:
		press_number(n + 1)
	elif key.physical_keycode == KEY_E:
		press_use()

func _process(_delta: float) -> void:
	var prompts: Array = []
	var building := nearest_building()
	if building != null:
		prompts.append(building.prompt())
	var miner := nearest_miner()
	if miner != null:
		prompts.append(miner.prompt())
	if at_entrance():
		prompts.append("E: go down the mine")
	hud.update_prompts(prompts)
	for b in buildings:
		var art: ArtSprite = b.get_node("Art")
		if art.art != null:
			art.art.pose = b.owned_cue()
	for m in miners:
		m.get_node("Lantern").visible = m.on_crew()
	var board := _building_of("notice_board")
	board_panel.visible = board.board_open
	board_label.visible = board.board_open
	if board.board_open:
		board_label.text = board.board_text()
	hud.update_banked(progress.banked_ore)
