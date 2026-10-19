class_name MapTownGround
extends Node2D
## Suolo della città (Mappa 1): strada con striature, ciottoli, impronte di zoccoli e pozzanghere,
## marciapiedi di legno, solchi delle ruote e lotti di terra battuta con erbacce. Solo grafica.

var _street := Rect2()
var _bounds := Rect2()
var _lots: Array[Rect2] = []
var _decals: Array = []


func setup(bounds: Rect2, town: Dictionary) -> void:
	_bounds = bounds
	var s: Array = town["street"]
	_street = Rect2(s[0], s[1], s[2], s[3])
	_lots.clear()
	for lot in town["lots"]:
		var r: Array = lot["rect"]
		_lots.append(Rect2(r[0], r[1], r[2], r[3]))
	var rng := WorldSeed.rng_for("town_ground")
	_decals.clear()
	for i in 160:
		_decals.append({"k": "streak", "p": _rand_in(rng, _street.grow(-4.0)), "len": rng.randf_range(30.0, 120.0), "light": rng.randf() < 0.5})
	for i in 150:
		_decals.append({"k": "pebble", "p": _rand_in(rng, _street.grow(-6.0)), "r": rng.randf_range(1.2, 3.2)})
	for i in 90:
		_decals.append({"k": "hoof", "p": _rand_in(rng, _street.grow(-12.0)), "a": rng.randf_range(-0.4, 0.4)})
	for i in 7:
		_decals.append({"k": "puddle", "p": _rand_in(rng, _street.grow(-30.0)), "r": rng.randf_range(14.0, 30.0)})
	for r in _lots:
		for i in 14:
			_decals.append({"k": "weed", "p": _rand_in(rng, r.grow(-8.0)), "s": rng.randf_range(0.8, 1.3)})
		for i in 10:
			_decals.append({"k": "pebble", "p": _rand_in(rng, r.grow(-6.0)), "r": rng.randf_range(1.5, 4.0)})
		for i in 4:
			_decals.append({"k": "patch", "p": _rand_in(rng, r.grow(-20.0)), "r": rng.randf_range(14.0, 34.0), "light": rng.randf() < 0.5})
	queue_redraw()


static func _rand_in(rng: RandomNumberGenerator, r: Rect2) -> Vector2:
	return Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))


func _draw() -> void:
	draw_rect(_bounds, Color("#3b2614"), false, 8.0)
	# Lotti: terra battuta.
	for r in _lots:
		draw_rect(r, Color(0.60, 0.43, 0.26))
	# Strada.
	draw_rect(_street, Color(0.66, 0.51, 0.32))
	for d in _decals:
		var p: Vector2 = d["p"]
		match str(d["k"]):
			"streak":
				var c := Color(0.80, 0.66, 0.44, 0.22) if bool(d["light"]) else Color(0.48, 0.34, 0.20, 0.20)
				draw_line(p, p + Vector2(float(d["len"]), 0.0), c, 2.0)
			"pebble":
				draw_circle(p, float(d["r"]), Color(0.40, 0.30, 0.20, 0.55))
				draw_circle(p + Vector2(-0.6, -0.6), float(d["r"]) * 0.5, Color(0.70, 0.60, 0.46, 0.6))
			"hoof":
				var a := float(d["a"])
				draw_arc(p, 3.0, PI * 0.15 + a, PI * 0.85 + a, 6, Color(0.40, 0.28, 0.17, 0.5), 1.4)
				draw_arc(p + Vector2(9, 2), 3.0, PI * 0.15 + a, PI * 0.85 + a, 6, Color(0.40, 0.28, 0.17, 0.5), 1.4)
			"puddle":
				draw_set_transform(p, 0.0, Vector2(1.0, 0.4))
				draw_circle(Vector2.ZERO, float(d["r"]), Color(0.36, 0.26, 0.17, 0.55))
				draw_circle(Vector2(-3, -2), float(d["r"]) * 0.6, Color(0.45, 0.50, 0.52, 0.35))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			"weed":
				var k := float(d["s"])
				var col := Color("#8d7a3c")
				draw_line(p, p + Vector2(-4, -9) * k, col, 1.5)
				draw_line(p, p + Vector2(0, -12) * k, col, 1.5)
				draw_line(p, p + Vector2(4, -9) * k, col, 1.5)
			"patch":
				draw_set_transform(p, 0.0, Vector2(1.0, 0.45))
				draw_circle(Vector2.ZERO, float(d["r"]), Color(0.78, 0.62, 0.40, 0.20) if bool(d["light"]) else Color(0.40, 0.28, 0.16, 0.20))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_street_details()
	for r in _lots:
		draw_rect(r, Color("#3b2614"), false, 4.0)


# Marciapiedi di legno nei 10 px tra strada e lotti, bordi e solchi delle ruote.
func _draw_street_details() -> void:
	var wood := Color("#7a5632")
	var plank := Color(0, 0, 0, 0.28)
	for sy in [_street.position.y - 10.0, _street.end.y]:
		var y: float = sy
		draw_rect(Rect2(_street.position.x, y, _street.size.x, 10.0), wood)
		var x := _street.position.x
		while x < _street.end.x:
			draw_line(Vector2(x, y), Vector2(x, y + 10.0), plank, 1.0)
			x += 22.0
	var edge := Color("#6e5230")
	draw_line(_street.position, Vector2(_street.end.x, _street.position.y), edge, 3.0)
	draw_line(Vector2(_street.position.x, _street.end.y), _street.end, edge, 3.0)
	var rut := Color(0.45, 0.32, 0.18, 0.55)
	for fy in [0.36, 0.64]:
		var ry: float = _street.position.y + _street.size.y * float(fy)
		draw_dashed_line(Vector2(_street.position.x + 20.0, ry), Vector2(_street.end.x - 20.0, ry), rut, 3.0, 26.0)
