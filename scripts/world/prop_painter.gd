class_name PropPainter
extends RefCounted
## Disegno da codice dei prop della mappa (Mappa 1), sostituibile con sprite.
## Un prop è un Dictionary {t: tipo, x, y, s: scala, v: variante, flip, ...extra}; (x, y) sono i piedi.
## Si chiama dentro il _draw() di un CanvasItem: PropPainter.draw(self, prop).

const GREEN := Color(0.27, 0.46, 0.25)
const GREEN_L := Color(0.40, 0.60, 0.34)
const GREEN_D := Color(0.17, 0.32, 0.19)
const WOOD := Color(0.42, 0.28, 0.16)
const WOOD_D := Color(0.27, 0.17, 0.10)
const WOOD_L := Color(0.62, 0.45, 0.26)
const ROCK := Color(0.50, 0.44, 0.40)
const ROCK_L := Color(0.70, 0.64, 0.57)
const ROCK_D := Color(0.33, 0.28, 0.26)
const BONE := Color(0.90, 0.86, 0.76)
const STRAW := Color(0.82, 0.68, 0.32)
const GOLD := Color(0.86, 0.70, 0.30)
const ROOFS := [Color(0.47, 0.28, 0.18), Color(0.38, 0.37, 0.36), Color(0.56, 0.39, 0.22), Color(0.30, 0.36, 0.30)]
const HORSES := [Color(0.45, 0.28, 0.16), Color(0.16, 0.13, 0.12), Color(0.72, 0.66, 0.55), Color(0.60, 0.42, 0.22)]
const FLOWERS := [Color(0.95, 0.80, 0.20), Color(0.78, 0.35, 0.60), Color(0.90, 0.35, 0.25), Color(0.85, 0.85, 0.95)]


static func draw(ci: CanvasItem, p: Dictionary) -> void:
	var pos := Vector2(float(p["x"]), float(p["y"]))
	var s := float(p.get("s", 1.0))
	var f := -1.0 if bool(p.get("flip", false)) else 1.0
	var v := int(p.get("v", 0))
	match str(p["t"]):
		"saguaro": _saguaro(ci, pos, s, f, v)
		"barrel_cactus": _barrel_cactus(ci, pos, s, v)
		"nopal": _nopal(ci, pos, s, f)
		"agave": _agave(ci, pos, s)
		"bush": _bush(ci, pos, s, f, v)
		"tuft_dry": _tuft(ci, pos, s, f, Color(0.64, 0.56, 0.28), 7)
		"grass": _tuft(ci, pos, s, f, Color(0.36, 0.52, 0.24), 9)
		"flowers": _flowers(ci, pos, s, v)
		"cottonwood": _cottonwood(ci, pos, s, f, v)
		"dead_tree": _dead_tree(ci, pos, s, f)
		"juniper": _juniper(ci, pos, s)
		"rock_s": _rocks(ci, pos, s, v, 3)
		"rock_m": _rocks(ci, pos, s * 1.7, v, 2)
		"boulder": _rocks(ci, pos, float(p.get("r", 24.0)) / 12.0, v, 1)
		"butte": _butte(ci, pos, p)
		"bones": _bones(ci, pos, s, f)
		"wheel": _wheel(ci, pos, s)
		"tumbleweed": _tumbleweed(ci, pos, s, v)
		"log": _log(ci, pos, s, float(p.get("a", 0.0)))
		"reeds": _reeds(ci, pos, s, v)
		"palm": _palm(ci, pos, s, f, v)
		"house": _house(ci, pos, float(p["w"]), float(p["h"]), v, str(p.get("style", "house")))
		"tent": _tent(ci, pos, s, f, v)
		"campfire": _campfire(ci, pos, s)
		"fence_rect": _fence_rect(ci, pos, float(p["w"]), float(p["h"]), float(p.get("gap", 0.0)))
		"fence_line": _fence_seg(ci, pos, Vector2(float(p["x2"]), float(p["y2"])))
		"rail": _rail(ci, pos, float(p.get("w", 70.0)))
		"windmill": _windmill(ci, pos, s, v)
		"tank": _tank(ci, pos, s)
		"haystack": _haystack(ci, pos, s)
		"trough": _trough(ci, pos, s)
		"wagon": _wagon(ci, pos, s, float(p.get("a", 0.0)), bool(p.get("broken", false)))
		"horse": _horse(ci, pos, s, f, v)
		"crate": _crate(ci, pos, s)
		"barrel": _barrel(ci, pos, s)
		"cross": _cross(ci, pos, s)
		"headstone": _headstone(ci, pos, s, v)
		"well": _well(ci, pos, s)
		"signpost": _signpost(ci, pos, str(p.get("text", "")), float(p.get("w", 68.0)))
		"lamp": _lamp(ci, pos, s)
		"outhouse": _outhouse(ci, pos, s)
		"woodpile": _woodpile(ci, pos, s)
		"ruin": _ruin(ci, pos, float(p["w"]), float(p["h"]), v)
		"bedroll": _bedroll(ci, pos, s, f)
		"bridge": _bridge(ci, pos, float(p["a"]), float(p["len"]), float(p["w"]))
		"stones": _stones(ci, pos, float(p["a"]), float(p["len"]), v)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------------------ utilità

static func _rnd(v: int, i: int) -> float:
	return fposmod(sin(float(v) * 12.9898 + float(i) * 78.233) * 43758.5453, 1.0)


static func _tf(ci: CanvasItem, pos: Vector2, s: float, f: float = 1.0, rot: float = 0.0) -> void:
	ci.draw_set_transform(pos, rot, Vector2(s * f, s))


static func _shadow(ci: CanvasItem, pos: Vector2, rx: float, ry: float, a: float = 0.22) -> void:
	ci.draw_set_transform(pos, 0.0, Vector2(1.0, ry / rx))
	ci.draw_circle(Vector2.ZERO, rx, Color(0.0, 0.0, 0.0, a))


static func _blob(v: int, r: float, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := float(i) / float(n) * TAU
		var rr := r * (0.72 + 0.28 * _rnd(v, i))
		pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.8))
	return pts


