extends Area2D
class_name FuelPickup

@export var fuel_amount: float = 25.0

## A small twinkling light of the pickup's own, so a flask shows in the dark beyond the lantern's
## reach. It is a plain PointLight2D, not a MineLight: it spares no tunnel and holds off no dark.
## Its phase comes from where the pickup stands, and nothing here draws a random number.
const GLINT_RADIUS := 14.0 # px
const GLINT_ENERGY := 0.6
const GLINT_COLOR := Color8(150, 205, 250)
static var _glint_texture: GradientTexture2D

var _glint: PointLight2D
var _glint_time := 0.0

# Mines build pickups during seeded generation, and each used to draw one global
# random number (a twinkle phase). The draw stays so every seed keeps building
# the same mine it did before the art was redrawn (milestone 53).
var _seed_stream_draw: float = randf()

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_glint_time = fmod(position.x * 0.37 + position.y * 0.11, TAU)
	_glint = PointLight2D.new()
	_glint.name = "Glint"
	_glint.texture = _glow_texture()
	_glint.texture_scale = GLINT_RADIUS / (_glint.texture.get_width() * 0.5)
	_glint.color = GLINT_COLOR
	_glint.energy = glint_energy(_glint_time)
	add_child(_glint)
	# Twinkle only while on screen (the notifier reports an exit only after an entry, so start asleep).
	var notifier := VisibleOnScreenNotifier2D.new()
	notifier.rect = Rect2(-GLINT_RADIUS, -GLINT_RADIUS, GLINT_RADIUS * 2.0, GLINT_RADIUS * 2.0)
	notifier.screen_entered.connect(set_process.bind(true))
	notifier.screen_exited.connect(set_process.bind(false))
	add_child(notifier)
	set_process(false)

func _process(delta: float) -> void:
	_glint_time += delta
	_glint.energy = glint_energy(_glint_time)

## The glint's energy at a moment of its twinkle: always positive, never above GLINT_ENERGY.
static func glint_energy(moment: float) -> float:
	return GLINT_ENERGY * (0.55 + 0.45 * sin(moment * 2.5))

## One small radial falloff shared by every pickup.
static func _glow_texture() -> GradientTexture2D:
	if _glint_texture == null:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(1, 1, 1, 0))
		_glint_texture = GradientTexture2D.new()
		_glint_texture.gradient = gradient
		_glint_texture.fill = GradientTexture2D.FILL_RADIAL
		_glint_texture.fill_from = Vector2(0.5, 0.5)
		_glint_texture.fill_to = Vector2(1.0, 0.5)
		_glint_texture.width = 32
		_glint_texture.height = 32
	return _glint_texture

func _on_body_entered(body: Node) -> void:
	if body is Player:
		(body as Player).light.add_fuel(fuel_amount)
		Sfx.play("fuel")
		queue_free()
