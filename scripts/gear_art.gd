extends CreatureArt
class_name GearArt

## Procedural art for the miner and the base's buildings (milestone 53
## prototype), drawn the same way as CreatureArt. `gear` picks what to draw;
## for the miner, `state` is idle / run / dig / jump / fall. The origin is the
## feet (miner, flag, support, lamp) or the object's centre (beacon, bell).

@export_enum("player", "flag", "beacon", "bell", "support", "lamp", "ladder", "rope", "anchor", "camp", "lift", "outpost", "nest", "heart", "relic", "vault", "lost", "sign", "gas") var gear: String = "player"
@export var length: float = 64.0   # ladder, rope and lift: how tall they stand or hang
@export_enum("idle", "run", "dig", "jump", "fall") var state: String = "idle"

const GPAL := {
	"player": {"k": Color8(16, 12, 10), "skin": Color8(214, 160, 118), "skinsh": Color8(150, 100, 74),
		"coat": Color8(138, 52, 44), "coatsh": Color8(84, 30, 28), "coatlt": Color8(176, 84, 66),
		"pants": Color8(70, 82, 104), "pantssh": Color8(40, 48, 66), "boot": Color8(58, 36, 22),
		"hat": Color8(176, 112, 38), "hatsh": Color8(96, 58, 22), "hatlt": Color8(222, 156, 70),
		"lamp": Color8(255, 238, 160), "wood": Color8(110, 78, 44), "iron": Color8(150, 156, 160), "hair": Color8(82, 58, 40)},
	"wood": {"k": Color8(18, 12, 8), "a": Color8(62, 42, 24), "b": Color8(108, 76, 42), "c": Color8(160, 120, 68)},
	"cloth": {"k": Color8(24, 8, 8), "a": Color8(110, 26, 28), "b": Color8(170, 44, 40), "c": Color8(214, 90, 70)},
	"metal": {"k": Color8(16, 14, 14), "a": Color8(70, 66, 62), "b": Color8(120, 114, 104), "c": Color8(190, 178, 150)},
	"flame": {"k": Color8(60, 20, 8), "a": Color8(220, 100, 30), "b": Color8(250, 170, 60), "c": Color8(255, 240, 170)},
}

func _draw() -> void:
	match gear:
		"player": _draw_player()
		"flag": _draw_flag()
		"beacon": _draw_beacon()
		"bell": _draw_bell()
		"support": _draw_support()
		"lamp": _draw_lamp()
		"ladder": _draw_ladder()
		"rope": _draw_rope()
		"anchor": _draw_anchor()
		"camp": _draw_camp()
		"lift": _draw_lift()
		"outpost": _draw_outpost()
		"nest": _draw_nest()
		"heart": _draw_heart()
		"relic": _draw_relic()
		"vault": _draw_vault()
		"lost": _draw_lost()
		"sign": _draw_sign()
		"gas": _draw_gas()

func _limb(pts: PackedVector2Array, col: Color, hi: Color, w: float = 2.0) -> void:
	draw_polyline(pts, GPAL["player"]["k"], w + 1.0)
	draw_polyline(pts, col, w)
	draw_polyline(pts, hi, 1.0)

# --- the miner ---------------------------------------------------------------