static func _poly(ci: CanvasItem, pts: PackedVector2Array, col: Color) -> void:
	if pts.size() >= 3:
		ci.draw_colored_polygon(pts, col)


# --------------------------------------------------------------------- vegetazione

static func _saguaro(ci: CanvasItem, pos: Vector2, s: float, f: float, v: int) -> void:
	_shadow(ci, pos + Vector2(7.0, 2.0) * s, 16.0 * s, 6.0 * s)
	_tf(ci, pos, s, f)
	var arms := v % 3
	if arms >= 1:
		ci.draw_rect(Rect2(-18, -30, 14, 6), GREEN)
		ci.draw_rect(Rect2(-18, -42, 6, 18), GREEN)
		ci.draw_circle(Vector2(-15, -42), 3.0, GREEN)
		ci.draw_rect(Rect2(-18, -42, 2, 18), GREEN_L)
	if arms >= 2:
		ci.draw_rect(Rect2(4, -22, 14, 6), GREEN)
		ci.draw_rect(Rect2(12, -34, 6, 18), GREEN)
		ci.draw_circle(Vector2(15, -34), 3.0, GREEN)
		ci.draw_rect(Rect2(16, -34, 2, 18), GREEN_D)
	ci.draw_rect(Rect2(-5.5, -48, 11, 48), GREEN)
	ci.draw_circle(Vector2(0, -48), 5.5, GREEN)
	ci.draw_rect(Rect2(-5.5, -48, 3, 48), GREEN_L)
	ci.draw_rect(Rect2(3, -48, 2.5, 48), GREEN_D)
	ci.draw_line(Vector2(0, -46), Vector2(0, -2), GREEN_D, 1.0)


static func _barrel_cactus(ci: CanvasItem, pos: Vector2, s: float, v: int) -> void:
	_shadow(ci, pos + Vector2(4.0, 1.0) * s, 11.0 * s, 4.0 * s)
	_tf(ci, pos, s)
	ci.draw_circle(Vector2(0, -8), 9.0, GREEN)
	ci.draw_circle(Vector2(-3, -10), 5.0, GREEN_L)
	for k in range(-2, 3):
		ci.draw_line(Vector2(float(k) * 3.0, -15.0), Vector2(float(k) * 4.5, -1.0), GREEN_D, 1.0)
	ci.draw_circle(Vector2(0, -16), 2.8, FLOWERS[v % 3])


static func _nopal(ci: CanvasItem, pos: Vector2, s: float, f: float) -> void:
	_shadow(ci, pos + Vector2(4.0, 2.0) * s, 15.0 * s, 5.0 * s)
	var pads := [[0.0, -10.0, 0.0, 1.0], [-10.0, -20.0, -0.5, 0.8], [11.0, -19.0, 0.6, 0.85], [2.0, -29.0, 0.1, 0.7]]
	for d in pads:
		ci.draw_set_transform(pos + Vector2(float(d[0]) * f, float(d[1])) * s, float(d[2]) * f, Vector2(s * float(d[3]) * 0.8, s * float(d[3]) * 1.05))
		ci.draw_circle(Vector2.ZERO, 9.0, Color(0.28, 0.50, 0.36))
		ci.draw_circle(Vector2(-2, -2), 5.0, Color(0.36, 0.60, 0.42))
		ci.draw_circle(Vector2(0, -8), 1.6, Color(0.80, 0.25, 0.25))


static func _agave(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(3.0, 1.0) * s, 15.0 * s, 5.0 * s)
	_tf(ci, pos, s)
	for k in 11:
		var a := float(k) / 11.0 * TAU
		var dir := Vector2(cos(a), sin(a) * 0.6)
		var tip := Vector2(0, -6) + dir * 17.0
		var perp := Vector2(-dir.y, dir.x) * 2.6
		_poly(ci, PackedVector2Array([Vector2(0, -6) + perp, tip, Vector2(0, -6) - perp]),
				Color(0.34, 0.56, 0.50) if k % 2 == 0 else Color(0.40, 0.62, 0.54))
	ci.draw_circle(Vector2(0, -6), 3.0, Color(0.26, 0.44, 0.40))


static func _bush(ci: CanvasItem, pos: Vector2, s: float, f: float, v: int) -> void:
	_shadow(ci, pos + Vector2(3.0, 2.0) * s, 14.0 * s, 5.0 * s)
	_tf(ci, pos, s, f)
	var col := Color(0.50, 0.54, 0.37) if v % 4 != 0 else Color(0.62, 0.52, 0.30)
	ci.draw_circle(Vector2(-8, -6), 8.0, col.darkened(0.12))
	ci.draw_circle(Vector2(7, -5), 7.0, col.darkened(0.12))
	ci.draw_circle(Vector2(0, -11), 8.5, col)
	ci.draw_circle(Vector2(-3, -14), 4.0, col.lightened(0.18))
	ci.draw_circle(Vector2(-9, -8), 3.0, col.lightened(0.10))
	if v % 3 == 0:
		ci.draw_circle(Vector2(4, -12), 1.5, FLOWERS[0])
		ci.draw_circle(Vector2(-6, -7), 1.5, FLOWERS[0])


static func _tuft(ci: CanvasItem, pos: Vector2, s: float, f: float, col: Color, blades: int) -> void:
	_tf(ci, pos, s, f)
	for k in blades:
		var x := (float(k) - float(blades) * 0.5) * 1.8
		var lean := (float(k) - float(blades) * 0.5) * 0.9
		ci.draw_line(Vector2(x, 0), Vector2(x + lean, -8.0 - float((k * 5) % 5)), col, 1.4)


static func _flowers(ci: CanvasItem, pos: Vector2, s: float, v: int) -> void:
	_tf(ci, pos, s)
	for k in 6:
		var x := (_rnd(v, k) - 0.5) * 22.0
		var y := (_rnd(v, k + 9) - 0.5) * 8.0
		ci.draw_line(Vector2(x, y), Vector2(x, y - 6.0), GREEN, 1.0)
		ci.draw_circle(Vector2(x, y - 7.0), 1.9, FLOWERS[(v + k) % 4])


