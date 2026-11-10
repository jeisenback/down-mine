extends Node2D
class_name CreatureArt

## Procedural creature art (milestone 53 prototype): the Stalker, Burrower,
## Snuffer, fuel flask and ore cluster drawn at runtime from polygons, lines
## and circles, and animated by code instead of by sprite frames. Draw it in
## a small low-resolution viewport (one unit = one pixel, no antialiasing) and
## it stays pixelated. The origin is the creature's centre of mass; it faces
## +x. `t` is the animation clock (seconds); `pose` is a 0..1 extra (a lunge,
## or how open the mandibles are).

@export_enum("stalker", "burrower", "snuffer", "fuel", "ore") var kind: String = "stalker"
@export var animate: bool = true
var t: float = 0.0
var pose: float = 0.0
## 0 for the ordinary creature, 1 for its deep variant (the second Stalker has four eyes).
var variant: int = 0
## When true this art draws only its unlit glow (eyes and the like) through _draw_glow, for ArtSprite's
## glow layer: pieces that must show in total darkness, drawn on their own unshaded sprite.
var glow_only: bool = false

## The Stalker's eyes: ice blue, red on a strike. Drawn unlit (the glow layer), so they show in the dark.
const STALKER_EYE := Color8(150, 215, 255)
const STALKER_STRIKE_EYE := Color8(245, 74, 56)

const PAL := {
	"stalker": {"k": Color8(12, 16, 24), "a": Color8(30, 44, 58), "b": Color8(52, 76, 96), "c": Color8(104, 140, 158),
		"e": Color8(245, 74, 56), "m": Color8(226, 230, 216), "v": Color8(6, 8, 12)},
	"burrower": {"k": Color8(20, 12, 6), "a": Color8(66, 44, 20), "b": Color8(120, 82, 34), "c": Color8(188, 140, 68),
		"o": Color8(240, 110, 40), "m": Color8(228, 214, 178)},
	"snuffer": {"k": Color8(18, 34, 46), "a": Color8(46, 74, 92), "b": Color8(88, 134, 152), "c": Color8(190, 226, 236),
		"e": Color8(214, 66, 204), "g": Color8(76, 112, 128)},
	"fuel": {"k": Color8(14, 22, 38), "a": Color8(40, 70, 120), "b": Color8(70, 130, 210), "c": Color8(150, 205, 250),
		"w": Color8(236, 246, 255), "n": Color8(110, 72, 36), "N": Color8(160, 112, 60)},
	"ore": {"k": Color8(18, 14, 10), "a": Color8(48, 42, 36), "b": Color8(84, 76, 64), "c": Color8(132, 120, 100),
		"y": Color8(232, 192, 80), "Y": Color8(255, 238, 150)},
}

## The art redraws this many times a second: it reads as hand-animated, and
## rebuilding every polygon each frame costs far more than it is worth.
const REDRAW_FPS := 20.0
var _since_redraw: float = 1.0

func _process(delta: float) -> void:
	if animate:
		t += delta
	_since_redraw += delta
	if _since_redraw >= 1.0 / REDRAW_FPS:
		_since_redraw = 0.0
		queue_redraw()

func _draw() -> void:
	if glow_only:
		_draw_glow()
		return
	match kind:
		"stalker": _draw_stalker()
		"burrower": _draw_burrower()
		"snuffer": _draw_snuffer()
		"fuel": _draw_fuel()
		"ore": _draw_ore()

## The unlit pieces of this creature, drawn alone when glow_only is set: the Stalker's eyes. Other
## creatures draw nothing here.
func _draw_glow() -> void:
	match kind:
		"stalker": _draw_stalker_glow()

# --- helpers ---------------------------------------------------------------