func _draw_player() -> void:
	var p: Dictionary = GPAL["player"]
	var ground := 7.0
	var running := state == "run"
	var digging := state == "dig"
	var air := state == "jump" or state == "fall"
	var cyc := t * 11.0
	var bob := absf(sin(cyc)) * 0.9 if running else 0.0
	var hip := Vector2(0.0, 2.0 - bob)
	# legs: far leg dark, near leg lit
	for far in [true, false]:
		var ph := cyc + (PI if far else 0.0)
		var foot := Vector2(0.0, ground)
		var knee := hip + Vector2(0.6, 2.4)
		if running:
			foot = Vector2(sin(ph) * 3.4, ground - maxf(0.0, -cos(ph)) * 2.2)
			knee = hip + Vector2(sin(ph) * 1.8 + 0.8, 2.2 - maxf(0.0, -cos(ph)) * 1.2)
		elif air:
			var up := state == "jump"
			foot = Vector2(-2.6 if far else 2.8, ground - (3.0 if up else 0.5))
			knee = hip + Vector2(0.4 if far else 1.8, 2.0 if up else 2.8)
		elif digging:
			foot = Vector2(-2.4 if far else 2.4, ground)
			knee = hip + Vector2(-1.4 if far else 1.6, 2.4)
		else:
			foot = Vector2(-1.4 if far else 1.6, ground)
		_limb(PackedVector2Array([hip, knee, foot]), p["pantssh"] if far else p["pants"], p["pants"] if far else p["pants"].lightened(0.2))
		draw_rect(Rect2(foot + Vector2(-1.0, -1.0), Vector2(3.2, 1.8)), p["boot"])
		draw_rect(Rect2(foot + Vector2(-1.0, -1.0), Vector2(3.2, 0.6)), p["k"])
	# the far arm, behind the body
	var shoulder := Vector2(0.4, -2.6 - bob)
	var swing := sin(cyc) * 2.0 if running else 0.0
	var dig_t := sin(t * 8.0) if digging else 0.0
	_limb(PackedVector2Array([shoulder, shoulder + Vector2(-1.2 - swing * 0.5, 2.2), shoulder + Vector2(-1.4 - swing, 4.2)]), p["coatsh"], p["coat"], 1.6)
	# the torso: a patched, dark coat with a belt
	var torso := PackedVector2Array([Vector2(-2.6, -3.6 - bob), Vector2(2.8, -3.6 - bob), Vector2(2.6, 2.4 - bob), Vector2(-2.4, 2.4 - bob)])
	draw_colored_polygon(torso, p["coat"])
	draw_colored_polygon(PackedVector2Array([Vector2(-2.6, -3.6 - bob), Vector2(-0.4, -3.6 - bob), Vector2(-0.8, 2.4 - bob), Vector2(-2.4, 2.4 - bob)]), p["coatsh"])
	draw_colored_polygon(PackedVector2Array([Vector2(0.4, -3.4 - bob), Vector2(2.4, -3.4 - bob), Vector2(2.4, -1.4 - bob), Vector2(0.4, -1.4 - bob)]), p["coatlt"])
	draw_rect(Rect2(Vector2(-2.5, 0.6 - bob), Vector2(5.2, 1.0)), p["k"])
	var tc := torso.duplicate()
	tc.append(torso[0])
	draw_polyline(tc, p["k"], 1.0)
	# head: face, hair, hard hat with a headlamp
	var head := Vector2(0.6, -6.4 - bob + (0.6 if air and state == "fall" else 0.0))
	draw_colored_polygon(_ellipse(head, 2.5, 2.6, 10), p["skin"])
	draw_colored_polygon(_ellipse(head + Vector2(-0.8, 0.8), 1.6, 1.4, 8), p["skinsh"])
	draw_rect(Rect2(head + Vector2(1.0, -0.4), Vector2(1, 1)), p["k"])           # an eye
	draw_polyline(PackedVector2Array(_ellipse(head, 2.5, 2.6, 10) + PackedVector2Array([head + Vector2(2.5, 0.0)])), p["k"], 1.0)
	var hat := PackedVector2Array([head + Vector2(-3.0, -0.6), head + Vector2(-2.4, -2.8), head + Vector2(0.0, -3.7), head + Vector2(2.4, -2.8), head + Vector2(3.4, -0.6)])
	draw_colored_polygon(hat, p["hat"])
	draw_colored_polygon(PackedVector2Array([head + Vector2(-2.4, -2.8), head + Vector2(0.0, -3.7), head + Vector2(0.4, -2.2), head + Vector2(-2.6, -1.6)]), p["hatlt"])
	draw_rect(Rect2(head + Vector2(-2.8, -0.8), Vector2(6.0, 1.0)), p["hatsh"])      # the brim
	draw_rect(Rect2(head + Vector2(2.6, -2.2), Vector2(1.6, 1.4)), p["lamp"])       # the lamp
	_glow(head + Vector2(3.6, -1.5), 2.6, p["lamp"], 0.55 + 0.1 * sin(t * 6.0))
	# the near arm and the pick
	var hand := shoulder + Vector2(2.6, 2.6)
	var pick_ang := 1.0
	if digging:
		hand = shoulder + Vector2(3.6 + dig_t * 1.2, 0.6 + dig_t * 1.4)
		pick_ang = -0.5 + dig_t * 0.7
	elif running:
		hand = shoulder + Vector2(1.6 + swing, 3.4)
		pick_ang = -1.1 + swing * 0.08
	elif air:
		hand = shoulder + Vector2(2.8, -1.4 if state == "jump" else 1.2)
		pick_ang = -0.8
	var elbow := shoulder + (hand - shoulder) * 0.5 + Vector2(-0.4, 1.0)
	_limb(PackedVector2Array([shoulder, elbow, hand]), p["coat"], p["coatlt"], 1.8)
	var dir := Vector2.from_angle(pick_ang)
	draw_line(hand - dir * 2.0, hand + dir * 5.0, p["k"], 2.0)
	draw_line(hand - dir * 2.0, hand + dir * 5.0, p["wood"], 1.0)
	var tip := hand + dir * 5.0
	var perp := Vector2(-dir.y, dir.x)
	draw_line(tip - perp * 2.2, tip + perp * 2.2, p["k"], 2.0)
	draw_line(tip - perp * 2.2, tip + perp * 2.2, p["iron"], 1.0)
	draw_rect(Rect2(hand - Vector2(0.5, 0.5), Vector2(1.4, 1.4)), p["skin"])

# --- the run base ------------------------------------------------------------