static func _cottonwood(ci: CanvasItem, pos: Vector2, s: float, f: float, v: int) -> void:
	_shadow(ci, pos + Vector2(14.0, 4.0) * s, 34.0 * s, 12.0 * s, 0.26)
	_tf(ci, pos, s, f)
	ci.draw_rect(Rect2(-4, -28, 8, 28), WOOD)
	ci.draw_rect(Rect2(-4, -28, 3, 28), WOOD_L)
	var base := Color(0.27, 0.43, 0.19)
	if v % 5 == 0:
		base = Color(0.62, 0.52, 0.20)
	ci.draw_circle(Vector2(0, -46), 26.0, base.darkened(0.15))
	ci.draw_circle(Vector2(-15, -38), 18.0, base.darkened(0.08))
	ci.draw_circle(Vector2(15, -38), 18.0, base.darkened(0.08))
	ci.draw_circle(Vector2(0, -58), 19.0, base)
	ci.draw_circle(Vector2(-8, -57), 10.0, base.lightened(0.15))
	ci.draw_circle(Vector2(10, -48), 6.0, base.lightened(0.08))


static func _dead_tree(ci: CanvasItem, pos: Vector2, s: float, f: float) -> void:
	_shadow(ci, pos + Vector2(8.0, 2.0) * s, 16.0 * s, 5.0 * s)
	_tf(ci, pos, s, f)
	var c := Color(0.46, 0.39, 0.33)
	ci.draw_line(Vector2(0, 0), Vector2(0, -36), c.darkened(0.2), 5.0)
	ci.draw_line(Vector2(-1, 0), Vector2(-1, -36), c, 2.0)
	ci.draw_line(Vector2(0, -20), Vector2(-14, -34), c, 2.6)
	ci.draw_line(Vector2(-14, -34), Vector2(-18, -44), c, 2.0)
	ci.draw_line(Vector2(0, -27), Vector2(12, -40), c, 2.6)
	ci.draw_line(Vector2(12, -40), Vector2(10, -50), c, 2.0)
	ci.draw_line(Vector2(0, -36), Vector2(-3, -48), c, 2.0)


static func _juniper(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(10.0, 3.0) * s, 22.0 * s, 8.0 * s, 0.26)
	_tf(ci, pos, s)
	ci.draw_rect(Rect2(-3, -14, 6, 14), WOOD_D)
	var cols := [Color(0.16, 0.30, 0.20), Color(0.20, 0.36, 0.24), Color(0.25, 0.42, 0.28)]
	var tiers := [[-18.0, -12.0, -40.0], [-14.0, -28.0, -54.0], [-10.0, -44.0, -68.0]]
	for i in 3:
		var t: Array = tiers[i]
		var w := float(t[0])
		_poly(ci, PackedVector2Array([Vector2(w, float(t[1])), Vector2(-w, float(t[1])), Vector2(0, float(t[2]))]), cols[i])
		_poly(ci, PackedVector2Array([Vector2(0, float(t[1])), Vector2(-w, float(t[1])), Vector2(0, float(t[2]))]), Color(1, 1, 1, 0.07))


static func _reeds(ci: CanvasItem, pos: Vector2, s: float, v: int) -> void:
	_tf(ci, pos, s)
	for k in 7:
		var x := (_rnd(v, k) - 0.5) * 16.0
		var hgt := 16.0 + _rnd(v, k + 4) * 14.0
		var lean := (_rnd(v, k + 8) - 0.5) * 6.0
		ci.draw_line(Vector2(x, 0), Vector2(x + lean, -hgt), Color(0.45, 0.56, 0.28), 1.4)
		if k % 3 == 0:
			ci.draw_line(Vector2(x + lean, -hgt), Vector2(x + lean, -hgt - 5.0), Color(0.40, 0.26, 0.14), 2.6)


static func _palm(ci: CanvasItem, pos: Vector2, s: float, f: float, v: int) -> void:
	_shadow(ci, pos + Vector2(14.0, 3.0) * s, 24.0 * s, 8.0 * s)
	_tf(ci, pos, s, f)
	var trunk := PackedVector2Array([Vector2(0, 0), Vector2(2, -14), Vector2(5, -28), Vector2(4, -42)])
	ci.draw_polyline(trunk, WOOD, 5.0)
	ci.draw_polyline(trunk, WOOD_L, 1.5)
	var top := Vector2(4, -42)
	for k in 8:
		var a := float(k) / 8.0 * TAU + float(v) * 0.4
		var dir := Vector2(cos(a), sin(a) * 0.55)
		var tip := top + dir * 28.0 + Vector2(0, 8)
		var perp := Vector2(-dir.y, dir.x) * 4.0
		_poly(ci, PackedVector2Array([top, top + dir * 14.0 + perp - Vector2(0, 4), tip, top + dir * 14.0 - perp - Vector2(0, 4)]),
				Color(0.26, 0.46, 0.24) if k % 2 == 0 else Color(0.32, 0.54, 0.28))
	ci.draw_circle(top, 3.0, WOOD_D)


# ------------------------------------------------------------------------- rocce

static func _rocks(ci: CanvasItem, pos: Vector2, s: float, v: int, n: int) -> void:
	_shadow(ci, pos + Vector2(5.0, 3.0) * s, 15.0 * s, 5.0 * s, 0.24)
	for k in n:
		var off := Vector2((_rnd(v, k + 20) - 0.5) * 16.0, (_rnd(v, k + 30) - 0.5) * 6.0) * s * (1.0 if n > 1 else 0.0)
		var r := (7.0 + _rnd(v, k + 40) * 6.0) * s
		var c := pos + off + Vector2(0, -r * 0.5)
		ci.draw_set_transform(c, 0.0, Vector2.ONE)
		var body := _blob(v + k * 7, r)
		var dark := PackedVector2Array()
		for q in body:
			dark.append(q + Vector2(1.5, 1.5) * s)
		_poly(ci, dark, ROCK_D)
		_poly(ci, body, ROCK)
		var lit := PackedVector2Array()
		for q in body:
			lit.append(q * 0.6 + Vector2(-r * 0.18, -r * 0.2))
		_poly(ci, lit, ROCK_L)


