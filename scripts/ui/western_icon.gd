class_name WesternIcon
extends Control
## Icone procedurali (nessun asset esterno richiesto).
## Sostituibili in futuro con sprite veri senza cambiare l'API.

enum Kind { HEART, COIN, STAR, BAG, HAT }

@export var kind: Kind = Kind.COIN:
	set(v):
		kind = v
		queue_redraw()
@export var icon_size: float = 28.0:
	set(v):
		icon_size = v
		custom_minimum_size = Vector2(v, v)
		queue_redraw()


func _ready() -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	match kind:
		Kind.HEART: _heart(c, r)
		Kind.COIN: _coin(c, r)
		Kind.STAR: _star(c, r)
		Kind.BAG: _bag(c, r)
		Kind.HAT: _hat(c, r)


func _heart(c: Vector2, r: float) -> void:
	var col := WesternTheme.color("blood").lightened(0.1)
	var edge := WesternTheme.color("wood_dark")
	draw_circle(c + Vector2(-r * 0.45, -r * 0.25), r * 0.55, edge)
	draw_circle(c + Vector2(r * 0.45, -r * 0.25), r * 0.55, edge)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 1.0, -r * 0.05), c + Vector2(r * 1.0, -r * 0.05), c + Vector2(0, r * 1.0)]), edge)
	var q := 0.85
	draw_circle(c + Vector2(-r * 0.45, -r * 0.25), r * 0.55 * q, col)
	draw_circle(c + Vector2(r * 0.45, -r * 0.25), r * 0.55 * q, col)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.0), c + Vector2(r * 0.9, -r * 0.0), c + Vector2(0, r * 0.88)]), col)
	draw_circle(c + Vector2(-r * 0.55, -r * 0.4), r * 0.15, Color(1, 1, 1, 0.45))


func _coin(c: Vector2, r: float) -> void:
	draw_circle(c, r, WesternTheme.color("gold_dark"))
	draw_circle(c, r * 0.84, WesternTheme.color("gold"))
	draw_arc(c, r * 0.62, 0, TAU, 24, WesternTheme.color("gold_dark"), 1.5)
	var font := WesternTheme.get_font()
	var fs := int(r * 1.2)
	draw_string(font, Vector2(c.x - r, c.y + fs * 0.35), "$", HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fs, WesternTheme.color("ink"))


func _star(c: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		var rr := r if i % 2 == 0 else r * 0.45
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	draw_colored_polygon(pts, WesternTheme.color("gold"))
	pts.append(pts[0])
	draw_polyline(pts, WesternTheme.color("gold_dark"), 2.0)
	for i in 5:
		var a := -PI / 2.0 + i * TAU / 5.0
		draw_circle(c + Vector2(cos(a), sin(a)) * r * 0.98, r * 0.1, WesternTheme.color("gold").lightened(0.3))


func _bag(c: Vector2, r: float) -> void:
	var cloth := WesternTheme.color("wood_light")
	var edge := WesternTheme.color("wood_dark")
	draw_circle(c + Vector2(0, r * 0.25), r * 0.8, edge)
	draw_circle(c + Vector2(0, r * 0.25), r * 0.68, cloth)
	draw_rect(Rect2(c.x - r * 0.35, c.y - r * 0.7, r * 0.7, r * 0.35), edge)
	draw_rect(Rect2(c.x - r * 0.28, c.y - r * 0.64, r * 0.56, r * 0.24), cloth)
	draw_line(c + Vector2(-r * 0.4, -r * 0.35), c + Vector2(r * 0.4, -r * 0.35), WesternTheme.color("gold"), 2.0)


func _hat(c: Vector2, r: float) -> void:
	var felt := WesternTheme.color("wood_light")
	var edge := WesternTheme.color("wood_dark")
	draw_rect(Rect2(c.x - r, c.y + r * 0.15, r * 2.0, r * 0.3), edge)
	draw_rect(Rect2(c.x - r * 0.95, c.y + r * 0.2, r * 1.9, r * 0.2), felt)
	draw_rect(Rect2(c.x - r * 0.5, c.y - r * 0.7, r * 1.0, r * 0.9), edge)
	draw_rect(Rect2(c.x - r * 0.44, c.y - r * 0.64, r * 0.88, r * 0.8), felt)
	draw_rect(Rect2(c.x - r * 0.44, c.y - r * 0.02, r * 0.88, r * 0.16), WesternTheme.color("gold_dark"))