func _draw_flag() -> void:
	var w: Dictionary = GPAL["wood"]
	var c: Dictionary = GPAL["cloth"]
	var m: Dictionary = GPAL["metal"]
	# a stone-weighted footing and a splintered pole
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(-3, -2), Vector2(3, -2), Vector2(5, 0)]), m["a"])
	draw_polyline(PackedVector2Array([Vector2(-5, 0), Vector2(-3, -2), Vector2(3, -2), Vector2(5, 0)]), m["k"], 1.0)
	draw_line(Vector2(0, 0), Vector2(0, -26), w["k"], 3.0)
	draw_line(Vector2(0, 0), Vector2(0, -26), w["b"], 1.0)
	draw_line(Vector2(-1, -2), Vector2(-1, -24), w["c"], 1.0)
	# the banner: tattered, rippling in a draught
	var top := PackedVector2Array()
	var bottom := PackedVector2Array()
	var n := 8
	for i in range(n + 1):
		var f := float(i) / n
		var x := 1.0 + f * 11.0
		var wave := sin(t * 4.0 - f * 4.0) * (0.6 + f * 1.6)
		top.append(Vector2(x, -25.0 + wave))
		var rag := (1.5 if i % 3 == 1 else 0.0) + f * 2.5
		bottom.append(Vector2(x, -14.0 + rag + wave))
	var banner := PackedVector2Array()
	banner.append_array(top)
	for i in range(n, -1, -1):
		banner.append(bottom[i])
	draw_colored_polygon(_shift(banner, Vector2(1, 1)), c["a"])
	draw_colored_polygon(banner, c["b"])
	draw_polyline(top, c["c"], 1.0)
	draw_polyline(bottom, c["k"], 1.0)
	draw_rect(Rect2(-1.5, -27.0, 3.0, 2.0), m["c"])

func _draw_beacon() -> void:
	var m: Dictionary = GPAL["metal"]
	var f: Dictionary = GPAL["flame"]
	var flick := 0.85 + 0.15 * sin(t * 13.0) + 0.08 * sin(t * 29.0)
	_glow(Vector2(0, -1), 7.0 * flick, f["b"], 0.9)
	# an iron cage brazier
	draw_colored_polygon(PackedVector2Array([Vector2(-3, 3), Vector2(3, 3), Vector2(2, 0), Vector2(-2, 0)]), m["a"])
	draw_polyline(PackedVector2Array([Vector2(-3, 3), Vector2(-2, 0), Vector2(2, 0), Vector2(3, 3), Vector2(-3, 3)]), m["k"], 1.0)
	var flame := PackedVector2Array([Vector2(-2.2, 0), Vector2(-1.2, -2.0 * flick), Vector2(-0.4, -1.0), Vector2(0.4, -4.5 * flick), Vector2(1.2, -1.2), Vector2(2.2, -2.4 * flick), Vector2(2.4, 0)])
	draw_colored_polygon(flame, f["a"])
	draw_colored_polygon(_shrink(flame, 0.6), f["b"])
	draw_colored_polygon(_shift(_shrink(flame, 0.3), Vector2(0, 0.8)), f["c"])
	draw_line(Vector2(-3, 3), Vector2(3, 3), m["c"], 1.0)

func _draw_bell() -> void:
	var m: Dictionary = GPAL["flame"]
	var w: Dictionary = GPAL["wood"]
	var swing := sin(t * 3.0) * (0.25 + pose * 0.6)
	draw_line(Vector2(-4, -6), Vector2(4, -6), w["k"], 2.0)
	draw_line(Vector2(-4, -6), Vector2(4, -6), w["b"], 1.0)
	var pivot := Vector2(0, -5.5)
	var rot := func(v: Vector2) -> Vector2: return pivot + (v - pivot).rotated(swing)
	var shell := PackedVector2Array()
	for v in [Vector2(-1.2, -4.5), Vector2(1.2, -4.5), Vector2(2.2, -1.5), Vector2(3.4, 2.0), Vector2(-3.4, 2.0), Vector2(-2.2, -1.5)]:
		shell.append(rot.call(v))
	draw_colored_polygon(_shift(shell, Vector2(1, 1)), m["k"])
	draw_colored_polygon(shell, m["a"])
	draw_colored_polygon(_shift(_shrink(shell, 0.5), Vector2(-0.8, -0.6)), m["b"])
	var closed := shell.duplicate()
	closed.append(shell[0])
	draw_polyline(closed, Color8(40, 20, 8), 1.0)
	draw_circle(rot.call(Vector2(0, 2.8)), 1.0, m["c"])           # the clapper

# --- buildings ---------------------------------------------------------------