static func _butte(ci: CanvasItem, pos: Vector2, p: Dictionary) -> void:
	var pts: PackedVector2Array = p["pts"]
	var tiers := int(p.get("tiers", 3))
	ci.draw_set_transform(pos, 0.0, Vector2.ONE)
	var sh := PackedVector2Array()
	for q in pts:
		sh.append(q + Vector2(14, 10))
	_poly(ci, sh, Color(0, 0, 0, 0.24))
	var side := Color(0.50, 0.28, 0.18)
	var top := Color(0.74, 0.50, 0.32)
	for t in tiers:
		var k := 1.0 - 0.17 * float(t)
		var off := Vector2(-4.0, -12.0) * float(t)
		var poly := PackedVector2Array()
		for q in pts:
			poly.append(q * k + off)
		var col := side.lerp(top, float(t) / float(maxi(tiers - 1, 1)))
		_poly(ci, poly, col.darkened(0.25))
		var lit := PackedVector2Array()
		for q in poly:
			lit.append(q + Vector2(1.5, -7.0))
		_poly(ci, lit, col)
		# crepe
		for j in 3:
			var a := poly[(j * 3 + t) % poly.size()]
			var b := poly[(j * 3 + t + 1) % poly.size()]
			ci.draw_line(a.lerp(Vector2(0, -10.0 * float(t)), 0.15), b.lerp(Vector2(0, -10.0 * float(t)), 0.35), Color(0, 0, 0, 0.18), 1.5)
	var cap := tiers - 1
	var kt := 1.0 - 0.17 * float(cap)
	ci.draw_circle(Vector2(-4.0, -12.0) * float(cap) + Vector2(-pts[0].length() * kt * 0.1, -8.0), pts[0].length() * kt * 0.18, Color(1, 1, 1, 0.08))


static func _bones(ci: CanvasItem, pos: Vector2, s: float, f: float) -> void:
	_tf(ci, pos, s, f)
	ci.draw_circle(Vector2(0, -3), 4.0, BONE)
	ci.draw_circle(Vector2(-1.5, -4), 1.0, ROCK_D)
	ci.draw_circle(Vector2(1.5, -4), 1.0, ROCK_D)
	ci.draw_line(Vector2(-3, -5), Vector2(-10, -9), BONE, 1.6)
	ci.draw_line(Vector2(3, -5), Vector2(10, -9), BONE, 1.6)
	for k in 4:
		ci.draw_arc(Vector2(18.0 + float(k) * 4.0, -3), 7.0, PI, TAU, 8, BONE, 1.4)
	ci.draw_line(Vector2(8, -2), Vector2(32, -2), BONE, 1.6)


