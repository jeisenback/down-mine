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

const PAL := {
	"stalker": {"k": Color8(12, 16, 24), "a": Color8(30, 44, 58), "b": Color8(52, 76, 96), "c": Color8(104, 140, 158),
		"e": Color8(245, 74, 56), "m": Color8(226, 230, 216), "v": Color8(6, 8, 12)},
	"burrower": {"k": Color8(20, 12, 6), "a": Color8(66, 44, 20), "b": Color8(120, 82, 34), "c": Color8(188, 140, 68),
		"e": Color8(240, 70, 46), "m": Color8(228, 214, 178)},
	"snuffer": {"k": Color8(18, 34, 46), "a": Color8(46, 74, 92), "b": Color8(88, 134, 152), "c": Color8(190, 226, 236),
		"e": Color8(214, 66, 204), "g": Color8(76, 112, 128)},
	"fuel": {"k": Color8(14, 22, 38), "a": Color8(40, 70, 120), "b": Color8(70, 130, 210), "c": Color8(150, 205, 250),
		"w": Color8(236, 246, 255), "n": Color8(110, 72, 36), "N": Color8(160, 112, 60)},
	"ore": {"k": Color8(18, 14, 10), "a": Color8(48, 42, 36), "b": Color8(84, 76, 64), "c": Color8(132, 120, 100),
		"y": Color8(232, 192, 80), "Y": Color8(255, 238, 150)},
}

func _process(delta: float) -> void:
	if animate:
		t += delta
	queue_redraw()

func _draw() -> void:
	match kind:
		"stalker": _draw_stalker()
		"burrower": _draw_burrower()
		"snuffer": _draw_snuffer()
		"fuel": _draw_fuel()
		"ore": _draw_ore()

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

# --- the Stalker: a hooded wraith -------------------------------------------

func _draw_stalker() -> void:
	var p: Dictionary = PAL["stalker"]
	var sway := sin(t * 2.2) * 0.9
	var bob := sin(t * 2.2 + 1.0) * 0.8
	var lean := pose * 3.0
	var hood_c := Vector2(sway * 0.5 + lean, -9.0 + bob)
	# the cloak: shoulders to a tattered, rippling hem
	var cloak := PackedVector2Array()
	cloak.append(hood_c + Vector2(-4.0, 3.0))
	cloak.append(hood_c + Vector2(4.0, 3.0))
	var n := 9
	for i in range(n + 1):
		var fx := float(i) / n
		var x := lerpf(7.5, -7.5, fx) + sway * 0.4
		var tatter := (3.0 if i % 2 == 0 else 0.0) + (2.0 if i % 3 == 0 else 0.0)
		cloak.append(Vector2(x, 4.0 + tatter * 0.6 + sin(t * 5.0 + i * 1.3) * 1.0))
	# arms: two-segment, swinging; one reaches out in a lunge
	var arm_l := PackedVector2Array([hood_c + Vector2(-4, 4), Vector2(-8.0 + sway, -2.0 + bob), Vector2(-9.0 + sin(t * 3.0) * 1.5, 3.0)])
	var arm_r := PackedVector2Array([hood_c + Vector2(4, 4), Vector2(8.0 - sway, -3.0 + bob), Vector2(9.0 + pose * 5.0, 2.0 - pose * 7.0 + sin(t * 3.0 + 1.0) * 1.0)])
	for arm in [arm_l, arm_r]:
		draw_polyline(arm, p["k"], 3.0)
		draw_polyline(arm, p["a"], 1.5)
		var hand: Vector2 = arm[2]
		for d in [-1.5, 0.0, 1.5]:
			draw_line(hand, hand + Vector2(d, 2.5), p["m"], 1.0)         # claws
	_blob(cloak, p)
	# the hood
	var hood := _ellipse(hood_c, 4.6, 5.2)
	_blob(hood, p)
	# the dark under the hood, burning eyes, a ragged mouth
	draw_colored_polygon(_ellipse(hood_c + Vector2(0.8, 0.8), 2.8, 3.1, 10), p["v"])
	var eye_l := hood_c + Vector2(-0.8, 0.2)
	var eye_r := hood_c + Vector2(2.4, 0.2)
	var flare := 0.8 + 0.2 * sin(t * 7.0)
	_glow(eye_l, 3.0, p["e"], flare)
	_glow(eye_r, 3.0, p["e"], flare)
	draw_rect(Rect2(eye_l - Vector2(0.5, 0.5), Vector2(1, 1)), p["e"])
	draw_rect(Rect2(eye_r - Vector2(0.5, 0.5), Vector2(1, 1)), p["e"])
	for i in range(3):
		draw_rect(Rect2(hood_c + Vector2(-0.5 + i * 1.3, 2.3), Vector2(1, 1)), p["m"])  # teeth

# --- the Burrower: an armoured, many-legged worm -----------------------------

func _draw_burrower() -> void:
	var p: Dictionary = PAL["burrower"]
	var open := 0.5 + 0.5 * sin(t * 6.0) if pose == 0.0 else pose
	var seg_count := 7
	var spacing := 4.2
	# tail first, head last
	for i in range(seg_count, 0, -1):
		var c := Vector2(-i * spacing, sin(t * 6.0 - i * 0.9) * 1.8 * min(1.0, i / 2.0))
		var r := lerpf(5.0, 2.6, float(i) / seg_count)
		# legs, alternating
		for side in [-1.0, 1.0]:
			var swing := sin(t * 10.0 + i * 1.7) * 1.4
			draw_line(c + Vector2(0, r * 0.7 * side), c + Vector2(swing, (r + 2.2) * side), p["k"], 1.0)
		_blob(_ellipse(c, r + 0.8, r, 12), p)
		draw_line(c + Vector2(-r * 0.7, -r * 0.6), c + Vector2(-r * 0.7, r * 0.6), p["a"], 1.0)  # a ring groove
	# the head
	var hc := Vector2(2.0, 0.0)
	_blob(_ellipse(hc, 6.2, 5.2, 14), p)
	draw_colored_polygon(PackedVector2Array([hc + Vector2(-2, -4.2), hc + Vector2(3, -4.2), hc + Vector2(4, -2.5), hc + Vector2(-2, -2.5)]), p["c"])
	var eye := hc + Vector2(2.0, -0.5)
	_glow(eye, 2.6, p["e"], 0.9)
	draw_rect(Rect2(eye - Vector2(0.5, 0.5), Vector2(1.5, 1)), p["e"])
	# mandibles, opening and closing
	for side in [-1.0, 1.0]:
		var base := hc + Vector2(5.0, 2.4 * side)
		var tip := base + Vector2(3.0, (2.0 + 2.2 * open) * side * -1.0)
		var mid := base + Vector2(2.0, 1.2 * side * (1.0 + open))
		draw_polyline(PackedVector2Array([base, mid, tip]), p["k"], 2.0)
		draw_polyline(PackedVector2Array([base, mid, tip]), p["m"], 1.0)

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