func _draw_support() -> void:
	var w: Dictionary = GPAL["wood"]
	var m: Dictionary = GPAL["metal"]
	var wear := pose                                    # 0 fresh .. 1 worn out
	var lean := wear * 0.8
	var top := -16.0
	# a heavy prop post wedged floor to ceiling: ceiling plank and foot sill
	draw_rect(Rect2(-6.0, top - 2.0, 12.0, 3.0), w["k"])
	draw_rect(Rect2(-5.5, top - 1.5, 11.0, 2.0), w["b"])
	draw_rect(Rect2(-5.5, top - 1.5, 11.0, 0.8), w["c"])
	draw_rect(Rect2(-5.0, -2.0, 10.0, 2.0), w["k"])
	draw_rect(Rect2(-4.5, -1.5, 9.0, 1.2), w["a"])
	# the post: a rough log, lit from the left, with bark seams and a knot
	var post := PackedVector2Array([Vector2(-3.0 + lean, top + 1.0), Vector2(3.0 + lean, top + 1.0), Vector2(3.4, -2.0), Vector2(-3.4, -2.0)])
	draw_colored_polygon(post, w["b"])
	draw_colored_polygon(PackedVector2Array([Vector2(-3.0 + lean, top + 1.0), Vector2(-0.8 + lean, top + 1.0), Vector2(-1.2, -2.0), Vector2(-3.4, -2.0)]), w["c"])
	draw_colored_polygon(PackedVector2Array([Vector2(1.6 + lean, top + 1.0), Vector2(3.0 + lean, top + 1.0), Vector2(3.4, -2.0), Vector2(2.0, -2.0)]), w["a"])
	var edge := post.duplicate()
	edge.append(post[0])
	draw_polyline(edge, w["k"], 1.0)
	for y in [-12.0, -7.0]:
		draw_line(Vector2(-1.5, y), Vector2(1.0, y + 1.0), w["a"], 1.0)
	draw_rect(Rect2(0.5, -9.5, 1.5, 1.5), w["k"])                                 # a knot
	# iron straps near each end
	for y in [-14.0, -4.0]:
		draw_rect(Rect2(-3.6, y, 7.2, 1.5), m["k"])
		draw_rect(Rect2(-3.2, y + 0.3, 6.4, 0.7), m["b"])
	# angled wedges driving the post tight
	draw_colored_polygon(PackedVector2Array([Vector2(3.6, -2.0), Vector2(6.4, -2.0), Vector2(3.6, -4.2)]), w["c"])
	draw_colored_polygon(PackedVector2Array([Vector2(-3.6, top + 1.0), Vector2(-6.4, top + 1.0), Vector2(-3.6, top + 3.2)]), w["c"])
	# wear: cracks and splinters appear as it fails
	if wear > 0.35:
		draw_line(Vector2(-0.5, -13.0), Vector2(0.5, -8.0), w["k"], 1.0)
	if wear > 0.7:
		draw_line(Vector2(1.0, -9.0), Vector2(-0.5, -4.5), w["k"], 1.0)
		draw_line(Vector2(3.4, -10.0), Vector2(5.0, -9.0), w["c"], 1.0)

func _draw_lamp() -> void:
	var m: Dictionary = GPAL["metal"]
	var f: Dictionary = GPAL["flame"]
	var flick := 0.85 + 0.15 * sin(t * 11.0) + 0.06 * sin(t * 23.0)
	draw_line(Vector2(0, 0), Vector2(0, -9), m["k"], 3.0)
	draw_line(Vector2(0, 0), Vector2(0, -9), m["a"], 1.0)
	draw_rect(Rect2(-2.5, -1.0, 5.0, 1.0), m["k"])
	_glow(Vector2(0, -11), 7.0 * flick, f["b"], 0.8)
	draw_rect(Rect2(-2.5, -15.0, 5.0, 6.0), m["k"])                              # the lantern cage
	draw_rect(Rect2(-1.5, -14.0, 3.0, 4.0), f["a"])
	draw_rect(Rect2(-1.0, -13.0 + (1.0 - flick), 2.0, 2.5), f["c"])
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -15), Vector2(3, -15), Vector2(0, -17.5)]), m["a"])

# --- climbing tools -----------------------------------------------------------

## A ladder standing up from its feet; `pose` is wear: rungs snap and rails crack.
func _draw_ladder() -> void:
	var w: Dictionary = GPAL["wood"]
	var top := -length
	for x in [-4.0, 3.0]:
		draw_rect(Rect2(x - 1.5, top, 3.0, length), w["k"])
		draw_rect(Rect2(x - 1.0, top, 2.0, length), w["b"])
		draw_rect(Rect2(x - 1.0, top, 0.8, length), w["c"])
	var n := int(length / 8.0)
	for i in range(n):
		var y := -3.0 - i * 8.0
		var snapped := pose > 0.5 and (i * 7 + 3) % 5 == 0
		var x1 := -4.0
		var x2 := 3.0
		if snapped:
			x2 = -0.5                                    # a broken rung, one stub left
		draw_line(Vector2(x1, y), Vector2(x2, y), w["k"], 3.0)
		draw_line(Vector2(x1, y - 0.5), Vector2(x2, y - 0.5), w["c"], 1.0)
		draw_line(Vector2(x1, y + 0.5), Vector2(x2, y + 0.5), w["a"], 1.0)
	if pose > 0.3:
		for i in range(int(pose * 3.0) + 1):
			var y := top + 6.0 + i * 13.0
			draw_line(Vector2(-4.0, y), Vector2(-3.0, y + 4.0), w["k"], 1.0)