static func _wheel(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_tf(ci, pos, s)
	ci.draw_arc(Vector2(0, -9), 9.0, 0.0, TAU, 18, WOOD, 2.2)
	for k in 4:
		var a := float(k) * PI * 0.25
		ci.draw_line(Vector2(cos(a), sin(a)) * 9.0 + Vector2(0, -9), Vector2(-cos(a), -sin(a)) * 9.0 + Vector2(0, -9), WOOD_D, 1.2)
	ci.draw_circle(Vector2(0, -9), 1.8, WOOD_D)


static func _tumbleweed(ci: CanvasItem, pos: Vector2, s: float, v: int) -> void:
	_shadow(ci, pos + Vector2(3.0, 1.0) * s, 9.0 * s, 3.0 * s, 0.18)
	_tf(ci, pos, s)
	var c := Color(0.55, 0.42, 0.24)
	for k in 5:
		var a := _rnd(v, k) * TAU
		ci.draw_arc(Vector2(0, -8), 7.0 + _rnd(v, k + 5) * 3.0, a, a + 4.0, 10, c, 1.2)


static func _log(ci: CanvasItem, pos: Vector2, s: float, a: float) -> void:
	_shadow(ci, pos + Vector2(3.0, 2.0) * s, 20.0 * s, 4.0 * s)
	ci.draw_set_transform(pos + Vector2(0, -4.0 * s), a, Vector2(s, s))
	ci.draw_rect(Rect2(-18, -4.5, 36, 9), WOOD)
	ci.draw_rect(Rect2(-18, -4.5, 36, 3), WOOD_L)
	ci.draw_circle(Vector2(-18, 0), 4.5, WOOD_L)
	ci.draw_arc(Vector2(-18, 0), 2.5, 0.0, TAU, 8, WOOD_D, 1.0)


# ---------------------------------------------------------------------- strutture

static func _house(ci: CanvasItem, pos: Vector2, w: float, h: float, v: int, style: String) -> void:
	var r := Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_rect(Rect2(r.position + Vector2(8, 8), r.size), Color(0, 0, 0, 0.24))
	var wall := Color(0.60, 0.44, 0.28)
	var roof: Color = ROOFS[v % ROOFS.size()]
	if style == "barn":
		wall = Color(0.55, 0.22, 0.17)
		roof = Color(0.50, 0.20, 0.16)
	elif style == "chapel":
		wall = Color(0.84, 0.80, 0.70)
		roof = Color(0.52, 0.40, 0.32)
	var front := 18.0
	ci.draw_rect(Rect2(r.position.x, r.end.y - front, w, front), wall)
	for x in range(int(r.position.x) + 6, int(r.end.x), 9):
		ci.draw_line(Vector2(x, r.end.y - front), Vector2(x, r.end.y), Color(0, 0, 0, 0.16), 1.0)
	var rr := Rect2(r.position.x - 3.0, r.position.y - 2.0, w + 6.0, h - front + 2.0)
	ci.draw_rect(rr, roof)
	ci.draw_rect(Rect2(rr.position.x, rr.position.y, rr.size.x, rr.size.y * 0.5), roof.lightened(0.10))
	var y := rr.position.y + 6.0
	var row := 0
	while y < rr.end.y:
		ci.draw_line(Vector2(rr.position.x, y), Vector2(rr.end.x, y), Color(0, 0, 0, 0.20), 1.0)
		var x := rr.position.x + (5.0 if row % 2 == 0 else 11.0)
		while x < rr.end.x:
			ci.draw_line(Vector2(x, y - 6.0), Vector2(x, y), Color(0, 0, 0, 0.12), 1.0)
			x += 12.0
		y += 6.0
		row += 1
	ci.draw_line(Vector2(rr.position.x, rr.position.y + rr.size.y * 0.5), Vector2(rr.end.x, rr.position.y + rr.size.y * 0.5), roof.darkened(0.35), 2.5)
	ci.draw_rect(rr, WOOD_D, false, 2.0)
	if style == "house" and w > 60.0:
		var cx := rr.position.x + rr.size.x * 0.75
		ci.draw_rect(Rect2(cx + 3, rr.position.y + 9, 11, 13), Color(0, 0, 0, 0.22))
		ci.draw_rect(Rect2(cx, rr.position.y + 5, 11, 13), Color(0.52, 0.30, 0.24))
		ci.draw_rect(Rect2(cx, rr.position.y + 5, 11, 13), ROCK_D, false, 1.5)
	if style == "barn":
		var d := Rect2(pos.x - 22.0, r.end.y - front + 1.0, 44.0, front - 1.0)
		ci.draw_rect(d, Color(0.40, 0.14, 0.11))
		ci.draw_line(d.position, d.end, Color(0.92, 0.88, 0.80), 2.0)
		ci.draw_line(Vector2(d.end.x, d.position.y), Vector2(d.position.x, d.end.y), Color(0.92, 0.88, 0.80), 2.0)
		ci.draw_rect(d, Color(0.92, 0.88, 0.80), false, 2.0)
	elif style == "chapel":
		ci.draw_rect(Rect2(pos.x - 3.0, rr.position.y + 8, 6, 30), Color(0.85, 0.72, 0.32))
		ci.draw_rect(Rect2(pos.x - 10.0, rr.position.y + 16, 20, 6), Color(0.85, 0.72, 0.32))
		ci.draw_rect(Rect2(pos.x - 7.0, r.end.y - front + 2.0, 14, front - 2.0), Color(0.30, 0.20, 0.14))
	else:
		ci.draw_rect(Rect2(pos.x - 7.0, r.end.y - front + 4.0, 14, front - 4.0), WOOD_D)
		ci.draw_rect(Rect2(r.position.x + 10.0, r.end.y - front + 5.0, 14, 9), Color(0.95, 0.82, 0.45, 0.8))
		ci.draw_rect(Rect2(r.end.x - 24.0, r.end.y - front + 5.0, 14, 9), Color(0.95, 0.82, 0.45, 0.8))


static func _tent(ci: CanvasItem, pos: Vector2, s: float, f: float, v: int) -> void:
	_shadow(ci, pos + Vector2(8.0, 4.0) * s, 28.0 * s, 8.0 * s)
	_tf(ci, pos, s, f)
	var cols := [Color(0.80, 0.72, 0.54), Color(0.64, 0.32, 0.24), Color(0.42, 0.48, 0.32)]
	var c: Color = cols[v % 3]
	_poly(ci, PackedVector2Array([Vector2(-22, -4), Vector2(0, -34), Vector2(22, -4), Vector2(24, 0), Vector2(-24, 0)]), c)
	_poly(ci, PackedVector2Array([Vector2(0, -34), Vector2(22, -4), Vector2(24, 0), Vector2(0, 0)]), c.darkened(0.18))
	_poly(ci, PackedVector2Array([Vector2(-6, 0), Vector2(0, -16), Vector2(6, 0)]), Color(0.12, 0.09, 0.07))
	ci.draw_line(Vector2(0, -34), Vector2(0, -38), WOOD_D, 2.0)


static func _campfire(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_tf(ci, pos, s)
	ci.draw_circle(Vector2(0, -3), 22.0, Color(1.0, 0.6, 0.2, 0.10))
	for k in 9:
		var a := float(k) / 9.0 * TAU
		ci.draw_circle(Vector2(cos(a) * 10.0, sin(a) * 5.0 - 3.0), 3.0, ROCK)
	ci.draw_set_transform(pos + Vector2(0, -3.0 * s), 0.0, Vector2(s, s * 0.5))
	ci.draw_circle(Vector2.ZERO, 7.0, Color(0.14, 0.11, 0.09))
	_tf(ci, pos, s)
	ci.draw_line(Vector2(-7, -2), Vector2(7, -5), WOOD_D, 3.0)
	ci.draw_line(Vector2(-6, -5), Vector2(6, -1), WOOD, 3.0)
	_poly(ci, PackedVector2Array([Vector2(-5, -4), Vector2(0, -17), Vector2(5, -4)]), Color(0.95, 0.45, 0.12))
	_poly(ci, PackedVector2Array([Vector2(-3, -4), Vector2(1, -12), Vector2(4, -4)]), Color(1.0, 0.82, 0.30))


static func _fence_seg(ci: CanvasItem, a: Vector2, b: Vector2) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var length := a.distance_to(b)
	var n := maxi(1, int(length / 26.0))
	ci.draw_line(a + Vector2(0, 2), b + Vector2(0, 2), Color(0, 0, 0, 0.2), 3.0)
	ci.draw_line(a, b, WOOD, 2.4)
	for k in n + 1:
		var q := a.lerp(b, float(k) / float(n))
		ci.draw_rect(Rect2(q.x - 2.0, q.y - 4.0, 4.0, 7.0), WOOD_D)
		ci.draw_rect(Rect2(q.x - 2.0, q.y - 4.0, 2.0, 7.0), WOOD_L)


static func _fence_rect(ci: CanvasItem, pos: Vector2, w: float, h: float, gap: float) -> void:
	var tl := pos - Vector2(w, h) * 0.5
	var tr := tl + Vector2(w, 0)
	var bl := tl + Vector2(0, h)
	var br := tl + Vector2(w, h)
	_fence_seg(ci, tl, tr)
	_fence_seg(ci, tr, br)
	_fence_seg(ci, bl, tl)
	if gap > 0.0:
		var mid := (bl.x + br.x) * 0.5
		_fence_seg(ci, bl, Vector2(mid - gap * 0.5, bl.y))
		_fence_seg(ci, Vector2(mid + gap * 0.5, br.y), br)
	else:
		_fence_seg(ci, bl, br)


static func _rail(ci: CanvasItem, pos: Vector2, w: float) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_line(pos + Vector2(-w * 0.5, 2), pos + Vector2(w * 0.5, 2), Color(0, 0, 0, 0.2), 3.0)
	ci.draw_rect(Rect2(pos.x - w * 0.5, pos.y - 2.0, 4, 8), WOOD_D)
	ci.draw_rect(Rect2(pos.x + w * 0.5 - 4.0, pos.y - 2.0, 4, 8), WOOD_D)
	ci.draw_line(pos + Vector2(-w * 0.5, -3), pos + Vector2(w * 0.5, -3), WOOD, 3.0)


static func _windmill(ci: CanvasItem, pos: Vector2, s: float, v: int) -> void:
	_shadow(ci, pos + Vector2(26.0, 6.0) * s, 30.0 * s, 8.0 * s, 0.24)
	_tf(ci, pos, s)
	_poly(ci, PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(7, -64), Vector2(-7, -64)]), WOOD_L)
	_poly(ci, PackedVector2Array([Vector2(0, 0), Vector2(14, 0), Vector2(7, -64), Vector2(0, -64)]), Color(0, 0, 0, 0.18))
	ci.draw_line(Vector2(-13, -2), Vector2(6, -40), WOOD_D, 1.5)
	ci.draw_line(Vector2(13, -2), Vector2(-6, -40), WOOD_D, 1.5)
	var hub := Vector2(0, -66)
	var metal := Color(0.74, 0.76, 0.77)
	ci.draw_line(hub, hub + Vector2(-34, 4), Color(0.45, 0.46, 0.48), 2.0)
	_poly(ci, PackedVector2Array([hub + Vector2(-34, 4), hub + Vector2(-44, 0), hub + Vector2(-44, 9), hub + Vector2(-34, 8)]), Color(0.66, 0.30, 0.22))
	for k in 12:
		var a := float(k) / 12.0 * TAU + float(v) * 0.3
		var tip := hub + Vector2(cos(a), sin(a)) * 22.0
		ci.draw_line(hub, tip, metal, 1.4)
		var perp := Vector2(-sin(a), cos(a)) * 3.0
		_poly(ci, PackedVector2Array([hub + Vector2(cos(a), sin(a)) * 10.0, tip, tip + perp, hub + Vector2(cos(a), sin(a)) * 10.0 + perp]), metal.darkened(0.1))
	ci.draw_circle(hub, 3.0, Color(0.3, 0.3, 0.32))