func _ellipse(c: Vector2, rx: float, ry: float, n: int = 14) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _shift(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out

func _shrink(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= float(pts.size())
	var out := PackedVector2Array()
	for p in pts:
		out.append(c + (p - c) * k)
	return out

## A lit blob: shadow offset behind it, the body, a highlight toward the
## light (up and left), and a dark outline.
func _blob(pts: PackedVector2Array, pal: Dictionary, outline: bool = true) -> void:
	draw_colored_polygon(_shift(pts, Vector2(1, 1)), pal["a"])
	draw_colored_polygon(pts, pal["b"])
	draw_colored_polygon(_shift(_shrink(pts, 0.55), Vector2(-1.0, -1.2)), pal["c"])
	if outline:
		var closed := pts.duplicate()
		closed.append(pts[0])
		draw_polyline(closed, pal["k"], 1.0)

func _glow(c: Vector2, r: float, col: Color, strength: float) -> void:
	for i in range(3):
		var k := 1.0 - i / 3.0
		draw_circle(c, r * (0.45 + 0.55 * k), Color(col.r, col.g, col.b, strength * (0.12 + 0.1 * (1.0 - k))))

# --- the Stalker: a big dark spider ------------------------------------------

## The Stalker: a blue eight-legged spider. Its eyes are not here: they are drawn unlit by
## _draw_stalker_glow, so in the dark you see two cold eyes and nothing else. The deep Stalker
## (variant 1) stands taller and has four.
func _draw_stalker() -> void:
	var p: Dictionary = PAL["stalker"]
	var lunge := pose * 3.0
	var bob := sin(t * 3.0) * 0.5
	var ground := 7.0
	var rise := -2.0 * variant                              # the deep Stalker stands taller
	var thorax := Vector2(2.0 + lunge, -2.0 + bob + rise)
	var abdomen := Vector2(-4.5 + lunge * 0.4, -1.5 + bob * 0.6 + rise)
	# eight legs: long, high-kneed, splayed front and back; far side darker
	for i in range(8):
		var far := i % 2 == 0
		var slot := i / 2                                   # 0 front .. 3 rear
		var dir := 1.0 if slot < 2 else -1.0
		var reach: float = [10.0, 7.0, 8.0, 11.0][slot] + (1.0 if far else 0.0)
		var ph := t * 4.0 + (PI if far else 0.0) + slot * 1.6
		var hip := thorax + Vector2(-slot * 2.2 + 1.5, 1.0)
		var knee := hip + Vector2(dir * (reach * 0.5), -7.0 + sin(ph) * 0.8)
		if slot == 0:
			knee.y -= 1.5 + pose * 3.0                       # front legs reach up and out
		var foot := Vector2(hip.x + dir * reach + (lunge if slot == 0 else 0.0), ground - maxf(0.0, cos(ph)) * 1.5 - (1.0 if far else 0.0))
		if slot == 0:
			foot.y -= pose * 5.0
		var leg := PackedVector2Array([hip, knee, foot])
		draw_polyline(leg, p["k"], 2.0)
		draw_polyline(leg, p["a"] if far else p["c"], 1.0)
	# round abdomen with a mark, smaller thorax
	_blob(_ellipse(abdomen, 5.2, 4.4, 16), p)
	draw_colored_polygon(PackedVector2Array([abdomen + Vector2(-2.6, -1.0), abdomen + Vector2(0.0, -2.6), abdomen + Vector2(0.6, 0.6)]), p["e"].darkened(0.35))
	_blob(_ellipse(thorax, 3.4, 2.9, 12), p)
	# the fangs (the eyes are on the glow layer, drawn unlit: see _draw_stalker_glow)
	var fang := 0.4 + 0.4 * sin(t * 5.0) + pose
	for side in [-1.0, 1.0]:
		draw_line(thorax + Vector2(3.0, 0.8 + side * 0.9), thorax + Vector2(4.2, 2.6 + side * 0.3 * fang), p["m"], 1.0)

## The thorax centre, shared by the body and its eyes so the eyes stay on the face.
func _stalker_thorax() -> Vector2:
	var rise := -2.0 * variant
	return Vector2(2.0 + pose * 3.0, -2.0 + sin(t * 3.0) * 0.5 + rise)

## The Stalker's eyes, drawn alone on the glow layer: two (four for the deep one) cold ice blue eyes,
## round and slow to blink; on a strike they narrow to red slits.
func _draw_stalker_glow() -> void:
	var striking := pose >= 0.5
	if not striking and fposmod(t, 4.2) > 4.05:
		return # a blink
	var face := Vector2(roundf(_stalker_thorax().x), roundf(_stalker_thorax().y))
	var colour := STALKER_STRIKE_EYE if striking else STALKER_EYE
	var size := Vector2(3, 1) if striking else Vector2(2, 2)
	var rows := [-3.0, 0.0] if variant == 1 else [-2.0]
	for row in rows:
		for dx in [-1.0, 3.0]:
			draw_rect(Rect2(face + Vector2(dx, row), size), colour)

# --- the Burrower: a low, many-legged crawler with mandibles --------------

## The Burrower (M92): a long, low, segmented armoured worm, a fat head tapering back through five
## segments that ripple front to back, and at the head a ring of pale teeth turning like a drill bit
## round a hot orange mouth. The ring spins fast and flares open on a strike (`pose`). A few specks of
## rubble trail off the tail.
func _draw_burrower() -> void:
	var p: Dictionary = PAL["burrower"]
	var lunge := roundf(pose * 2.0)
	var ground := 4.0
	# the segments, tail first so the head is drawn last and over them
	var centres := [-16.0, -11.5, -7.0, -2.5, 2.0]
	var radii := [Vector2(2.2, 1.9), Vector2(2.7, 2.3), Vector2(3.0, 2.7), Vector2(3.3, 3.0), Vector2(3.6, 3.3)]
	for i in range(centres.size()):
		var ripple := roundf(sin(t * 4.0 - i * 0.9) * 1.0)
		var r: Vector2 = radii[i]
		var c := Vector2(centres[i], ground - r.y + ripple)
		_blob(_ellipse(c, r.x, r.y, 12), p)
		draw_line(c + Vector2(-r.x + 0.5, -r.y * 0.6), c + Vector2(-r.x + 0.5, r.y * 0.6), p["a"], 1.0) # the plate seam
	# the head: the biggest segment, low and forward
	var head := Vector2(7.0 + lunge, ground - 3.8 + roundf(sin(t * 4.0 - 4.5)))
	_blob(_ellipse(head, 4.4, 3.8, 14), p)
	# the mouth: a hot orange opening in its face, wider on a strike, ringed with turning teeth
	var mouth := head + Vector2(3.0, 0.0)
	var opening := 2.5 + pose * 1.5
	draw_rect(Rect2(mouth + Vector2(-1, -opening), Vector2(3, opening * 2.0 + 1.0)), p["k"])
	draw_rect(Rect2(mouth + Vector2(0, -opening + 1.0), Vector2(2, opening * 2.0 - 1.0)), p["o"])
	var spin := t * (6.0 + pose * 18.0)
	var ring := 3.8 + pose * 1.5
	for i in range(8):
		var angle := TAU * i / 8.0 + spin
		var near := cos(angle) > 0.0
		var tooth := mouth + Vector2(1.0 + cos(angle) * 1.0, roundf(sin(angle) * ring) - 1.0)
		draw_rect(Rect2(tooth, Vector2(2, 2) if near else Vector2(2, 1)), p["m"] if near else p["c"])
	# rubble kicked off the tail
	for i in range(4):
		var along := fposmod(t * 0.9 + i * 0.37, 1.0)
		draw_rect(Rect2(Vector2(-18.0 - roundf(along * 4.0), ground - 1.0 - roundf(fposmod(t * 1.3 + i * 0.21, 1.0) * 4.0)), Vector2(1, 1)), p["b"])

# --- the Snuffer: a light-eating jellyfish -------------------------------------

func _draw_snuffer() -> void:
	var p: Dictionary = PAL["snuffer"]
	var pulse := sin(t * 3.0)
	var bell_c := Vector2(0, -5.0 + pulse * 0.6)
	var rx := 6.5 - pulse * 0.7
	var ry := 5.2 + pulse * 0.9
	# a faint cold halo: it drinks light, so it glows from within, never brightly
	_glow(bell_c, 11.0, p["c"], 0.5)
	# tendrils first, trailing behind the bell
	for i in range(5):
		var x0 := lerpf(-4.5, 4.5, i / 4.0)
		var pts := PackedVector2Array()
		for j in range(9):
			var fj := float(j) / 8.0
			pts.append(Vector2(x0 + sin(t * 3.0 - j * 0.8 + i * 1.3) * (0.6 + 2.2 * fj), bell_c.y + ry * 0.7 + j * 1.5))
		draw_polyline(pts, p["a"], 1.0)
		for j in range(0, 9, 2):
			draw_circle(pts[j], 0.5, Color(p["g"].r, p["g"].g, p["g"].b, 1.0 - j / 10.0))
	# the bell, with a scalloped skirt
	var bell := PackedVector2Array()
	for i in range(13):
		var a := PI + PI * i / 12.0
		bell.append(bell_c + Vector2(cos(a) * rx, sin(a) * ry))
	for i in range(6):
		var x := rx - i * rx * 2.0 / 5.0
		bell.append(bell_c + Vector2(x, 1.2 + (1.4 if i % 2 == 0 else 0.0) + pulse * 0.4))
	_blob(bell, p)
	# glowing flecks drift inside it
	for i in range(4):
		var a2 := t * 0.9 + i * 1.7
		var fp := bell_c + Vector2(cos(a2) * rx * 0.55, sin(a2 * 1.3) * ry * 0.4 - 1.0)
		draw_rect(Rect2(fp, Vector2(1, 1)), Color(p["c"].r, p["c"].g, p["c"].b, 0.5 + 0.5 * sin(t * 4.0 + i)))
	# one slit eye
	var eye := bell_c + Vector2(0, 0.5)
	_glow(eye, 3.5, p["e"], 0.8)
	draw_rect(Rect2(eye + Vector2(-1.5, 0), Vector2(3, 1)), p["e"])

# --- fuel: a glass flask of glowing oil ----------------------------------------

func _draw_fuel() -> void:
	var p: Dictionary = PAL["fuel"]
	var bob := sin(t * 2.0) * 0.8
	var c := Vector2(0, bob)
	_glow(c + Vector2(0, 2), 10.0, p["c"], 0.5 + 0.2 * sin(t * 3.0))
	var belly := _ellipse(c + Vector2(0, 2.5), 5.0, 4.6, 14)
	var glass := PackedVector2Array()
	glass.append(c + Vector2(-1.8, -6.0))
	glass.append(c + Vector2(1.8, -6.0))
	glass.append(c + Vector2(1.8, -2.0))
	for pt in belly:
		glass.append(pt)
	glass.append(c + Vector2(-1.8, -2.0))
	draw_colored_polygon(glass, p["a"])
	# the fuel, with a wobbling surface
	var level := 1.0 + sin(t * 4.0) * 0.4
	var fuel := PackedVector2Array([c + Vector2(-4.4, level), c + Vector2(4.4, 1.0 - level * 0.0 + sin(t * 4.0 + 1.0) * 0.4)])
	for pt in belly:
		if pt.y > c.y + 1.2:
			fuel.append(pt)
	draw_colored_polygon(fuel, p["b"])
	draw_line(c + Vector2(-3.4, 1.6 + level * 0.1), c + Vector2(3.4, 1.6), p["c"], 1.0)
	draw_rect(Rect2(c + Vector2(-3.2, 3.2), Vector2(1.5, 2)), p["w"])                  # the glint
	var outline := glass.duplicate()
	outline.append(glass[0])
	draw_polyline(outline, p["k"], 1.0)
	draw_rect(Rect2(c + Vector2(-1.8, -8.0), Vector2(3.6, 2.5)), p["n"])                 # the cork
	draw_rect(Rect2(c + Vector2(-1.8, -8.0), Vector2(3.6, 1.0)), p["N"])
	# a bubble rising through the neck
	var bt := fmod(t * 4.0, 8.0)
	draw_circle(c + Vector2(0.0, 3.0 - bt), 0.6, p["w"])

# --- ore: three shards on a slab, laced with gold --------------------------------

func _draw_ore() -> void:
	var p: Dictionary = PAL["ore"]
	var slab := PackedVector2Array([Vector2(-6.5, 3), Vector2(-5.5, 5.5), Vector2(6, 5.5), Vector2(7, 3), Vector2(6, 2), Vector2(-5.5, 2)])
	_blob(slab, p)
	var shards := [
		PackedVector2Array([Vector2(-5, 3), Vector2(-5.2, -1.5), Vector2(-3.4, -4), Vector2(-1.8, -1), Vector2(-1.5, 3)]),
		PackedVector2Array([Vector2(-1.5, 3), Vector2(-1.2, -4), Vector2(0.4, -8), Vector2(2.2, -4), Vector2(2.4, 3)]),
		PackedVector2Array([Vector2(2.4, 3), Vector2(2.6, -2), Vector2(4.4, -4), Vector2(6, -1.4), Vector2(5.4, 3)]),
	]
	for s in shards:
		_blob(s, p)
	for g in [Vector2(-3.2, -1), Vector2(0.4, -3), Vector2(0.8, 0.4), Vector2(4.2, -0.8), Vector2(-1, 3.8), Vector2(3.6, 4)]:
		draw_rect(Rect2(g, Vector2(1, 1)), p["y"])
	# a glint that crosses the tallest shard now and then
	var tw := fmod(t * 0.9, 3.0)
	if tw < 0.35:
		var k := 1.0 - tw / 0.35
		var tip := Vector2(0.4, -7.0)
		draw_line(tip + Vector2(-2, 0), tip + Vector2(2, 0), Color(p["Y"].r, p["Y"].g, p["Y"].b, k), 1.0)
		draw_line(tip + Vector2(0, -2), tip + Vector2(0, 2), Color(p["Y"].r, p["Y"].g, p["Y"].b, k), 1.0)