## A rope hanging from its top: twisted strands, a knot at the top, a frayed end.
func _draw_rope() -> void:
	var r: Dictionary = {"k": Color8(26, 18, 10), "a": Color8(90, 70, 40), "b": Color8(146, 116, 70), "c": Color8(196, 166, 110)}
	var sway := sin(t * 1.6) * 1.2
	var prev_a := Vector2.ZERO
	var prev_b := Vector2.ZERO
	var steps := int(length / 2.0)
	for i in range(steps + 1):
		var y := i * 2.0
		var f := float(i) / steps
		var cx := sway * f * f
		var twist := sin(i * 0.9) * 1.3
		var a := Vector2(cx + twist, y)
		var b := Vector2(cx - twist, y)
		if i > 0:
			draw_line(prev_b, b, r["k"], 2.0)
			draw_line(prev_a, a, r["k"], 2.0)
			draw_line(prev_b, b, r["a"], 1.0)
			draw_line(prev_a, a, r["b"] if sin(i * 0.9) > 0 else r["c"], 1.0)
		prev_a = a
		prev_b = b
	draw_rect(Rect2(-2.5, 0.0, 5.0, 3.0), r["k"])                                  # the knot
	draw_rect(Rect2(-2.0, 0.5, 4.0, 2.0), r["b"])
	var end := Vector2(sway, length)
	for d in [-2.0, -0.8, 0.8, 2.0]:
		draw_line(end, end + Vector2(d + sway * 0.3, 2.5 + absf(d) * 0.4), r["c"], 1.0)  # frayed end
	if pose > 0.5:
		var mid := Vector2(sway * 0.25, length * 0.45)
		draw_rect(Rect2(mid + Vector2(-1.0, -1.0), Vector2(2.0, 2.0)), r["k"])    # a worn thin spot

## A hammered iron ring set into rock above the spike.
func _draw_anchor() -> void:
	var m: Dictionary = GPAL["metal"]
	draw_colored_polygon(PackedVector2Array([Vector2(-1.5, -1.0), Vector2(1.5, -1.0), Vector2(0.5, 5.0), Vector2(-0.5, 5.0)]), m["a"])   # the spike
	draw_rect(Rect2(-3.0, -2.5, 6.0, 2.0), m["k"])
	draw_rect(Rect2(-2.5, -2.0, 5.0, 1.0), m["b"])
	var ring := _ellipse(Vector2(0, -6.0), 3.2, 3.6, 12)
	var closed := ring.duplicate()
	closed.append(ring[0])
	draw_polyline(closed, m["k"], 3.0)
	draw_polyline(closed, m["b"], 1.5)
	draw_arc(Vector2(0, -6.0), 3.2, PI, PI * 1.5, 6, m["c"], 1.0)
	var glint := fmod(t, 3.0)
	if glint < 0.25:
		draw_rect(Rect2(-2.0, -9.0, 1.0, 1.0), Color.WHITE)

# --- events ---------------------------------------------------------------------

## A patched tent and a small fire.
func _draw_camp() -> void:
	var c: Dictionary = {"k": Color8(20, 16, 10), "a": Color8(76, 66, 46), "b": Color8(120, 106, 74), "c": Color8(168, 150, 104)}
	var tent := PackedVector2Array([Vector2(-15, 0), Vector2(-6, -13), Vector2(3, 0)])
	draw_colored_polygon(_shift(tent, Vector2(1, 0)), c["a"])
	draw_colored_polygon(tent, c["b"])
	draw_colored_polygon(PackedVector2Array([Vector2(-15, 0), Vector2(-6, -13), Vector2(-7, 0)]), c["c"])
	draw_colored_polygon(PackedVector2Array([Vector2(-9.5, 0), Vector2(-6, -7), Vector2(-3, 0)]), c["k"])   # the opening
	draw_polyline(tent + PackedVector2Array([tent[0]]), c["k"], 1.0)
	draw_rect(Rect2(-11.5, -4.5, 3.0, 2.5), c["a"])                                  # a patch
	draw_line(Vector2(-6, -13), Vector2(-6, -16), c["k"], 1.0)
	draw_line(Vector2(5.5, -0.5), Vector2(12, -0.5), GPAL["wood"]["k"], 2.0)          # a log
	draw_line(Vector2(5.5, -1.0), Vector2(12, -1.0), GPAL["wood"]["b"], 1.0)
	var flick := 0.85 + 0.15 * sin(t * 12.0) + 0.07 * sin(t * 27.0)
	var f: Dictionary = GPAL["flame"]
	_glow(Vector2(8.5, -3.0), 8.0 * flick, f["b"], 0.8)
	var flame := PackedVector2Array([Vector2(6.0, -1.5), Vector2(6.8, -4.0 * flick), Vector2(7.8, -2.5), Vector2(8.8, -7.0 * flick), Vector2(9.8, -3.0), Vector2(10.8, -4.5 * flick), Vector2(11.2, -1.5)])
	draw_colored_polygon(flame, f["a"])
	draw_colored_polygon(_shrink(flame, 0.6), f["b"])
	draw_colored_polygon(_shift(_shrink(flame, 0.3), Vector2(0, 1.0)), f["c"])

