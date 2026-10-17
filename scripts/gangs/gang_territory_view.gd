class_name GangTerritoryView
extends Node2D
## Rifugio della banda disegnato da codice: tende, fuoco da campo, bandiera.
## L'area di territorio compare solo dopo che il giocatore ha scoperto la banda.

var gang_id: String = ""

var _color: Color = Color.WHITE
var _title: String = ""
var _radius: float = 300.0
var _discovered: bool = false
var _t: float = 0.0


func setup(g: Dictionary) -> void:
	gang_id = str(g["id"])
	_color = Color(str(g["color"]))
	_title = str(g["name"])
	_radius = GangSystem.radius_of(g)
	_discovered = bool(g["discovered"])
	z_index = -5
	process_mode = Node.PROCESS_MODE_PAUSABLE
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if _discovered:
		draw_circle(Vector2.ZERO, _radius, Color(_color, 0.07))
		draw_arc(Vector2.ZERO, _radius, 0.0, TAU, 96, Color(_color, 0.35), 3.0)
	# tende
	var tent: Color = _color.darkened(0.25)
	for off in [Vector2(-70, 10), Vector2(62, 2), Vector2(-4, -58)]:
		var o: Vector2 = off
		draw_colored_polygon(PackedVector2Array([
			o + Vector2(-28, 22), o + Vector2(28, 22), o + Vector2(0, -28)]), tent)
		draw_colored_polygon(PackedVector2Array([
			o + Vector2(-8, 22), o + Vector2(8, 22), o + Vector2(0, 0)]), Color(0.08, 0.05, 0.03))
	# fuoco da campo
	draw_circle(Vector2(0, 18), 9.0, Color(0.25, 0.15, 0.08))
	var flick: float = sin(_t * 9.0) * 1.6
	draw_circle(Vector2(0, 16), 7.0 + flick, Color(0.95, 0.45, 0.1))
	draw_circle(Vector2(0, 15), 3.5 + flick * 0.5, Color(1.0, 0.85, 0.3))
	# bandiera
	draw_line(Vector2(96, -6), Vector2(96, -78), Color(0.25, 0.15, 0.08), 3.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(96, -78), Vector2(132, -66), Vector2(96, -54)]), _color)
	# nome
	var label: String = "«%s»" % _title
	var font: Font = ThemeDB.fallback_font
	draw_string(font, Vector2(-119, 63), label, HORIZONTAL_ALIGNMENT_CENTER, 240.0, 16, Color(0, 0, 0, 0.7))
	draw_string(font, Vector2(-120, 62), label, HORIZONTAL_ALIGNMENT_CENTER, 240.0, 16, Color(1, 1, 1, 0.9))
