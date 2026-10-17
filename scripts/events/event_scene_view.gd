class_name EventSceneView
extends Node2D
## Grafica in mappa degli eventi casuali (Feature 24): fuoco, rapinatori, carovana, rissa, duellante, straniero.
## Il tipo viene da "scene" in data/events.json. Svanisce da solo dopo `seconds`.

const PAUSE_OK := Node.PROCESS_MODE_ALWAYS

var kind: String = ""
var _life: float = 60.0
var _age: float = 0.0


func setup(k: String, seconds: float) -> void:
	kind = k
	_life = maxf(5.0, seconds)
	z_index = 5
	queue_redraw()


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return
	modulate.a = clampf((_life - _age) / 4.0, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	match kind:
		"fire": _fire(t)
		"robbers": _robbers(t)
		"caravan": _caravan(t)
		"brawl": _brawl(t)
		"duelist": _person(Vector2.ZERO, Color("#3a2a1c"), Color("#2b1b10"), t, true)
		"stranger": _stranger(t)


func _person(p: Vector2, shirt: Color, hat: Color, t: float, draw_gun: bool = false, mask: bool = false) -> void:
	draw_circle(p + Vector2(0, 22), 14.0, Color(0, 0, 0, 0.25))
	draw_rect(Rect2(p.x - 8, p.y - 4, 16, 26), shirt)
	draw_circle(p + Vector2(0, -12), 8.0, Color("#e0b48a"))
	if mask:
		draw_rect(Rect2(p.x - 8, p.y - 12, 16, 7), Color("#7a1f1f"))
	draw_rect(Rect2(p.x - 13, p.y - 18, 26, 4), hat)
	draw_rect(Rect2(p.x - 8, p.y - 26, 16, 9), hat)
	if draw_gun:
		draw_line(p + Vector2(8, 6), p + Vector2(20, 8 + sin(t * 3.0) * 1.5), Color("#2b2b2b"), 3.0)


func _flame(p: Vector2, h: float, t: float, seed_off: float) -> void:
	var w := h * 0.45
	var sway := sin(t * 7.0 + seed_off) * h * 0.12
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(sway, -h), p + Vector2(w, 0)]), Color("#d8501a"))
	var h2 := h * (0.62 + sin(t * 9.0 + seed_off) * 0.08)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.6, 0), p + Vector2(sway * 0.6, -h2), p + Vector2(w * 0.6, 0)]), Color("#f4a52a"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w * 0.3, 0), p + Vector2(0, -h2 * 0.55), p + Vector2(w * 0.3, 0)]), Color("#fff1a0"))


func _fire(t: float) -> void:
	draw_circle(Vector2(0, 6), 70.0 + sin(t * 4.0) * 4.0, Color(1.0, 0.55, 0.15, 0.12))
	draw_rect(Rect2(-46, -6, 92, 18), Color("#3b2614"))
	draw_rect(Rect2(-46, -6, 92, 18), Color("#1f1208"), false, 2.0)
	for i in 5:
		_flame(Vector2(-36 + i * 18, -4), 44.0 + (i % 2) * 18.0, t, float(i) * 1.7)
	for i in 4:
		var k := fmod(t * 0.35 + float(i) * 0.25, 1.0)
		draw_circle(Vector2(sin(float(i) * 2.3 + t) * 14.0, -50.0 - k * 80.0), 10.0 + k * 16.0, Color(0.25, 0.25, 0.25, 0.35 * (1.0 - k)))


func _robbers(t: float) -> void:
	_person(Vector2(-26, 0), Color("#2f2f3a"), Color("#1a1a1a"), t, true, true)
	_person(Vector2(26, 6), Color("#3a2f2a"), Color("#1a1a1a"), t, true, true)
	draw_circle(Vector2(36, -6), 9.0, Color("#6b5a2e"))
	draw_circle(Vector2(36, -6), 9.0, Color("#2b1b10"), false, 2.0)
	draw_string(ThemeDB.fallback_font, Vector2(-6, -44 - absf(sin(t * 6.0)) * 4.0), "!", HORIZONTAL_ALIGNMENT_CENTER, -1, 28, Color("#c0392b"))


func _caravan(t: float) -> void:
	var bob := sin(t * 3.0) * 1.2
	draw_rect(Rect2(-60, -26 + bob, 120, 34), Color("#7a5230"))
	draw_rect(Rect2(-60, -26 + bob, 120, 34), Color("#3b2614"), false, 3.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-56, -26 + bob), Vector2(-40, -56 + bob), Vector2(40, -56 + bob), Vector2(56, -26 + bob)]), Color("#e8dcc0"))
	for x in [-38.0, 38.0]:
		draw_circle(Vector2(x, 10), 15.0, Color("#3b2614"))
		draw_circle(Vector2(x, 10), 10.0, Color("#a07848"))
		var a := t * 2.0
		draw_line(Vector2(x, 10) - Vector2(cos(a), sin(a)) * 10.0, Vector2(x, 10) + Vector2(cos(a), sin(a)) * 10.0, Color("#3b2614"), 2.0)
	for hx in [90.0, 118.0]:
		draw_rect(Rect2(hx - 12, -12, 26, 14), Color("#5a3a22"))
		draw_rect(Rect2(hx + 8, -20, 8, 10), Color("#5a3a22"))
		draw_line(Vector2(hx - 10, 2), Vector2(hx - 10, 18), Color("#3b2614"), 3.0)
		draw_line(Vector2(hx + 8, 2), Vector2(hx + 8, 18), Color("#3b2614"), 3.0)
	draw_line(Vector2(60, -6), Vector2(90, -6), Color("#3b2614"), 2.0)
	_person(Vector2(-80, 4), Color("#4a5a3a"), Color("#4a2f1a"), t)


func _brawl(t: float) -> void:
	var s := sin(t * 8.0) * 3.0
	_person(Vector2(-18 + s, 0), Color("#5a3a3a"), Color("#4a2f1a"), t)
	_person(Vector2(18 - s, 0), Color("#3a4a5a"), Color("#2b1b10"), t)
	draw_line(Vector2(-8, 4), Vector2(6, 2), Color("#e0b48a"), 3.0)
	for i in 3:
		var k := fmod(t * 1.2 + float(i) / 3.0, 1.0)
		draw_circle(Vector2(-30 + i * 30, 24 - k * 10.0), 8.0 + k * 12.0, Color(0.7, 0.6, 0.45, 0.3 * (1.0 - k)))


func _stranger(t: float) -> void:
	draw_circle(Vector2(18, 6), 46.0 + sin(t * 3.0) * 3.0, Color(1.0, 0.85, 0.4, 0.10))
	draw_circle(Vector2(0, 22), 14.0, Color(0, 0, 0, 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 22), Vector2(-9, -8), Vector2(9, -8), Vector2(14, 22)]), Color("#2a2a33"))
	draw_circle(Vector2(0, -14), 9.0, Color("#1c1c22"))
	draw_rect(Rect2(-14, -22, 28, 4), Color("#15151a"))
	draw_line(Vector2(10, 0), Vector2(20, 4), Color("#2a2a33"), 3.0)
	draw_rect(Rect2(17, 4, 7, 10), Color("#e8b84a"))