## A mine lift: guide rails, a chain and a caged platform; `pose` slides the cage.
func _draw_lift() -> void:
	var m: Dictionary = GPAL["metal"]
	var w: Dictionary = GPAL["wood"]
	var top := -length
	for x in [-8.0, 7.0]:
		draw_rect(Rect2(x - 1.5, top, 3.0, length), m["k"])
		draw_rect(Rect2(x - 1.0, top, 2.0, length), m["a"])
		draw_rect(Rect2(x - 1.0, top, 0.8, length), m["b"])
	for i in range(int(length / 16.0)):
		draw_line(Vector2(-8, -4.0 - i * 16.0), Vector2(7, -12.0 - i * 16.0), m["a"], 1.0)     # lattice
	var cage_y := -4.0 - pose * (length - 24.0)
	draw_line(Vector2(0, top), Vector2(0, cage_y - 12.0), m["k"], 2.0)
	for i in range(int((cage_y - 12.0 - top) / 3.0)):
		draw_rect(Rect2(-1.0, top + i * 3.0, 2.0, 1.5), m["b"])                                # chain links
	draw_rect(Rect2(-7.0, cage_y - 12.0, 14.0, 12.0), m["k"])                                  # the cage
	draw_rect(Rect2(-6.0, cage_y - 11.0, 12.0, 10.0), Color8(34, 30, 28))
	for x in [-4.0, -1.0, 2.0, 5.0]:
		draw_line(Vector2(x, cage_y - 11.0), Vector2(x, cage_y - 1.0), m["b"], 1.0)
	draw_rect(Rect2(-8.0, cage_y, 16.0, 2.0), w["k"])                                          # the floor planks
	draw_rect(Rect2(-7.5, cage_y, 15.0, 1.0), w["b"])
	draw_rect(Rect2(-1.5, cage_y - 14.0, 3.0, 3.0), m["c"])

## A survivors' lean-to: a patched tarp roof on poles, supply crates, a hanging lantern.
func _draw_outpost() -> void:
	var w: Dictionary = GPAL["wood"]
	var f: Dictionary = GPAL["flame"]
	var tarp: Dictionary = {"k": Color8(18, 22, 20), "a": Color8(50, 66, 56), "b": Color8(82, 104, 86), "c": Color8(122, 148, 120)}
	for x in [-14.0, 12.0]:
		draw_line(Vector2(x, 0), Vector2(x, -15), w["k"], 3.0)
		draw_line(Vector2(x, 0), Vector2(x, -15), w["b"], 1.0)
	var roof := PackedVector2Array([Vector2(-17, -13), Vector2(15, -16), Vector2(16, -10), Vector2(10, -12), Vector2(3, -9.5), Vector2(-4, -11.5), Vector2(-12, -9), Vector2(-17, -10)])
	draw_colored_polygon(_shift(roof, Vector2(0, 1.5)), tarp["a"])
	draw_colored_polygon(roof, tarp["b"])
	draw_polyline(PackedVector2Array([Vector2(-17, -13), Vector2(15, -16)]), tarp["c"], 1.0)
	draw_rect(Rect2(-6.0, -14.5, 4.0, 3.0), tarp["a"])                                  # a patch
	# crates and a sack
	draw_rect(Rect2(-12.0, -6.0, 8.0, 6.0), w["k"])
	draw_rect(Rect2(-11.0, -5.0, 6.0, 4.0), w["b"])
	draw_line(Vector2(-11, -5), Vector2(-5, -1), w["a"], 1.0)
	draw_rect(Rect2(-3.0, -4.0, 6.0, 4.0), w["k"])
	draw_rect(Rect2(-2.0, -3.0, 4.0, 2.0), w["c"])
	draw_colored_polygon(_ellipse(Vector2(6.5, -3.0), 3.2, 3.0, 8), GPAL["metal"]["a"])      # a sack
	draw_polyline(_ellipse(Vector2(6.5, -3.0), 3.2, 3.0, 8), w["k"], 1.0)
	# the lantern
	var flick := 0.88 + 0.12 * sin(t * 10.0)
	draw_line(Vector2(0, -12), Vector2(0, -9), w["k"], 1.0)
	_glow(Vector2(0, -7.5), 8.0 * flick, f["b"], 0.75)
	draw_rect(Rect2(-1.5, -9.0, 3.0, 3.0), f["a"])
	draw_rect(Rect2(-0.5, -8.0, 1.0, 1.5), f["c"])

## A clutch of leathery eggs in dark webbing; the eggs pulse faintly.
func _draw_nest() -> void:
	var web: Dictionary = {"k": Color8(8, 8, 10), "a": Color8(26, 24, 28), "b": Color8(50, 44, 48), "c": Color8(110, 100, 96)}
	var egg: Dictionary = {"k": Color8(30, 40, 20), "a": Color8(78, 98, 52), "b": Color8(128, 152, 82), "c": Color8(190, 206, 140)}
	var bed := PackedVector2Array([Vector2(-15, 0), Vector2(-12, -3), Vector2(-4, -4), Vector2(5, -3.5), Vector2(13, -3), Vector2(16, 0)])
	draw_colored_polygon(bed, web["a"])
	draw_polyline(bed, web["k"], 1.0)
	for x in [-11.0, -6.0, 0.0, 7.0, 12.0]:
		draw_line(Vector2(x, -3.0), Vector2(x + 1.5, -6.5), web["b"], 1.0)                 # strands
	var eggs := [Vector2(-8, -5), Vector2(-1, -6), Vector2(6, -5), Vector2(0, -11)]
	for i in range(eggs.size()):
		var pulse := 1.0 + 0.06 * sin(t * 2.5 + i)
		var e: Vector2 = eggs[i]
		var pts := _ellipse(e, 3.2 * pulse, 4.0 * pulse, 12)
		_blob(pts, egg)
	draw_line(Vector2(9, -2), Vector2(15, -5), web["c"], 1.0)                                # a bone
	draw_rect(Rect2(14.5, -6.0, 1.5, 1.5), web["c"])

