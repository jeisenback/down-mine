extends CreatureArt
class_name GearArt

## Procedural art for the miner and the base's buildings (milestone 53
## prototype), drawn the same way as CreatureArt. `gear` picks what to draw;
## for the miner, `state` is idle / run / dig / jump / fall. The origin is the
## feet (miner, flag, support, lamp) or the object's centre (beacon, bell).

@export_enum("player", "flag", "beacon", "bell", "support", "lamp") var gear: String = "player"
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
	# two posts, a cap beam, and cross braces; knots and splits for grit
	for x in [-6.0, 5.0]:
		draw_rect(Rect2(x - 1.5, -9.0, 3.0, 9.0), w["k"])
		draw_rect(Rect2(x - 1.0, -9.0, 2.0, 9.0), w["b"])
		draw_rect(Rect2(x - 1.0, -9.0, 0.8, 9.0), w["c"])
		draw_rect(Rect2(x, -5.0, 1.0, 1.0), w["a"])
	draw_rect(Rect2(-8.5, -11.0, 17.0, 3.0), w["k"])
	draw_rect(Rect2(-8.0, -10.5, 16.0, 2.0), w["b"])
	draw_rect(Rect2(-8.0, -10.5, 16.0, 0.8), w["c"])
	for sgn in [-1.0, 1.0]:
		var a := Vector2(sgn * 5.0, -8.0)
		var b := Vector2(sgn * 2.0, -10.0)
		draw_line(a, Vector2(sgn * 3.0, -4.0), w["k"], 2.0)
		draw_line(a, Vector2(sgn * 3.0, -4.0), w["a"], 1.0)
	draw_line(Vector2(-4.0, -9.0), Vector2(-4.0, -9.0) + Vector2(0.0, 0.0), w["k"], 1.0)

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