static func _tank(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(8.0, 4.0) * s, 20.0 * s, 7.0 * s)
	_tf(ci, pos, s)
	ci.draw_rect(Rect2(-14, -22, 28, 18), WOOD)
	ci.draw_rect(Rect2(-14, -22, 8, 18), WOOD_L)
	ci.draw_rect(Rect2(-14, -18, 28, 2), Color(0.35, 0.35, 0.37))
	ci.draw_rect(Rect2(-14, -9, 28, 2), Color(0.35, 0.35, 0.37))
	ci.draw_set_transform(pos + Vector2(0, -22.0 * s), 0.0, Vector2(s, s * 0.45))
	ci.draw_circle(Vector2.ZERO, 14.0, WOOD_D)
	ci.draw_circle(Vector2.ZERO, 11.0, Color(0.20, 0.38, 0.48))
	ci.draw_circle(Vector2(-3, -2), 4.0, Color(0.45, 0.65, 0.70))


static func _haystack(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(8.0, 3.0) * s, 20.0 * s, 6.0 * s)
	_tf(ci, pos, s)
	ci.draw_circle(Vector2(0, -10), 15.0, STRAW.darkened(0.12))
	ci.draw_rect(Rect2(-15, -10, 30, 10), STRAW.darkened(0.12))
	ci.draw_circle(Vector2(-3, -13), 10.0, STRAW)
	for k in 5:
		ci.draw_line(Vector2(-12.0 + float(k) * 6.0, -4), Vector2(-9.0 + float(k) * 5.0, -17), STRAW.darkened(0.25), 1.0)


static func _trough(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(4.0, 2.0) * s, 22.0 * s, 4.0 * s)
	_tf(ci, pos, s)
	ci.draw_rect(Rect2(-20, -12, 40, 12), WOOD_D)
	ci.draw_rect(Rect2(-17, -10, 34, 7), Color(0.28, 0.46, 0.54))
	ci.draw_rect(Rect2(-17, -10, 34, 2), Color(0.55, 0.72, 0.76))
	ci.draw_rect(Rect2(-20, -12, 40, 12), WOOD, false, 1.5)


static func _wagon(ci: CanvasItem, pos: Vector2, s: float, a: float, broken: bool) -> void:
	_shadow(ci, pos + Vector2(6.0, 4.0) * s, 34.0 * s, 10.0 * s)
	ci.draw_set_transform(pos + Vector2(0, -10.0 * s), a + (0.12 if broken else 0.0), Vector2(s, s))
	ci.draw_rect(Rect2(-26, -12, 52, 24), WOOD)
	ci.draw_rect(Rect2(-26, -12, 52, 4), WOOD_L)
	if not broken:
		ci.draw_rect(Rect2(-23, -10, 44, 20), Color(0.86, 0.81, 0.67))
		for k in 5:
			ci.draw_line(Vector2(-18.0 + float(k) * 9.0, -10), Vector2(-18.0 + float(k) * 9.0, 10), Color(0, 0, 0, 0.14), 1.2)
	else:
		for k in 4:
			ci.draw_line(Vector2(-22.0 + float(k) * 13.0, -10), Vector2(-20.0 + float(k) * 13.0, 11), WOOD_D, 2.0)
	ci.draw_line(Vector2(26, 0), Vector2(48, 0), WOOD_D, 3.0)
	ci.draw_rect(Rect2(-20, 11, 10, 4), WOOD_D)
	ci.draw_rect(Rect2(12, 11, 10, 4), WOOD_D)
	if not broken:
		ci.draw_rect(Rect2(-20, -15, 10, 4), WOOD_D)
		ci.draw_rect(Rect2(12, -15, 10, 4), WOOD_D)