## The Heart: a dark crystal organ, throbbing, veined with ember light, on a cracked plinth.
func _draw_heart() -> void:
	var m: Dictionary = GPAL["metal"]
	var beat := pow(maxf(0.0, sin(t * 3.0)), 3.0)
	var rate := 1.0 + beat * 0.12
	_glow(Vector2(0, -9), 12.0 * rate, Color8(230, 50, 30), 0.7 + beat * 0.3)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 0), Vector2(-4, -3), Vector2(4, -3), Vector2(6, 0)]), m["a"])
	draw_polyline(PackedVector2Array([Vector2(-6, 0), Vector2(-4, -3), Vector2(4, -3), Vector2(6, 0)]), m["k"], 1.0)
	draw_line(Vector2(2, -3), Vector2(1, 0), m["k"], 1.0)
	var heart := PackedVector2Array([Vector2(0, -4), Vector2(-3.0 * rate, -6), Vector2(-5.0 * rate, -10), Vector2(-3.0 * rate, -14), Vector2(0, -12.5), Vector2(3.0 * rate, -14), Vector2(5.0 * rate, -10), Vector2(3.0 * rate, -6)])
	var body: Dictionary = {"k": Color8(30, 6, 8), "a": Color8(98, 14, 20), "b": Color8(170, 28, 30), "c": Color8(246, 110, 80)}
	_blob(heart, body)
	draw_line(Vector2(-1, -12), Vector2(-3, -8), body["k"], 1.0)                              # veins
	draw_line(Vector2(1.5, -12), Vector2(2.5, -7), body["k"], 1.0)
	if beat > 0.5:
		draw_rect(Rect2(-2.5, -11.5, 1.0, 1.0), Color.WHITE)

## The relic: a pale crystal floating over an iron stand, bobbing and glinting.
func _draw_relic() -> void:
	var m: Dictionary = GPAL["metal"]
	var bob := sin(t * 2.0) * 1.0
	var cr: Dictionary = {"k": Color8(16, 36, 54), "a": Color8(52, 100, 150), "b": Color8(120, 184, 232), "c": Color8(226, 246, 255)}
	_glow(Vector2(0, -10 + bob), 11.0, cr["b"], 0.7)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(-3, -3), Vector2(3, -3), Vector2(5, 0)]), m["a"])
	draw_polyline(PackedVector2Array([Vector2(-5, 0), Vector2(-3, -3), Vector2(3, -3), Vector2(5, 0)]), m["k"], 1.0)
	draw_rect(Rect2(-3.0, -4.0, 6.0, 1.0), m["b"])
	var gem := PackedVector2Array([Vector2(0, -16 + bob), Vector2(-3.5, -10 + bob), Vector2(0, -5 + bob), Vector2(3.5, -10 + bob)])
	_blob(gem, cr)
	draw_line(Vector2(0, -16 + bob), Vector2(0, -5 + bob), cr["a"], 1.0)
	var gl := fmod(t, 2.5)
	if gl < 0.3:
		draw_line(Vector2(-1.5, -12 + bob), Vector2(1.5, -12 + bob), Color.WHITE, 1.0)
		draw_line(Vector2(0, -14 + bob), Vector2(0, -10 + bob), Color.WHITE, 1.0)

## The vault door: riveted iron slab, a gold band and a bolt; `pose` cracks it.
func _draw_vault() -> void:
	var m: Dictionary = GPAL["metal"]
	draw_rect(Rect2(-9.0, -32.0, 18.0, 32.0), m["k"])
	draw_rect(Rect2(-8.0, -31.0, 16.0, 30.0), m["a"])
	draw_rect(Rect2(-8.0, -31.0, 6.0, 30.0), m["b"])
	for y in [-29.0, -3.0]:
		for x in [-6.0, 5.0]:
			draw_rect(Rect2(x, y, 1.5, 1.5), m["c"])                                     # rivets
	draw_line(Vector2(0, -31), Vector2(0, -1), m["k"], 1.0)                              # the seam
	var gold: Dictionary = {"k": Color8(60, 40, 10), "a": Color8(150, 106, 30), "b": Color8(220, 170, 60), "c": Color8(252, 226, 140)}
	draw_rect(Rect2(-8.0, -17.0, 16.0, 5.0), gold["k"])
	draw_rect(Rect2(-8.0, -16.0, 16.0, 3.0), gold["b"])
	draw_rect(Rect2(-8.0, -16.0, 16.0, 1.0), gold["c"])
	draw_circle(Vector2(0, -14.5), 2.2, gold["k"])
	draw_circle(Vector2(0, -14.5), 1.4, gold["a"])
	if pose > 0.0:
		draw_line(Vector2(-6, -28), Vector2(-2, -20), m["k"], 1.0)
		draw_line(Vector2(-2, -20), Vector2(-5, -14), m["k"], 1.0)
		draw_line(Vector2(4, -8), Vector2(6, -3), m["k"], 1.0)

