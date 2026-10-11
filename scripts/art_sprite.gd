extends Node2D
class_name ArtSprite

## Procedural art (CreatureArt or GearArt) drawn in a small transparent
## viewport, one unit per world pixel, and shown through a nearest-filtered
## sprite: the art stays on the pixel grid under the camera's zoom and is lit
## like any other sprite. `kind` names what to draw. The art's origin sits at
## this node's origin; `flip_h` mirrors it about that origin. The viewport
## stops rendering while the art is off screen.

const CREATURE_KINDS := ["stalker", "burrower", "snuffer", "fuel", "ore"]
const GEAR_KINDS := ["player", "flag", "beacon", "bell", "support", "lamp", "ladder", "rope", "anchor",
	"camp", "lift", "outpost", "nest", "heart", "relic", "vault", "lost", "sign", "gas",
	"bench", "lantern_post", "muffling_post", "rope_rack", "palisade", "rampart",
	"lamp_shop", "smithy", "bunkhouse", "notice_board", "entrance"]

@export var kind: String = ""
@export var cell: Vector2i = Vector2i(48, 48)
@export var origin: Vector2i = Vector2i(24, 24)
@export var length: float = 64.0
## The miner's coat, or a sign's cloth, colour. Live: set it any time.
@export var coat: Color = GearArt.DEFAULT_COAT:
	set(value):
		coat = value
		if art is GearArt:
			art.coat = value

# Art phases come from their own generator: drawing must never consume the
# global one, which the mine's seeded generation and spawns share.
static var _phase_rng := RandomNumberGenerator.new()

# Starts false: the notifier reports an exit only after an entry, so art
# that begins off screen must begin asleep and be woken by screen_entered.
var _on_screen: bool = false
var _notifier: VisibleOnScreenNotifier2D
var art # CreatureArt or GearArt (a CreatureArt subclass)
var viewport: SubViewport
var sprite: Sprite2D
var flip_h: bool = false:
	set(value):
		flip_h = value
		_place_sprite()

func _ready() -> void:
	if kind in CREATURE_KINDS:
		art = CreatureArt.new()
		art.kind = kind
	elif kind in GEAR_KINDS:
		var gear := GearArt.new()
		gear.gear = kind
		gear.length = length
		gear.coat = coat
		art = gear
	else:
		return
	art.t = _phase_rng.randf() * 10.0
	viewport = SubViewport.new()
	viewport.size = cell
	viewport.transparent_bg = true
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	art.draw.connect(_on_art_drawn)
	art.position = Vector2(origin)
	viewport.add_child(art)
	add_child(viewport)
	art.set_process(false) # entering the tree switched it on; it wakes on screen_entered
	sprite = Sprite2D.new()
	sprite.texture = viewport.get_texture()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	_place_sprite()
	_notifier = VisibleOnScreenNotifier2D.new()
	_notifier.name = "Notifier"
	_notifier.screen_entered.connect(_on_screen_entered)
	_notifier.screen_exited.connect(_on_screen_exited)
	add_child(_notifier)
	_place_sprite()

func _place_sprite() -> void:
	if sprite == null:
		return
	var centre := Vector2(cell) / 2.0 - Vector2(origin)
	sprite.position = Vector2(-centre.x if flip_h else centre.x, centre.y)
	sprite.scale.x = -1.0 if flip_h else 1.0
	if _notifier != null:
		_notifier.rect = Rect2(sprite.position - Vector2(cell) / 2.0, Vector2(cell))

## The viewport renders once per redraw of the art, not every frame.
func _on_art_drawn() -> void:
	if _on_screen:
		viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func _on_screen_entered() -> void:
	_on_screen = true
	art.set_process(true)
	art.queue_redraw()

func _on_screen_exited() -> void:
	_on_screen = false
	art.set_process(false)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