static func _horse(ci: CanvasItem, pos: Vector2, s: float, f: float, v: int) -> void:
	_shadow(ci, pos + Vector2(3.0, 1.0) * s, 20.0 * s, 4.0 * s, 0.24)
	var c: Color = HORSES[v % HORSES.size()]
	_tf(ci, pos, s, f)
	for lx in [-11.0, -7.0, 8.0, 12.0]:
		ci.draw_line(Vector2(float(lx), -14), Vector2(float(lx), 0), c.darkened(0.25), 2.4)
	ci.draw_set_transform(pos + Vector2(0, -19.0 * s), 0.0, Vector2(s * f, s * 0.55))
	ci.draw_circle(Vector2.ZERO, 15.0, c)
	_tf(ci, pos, s, f)
	_poly(ci, PackedVector2Array([Vector2(10, -22), Vector2(17, -34), Vector2(22, -31), Vector2(15, -17)]), c)
	ci.draw_circle(Vector2(20, -32), 4.5, c)
	ci.draw_line(Vector2(11, -24), Vector2(16, -34), c.darkened(0.45), 2.0)
	ci.draw_line(Vector2(-14, -22), Vector2(-20, -10), c.darkened(0.45), 2.6)
	ci.draw_rect(Rect2(-4, -26, 9, 3), Color(0.45, 0.20, 0.14))


static func _crate(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(3.0, 1.0) * s, 10.0 * s, 3.0 * s)
	_tf(ci, pos, s)
	ci.draw_rect(Rect2(-8, -14, 16, 14), WOOD)
	ci.draw_rect(Rect2(-8, -14, 16, 4), WOOD_L)
	ci.draw_line(Vector2(-8, -10), Vector2(8, 0), WOOD_D, 1.2)
	ci.draw_rect(Rect2(-8, -14, 16, 14), WOOD_D, false, 1.2)


static func _barrel(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(3.0, 1.0) * s, 9.0 * s, 3.0 * s)
	_tf(ci, pos, s)
	ci.draw_rect(Rect2(-7, -16, 14, 16), WOOD)
	ci.draw_rect(Rect2(-7, -16, 4, 16), WOOD_L)
	ci.draw_rect(Rect2(-7, -12, 14, 2), Color(0.30, 0.30, 0.32))
	ci.draw_rect(Rect2(-7, -5, 14, 2), Color(0.30, 0.30, 0.32))
	ci.draw_set_transform(pos + Vector2(0, -16.0 * s), 0.0, Vector2(s, s * 0.4))
	ci.draw_circle(Vector2.ZERO, 7.0, WOOD_L)


static func _cross(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(0.0, 2.0) * s, 11.0 * s, 4.0 * s, 0.30)
	_tf(ci, pos, s)
	ci.draw_line(Vector2(0, 0), Vector2(0, -26), WOOD_L, 3.0)
	ci.draw_line(Vector2(-7, -19), Vector2(7, -19), WOOD_L, 3.0)
	ci.draw_line(Vector2(1.5, 0), Vector2(1.5, -26), WOOD_D, 1.0)


static func _headstone(ci: CanvasItem, pos: Vector2, s: float, v: int) -> void:
	_shadow(ci, pos + Vector2(4.0, 2.0) * s, 11.0 * s, 4.0 * s, 0.30)
	_tf(ci, pos, s)
	ci.draw_rect(Rect2(-6, -14, 12, 14), ROCK_L)
	ci.draw_circle(Vector2(0, -14), 6.0, ROCK_L)
	ci.draw_rect(Rect2(2, -14, 4, 14), ROCK)
	ci.draw_line(Vector2(-3, -12), Vector2(3, -12), ROCK_D, 1.0)
	if v % 2 == 0:
		ci.draw_line(Vector2(-3, -9), Vector2(3, -9), ROCK_D, 1.0)


static func _well(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(6.0, 3.0) * s, 22.0 * s, 7.0 * s)
	ci.draw_set_transform(pos + Vector2(0, -6.0 * s), 0.0, Vector2(s, s * 0.6))
	ci.draw_circle(Vector2.ZERO, 16.0, ROCK_D)
	ci.draw_circle(Vector2.ZERO, 14.0, ROCK)
	ci.draw_circle(Vector2.ZERO, 10.0, Color(0.07, 0.11, 0.15))
	_tf(ci, pos, s)
	ci.draw_rect(Rect2(-15, -34, 3, 28), WOOD)
	ci.draw_rect(Rect2(12, -34, 3, 28), WOOD)
	ci.draw_rect(Rect2(-17, -38, 34, 5), WOOD_D)
	_poly(ci, PackedVector2Array([Vector2(-19, -37), Vector2(0, -48), Vector2(19, -37)]), Color(0.46, 0.28, 0.18))
	ci.draw_line(Vector2(0, -34), Vector2(0, -22), Color(0.7, 0.6, 0.4), 1.0)
	ci.draw_rect(Rect2(-3, -22, 6, 5), WOOD_L)