## A lost miner: slumped against the rock, one arm raised, headlamp guttering.
func _draw_lost() -> void:
	var p: Dictionary = GPAL["player"]
	var flick := 0.5 + 0.5 * sin(t * 9.0) * sin(t * 2.3)
	var bob := sin(t * 2.0) * 0.4
	var wave := sin(t * 5.0)
	# legs bent, sitting
	for x in [-1.0, 2.0]:
		_limb(PackedVector2Array([Vector2(0, 2), Vector2(x + 2.5, 3.5), Vector2(x + 3.5, 7)]), p["pants"], p["pants"].lightened(0.2))
		draw_rect(Rect2(x + 2.5, 6.0, 3.2, 1.6), p["boot"])
	draw_colored_polygon(PackedVector2Array([Vector2(-3, -3 + bob), Vector2(2.4, -3.4 + bob), Vector2(2.4, 3.0), Vector2(-3.2, 3.0)]), p["coatsh"])
	draw_colored_polygon(PackedVector2Array([Vector2(-1, -3 + bob), Vector2(2.4, -3.4 + bob), Vector2(2.4, 1.0), Vector2(-1, 1.0)]), p["coat"])
	draw_polyline(PackedVector2Array([Vector2(-3, -3 + bob), Vector2(2.4, -3.4 + bob), Vector2(2.4, 3.0), Vector2(-3.2, 3.0), Vector2(-3, -3 + bob)]), p["k"], 1.0)
	_limb(PackedVector2Array([Vector2(1, -2.4 + bob), Vector2(3.5, -5.5 + bob), Vector2(5.0 + wave * 1.2, -9.0 + bob)]), p["coat"], p["coatlt"], 1.6)
	draw_rect(Rect2(4.2 + wave * 1.2, -10.0 + bob, 1.6, 1.6), p["skin"])
	var head := Vector2(-0.4, -6.4 + bob)
	draw_colored_polygon(_ellipse(head, 2.4, 2.5, 10), p["skin"])
	draw_colored_polygon(_ellipse(head + Vector2(-0.8, 0.8), 1.5, 1.3, 8), p["skinsh"])
	draw_rect(Rect2(head + Vector2(0.8, -0.2), Vector2(1, 1)), p["k"])
	draw_colored_polygon(PackedVector2Array([head + Vector2(-3.0, -0.4), head + Vector2(-2.2, -2.7), head + Vector2(0.2, -3.5), head + Vector2(2.4, -2.5), head + Vector2(3.0, -0.4)]), p["hatsh"].lightened(0.1))
	draw_rect(Rect2(head + Vector2(2.2, -2.0), Vector2(1.4, 1.2)), p["lamp"] * Color(1, 1, 1, 0.4 + 0.5 * flick))
	_glow(head + Vector2(3.0, -1.4), 3.0, p["lamp"], 0.45 * flick)

## A scrap of a lost miner's shirt with a faint glow; `pose` is the veteran brightness.
func _draw_sign() -> void:
	var glow := Color8(120, 230, 160)
	var pulse := 0.6 + 0.4 * sin(t * 2.4)
	_glow(Vector2(0, -2), 6.0 + pose * 4.0, glow, (0.4 + pose * 0.5) * pulse)
	var scrap := PackedVector2Array([Vector2(-4, 0), Vector2(-3, -3), Vector2(0, -2.5), Vector2(3, -4), Vector2(4.5, -1), Vector2(2, 0.5), Vector2(-1, 0.2)])
	var cloth: Dictionary = {"k": Color8(24, 8, 8), "a": Color8(110, 26, 28), "b": Color8(170, 44, 40), "c": Color8(214, 90, 70)}
	_blob(scrap, cloth)
	draw_line(Vector2(-4, 0), Vector2(-5, 1), cloth["a"], 1.0)                              # a loose thread
	draw_line(Vector2(4.5, -1), Vector2(6, -0.5), cloth["a"], 1.0)

## Gas: slow, overlapping, translucent puffs that drift and fade with `pose` (0 thick .. 1 thin).
func _draw_gas() -> void:
	var fade := 1.0 - pose * 0.8
	for i in range(7):
		var a := t * 0.5 + i * 1.7
		var c := Vector2(cos(a) * (6.0 + i), sin(a * 0.8) * (4.0 + i * 0.5) - 2.0)
		var r := 6.0 + sin(t + i) * 1.5
		draw_colored_polygon(_ellipse(c, r, r * 0.8, 12), Color(0.42, 0.62, 0.28, 0.22 * fade))
		draw_colored_polygon(_ellipse(c + Vector2(-1, -1), r * 0.55, r * 0.45, 10), Color(0.62, 0.8, 0.4, 0.16 * fade))