static func _signpost(ci: CanvasItem, pos: Vector2, text: String, w: float) -> void:
	_shadow(ci, pos + Vector2(6.0, 2.0), 20.0, 5.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	ci.draw_line(pos + Vector2(-w * 0.35, 0), pos + Vector2(-w * 0.35, -34), WOOD_D, 4.0)
	ci.draw_line(pos + Vector2(w * 0.35, 0), pos + Vector2(w * 0.35, -34), WOOD_D, 4.0)
	var board := Rect2(pos.x - w * 0.5, pos.y - 56.0, w, 24.0)
	ci.draw_rect(board, WOOD)
	ci.draw_rect(board, GOLD, false, 2.0)
	if text != "":
		ci.draw_string(WesternTheme.get_font(), Vector2(board.position.x, board.position.y + 17.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, 13, GOLD)


static func _lamp(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(5.0, 1.0) * s, 8.0 * s, 3.0 * s)
	_tf(ci, pos, s)
	var iron := Color(0.16, 0.15, 0.15)
	ci.draw_circle(Vector2(0, -1), 3.5, iron)
	ci.draw_line(Vector2(0, 0), Vector2(0, -44), iron, 3.0)
	ci.draw_rect(Rect2(-5, -57, 10, 13), iron)
	ci.draw_rect(Rect2(-3.5, -55, 7, 9), Color(0.96, 0.84, 0.48))
	_poly(ci, PackedVector2Array([Vector2(-7, -57), Vector2(0, -64), Vector2(7, -57)]), iron)


static func _outhouse(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(6.0, 2.0) * s, 14.0 * s, 5.0 * s)
	_tf(ci, pos, s)
	ci.draw_rect(Rect2(-9, -30, 18, 30), WOOD)
	ci.draw_rect(Rect2(-9, -30, 5, 30), WOOD_L)
	ci.draw_rect(Rect2(-11, -35, 22, 6), WOOD_D)
	ci.draw_rect(Rect2(-5, -24, 10, 22), WOOD_D, false, 1.2)
	ci.draw_circle(Vector2(0, -18), 1.6, Color(0.1, 0.07, 0.05))


static func _woodpile(ci: CanvasItem, pos: Vector2, s: float) -> void:
	_shadow(ci, pos + Vector2(4.0, 2.0) * s, 16.0 * s, 4.0 * s)
	_tf(ci, pos, s)
	var rows := [4, 3, 2]
	for r in 3:
		var n: int = rows[r]
		for k in n:
			var c := Vector2((float(k) - float(n - 1) * 0.5) * 8.0, -4.0 - float(r) * 7.0)
			ci.draw_circle(c, 4.2, WOOD)
			ci.draw_circle(c, 2.4, WOOD_L)


static func _ruin(ci: CanvasItem, pos: Vector2, w: float, h: float, v: int) -> void:
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var r := Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h))
	ci.draw_rect(r, Color(0.16, 0.13, 0.11, 0.55))
	ci.draw_rect(r, Color(0.22, 0.18, 0.15), false, 5.0)
	for k in 7:
		var a := r.position + Vector2(_rnd(v, k) * w, _rnd(v, k + 8) * h)
		var d := Vector2(cos(_rnd(v, k + 3) * TAU), sin(_rnd(v, k + 3) * TAU)) * (14.0 + _rnd(v, k + 5) * 16.0)
		ci.draw_line(a, a + d, Color(0.10, 0.08, 0.07), 3.0)
	ci.draw_rect(Rect2(r.end.x - 26.0, r.position.y + 6.0, 16, 18), ROCK_D)
	ci.draw_rect(Rect2(r.end.x - 24.0, r.position.y + 4.0, 16, 18), ROCK)
	ci.draw_rect(Rect2(r.end.x - 20.0, r.position.y + 8.0, 8, 10), Color(0.09, 0.07, 0.06))
	for k in 6:
		ci.draw_circle(r.position + Vector2(_rnd(v, k + 20) * w, _rnd(v, k + 30) * h), 2.0 + _rnd(v, k) * 2.0, ROCK_D)


static func _bedroll(ci: CanvasItem, pos: Vector2, s: float, f: float) -> void:
	_shadow(ci, pos + Vector2(2.0, 1.0) * s, 16.0 * s, 4.0 * s, 0.2)
	_tf(ci, pos, s, f)
	ci.draw_rect(Rect2(-14, -8, 28, 8), Color(0.55, 0.30, 0.25))
	ci.draw_rect(Rect2(-14, -8, 28, 2), Color(0.72, 0.45, 0.36))
	ci.draw_rect(Rect2(-14, -9, 7, 9), Color(0.85, 0.80, 0.68))


static func _bridge(ci: CanvasItem, pos: Vector2, a: float, length: float, w: float) -> void:
	ci.draw_set_transform(pos + Vector2(6, 8), a, Vector2.ONE)
	ci.draw_rect(Rect2(-length * 0.5, -w * 0.5, length, w), Color(0, 0, 0, 0.25))
	ci.draw_set_transform(pos, a, Vector2.ONE)
	ci.draw_rect(Rect2(-length * 0.5, -w * 0.5, length, w), WOOD_L)
	var x := -length * 0.5 + 6.0
	while x < length * 0.5:
		ci.draw_line(Vector2(x, -w * 0.5), Vector2(x, w * 0.5), WOOD_D, 1.2)
		x += 11.0
	ci.draw_rect(Rect2(-length * 0.5, -w * 0.5 - 3.0, length, 5.0), WOOD_D)
	ci.draw_rect(Rect2(-length * 0.5, w * 0.5 - 2.0, length, 5.0), WOOD_D)
	x = -length * 0.5 + 4.0
	while x < length * 0.5:
		ci.draw_rect(Rect2(x - 2.5, -w * 0.5 - 6.0, 5, 6), WOOD)
		ci.draw_rect(Rect2(x - 2.5, w * 0.5, 5, 6), WOOD)
		x += 40.0


static func _stones(ci: CanvasItem, pos: Vector2, a: float, length: float, v: int) -> void:
	ci.draw_set_transform(pos, a, Vector2.ONE)
	var n := maxi(3, int(length / 22.0))
	for k in n:
		var x := -length * 0.5 + (float(k) + 0.5) * length / float(n)
		var y := (_rnd(v, k) - 0.5) * 16.0
		ci.draw_circle(Vector2(x + 1.5, y + 2.0), 8.0, Color(0, 0, 0, 0.22))
		ci.draw_circle(Vector2(x, y), 7.0, ROCK)
		ci.draw_circle(Vector2(x - 2.0, y - 2.0), 4.0, ROCK_L)
