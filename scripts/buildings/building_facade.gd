class_name BuildingFacade
extends Node2D
## Aspetto di un edificio (disegnato da codice, sostituibile con sprite).
## Viene disegnato sopra il lotto: tetto sul lato lontano dalla strada,
## facciata con porta, finestre e insegna sul lato strada.

var _size := Vector2(120, 100)
var _def: Dictionary = {}
var _door_bottom := true


func setup(rect: Rect2, def: Dictionary, door_bottom: bool) -> void:
	position = rect.position
	_size = rect.size
	_def = def
	_door_bottom = door_bottom
	z_index = 1
	queue_redraw()


func _draw() -> void:
	var s := _size
	var wall := Color(_def.get("color", "#7a5a3a"))
	var roof := Color(_def.get("roof", "#4a2f1a"))
	var edge := WesternTheme.color("wood_dark")
	var gold := WesternTheme.color("gold")

	draw_rect(Rect2(Vector2.ZERO, s), wall)
	var y := 8.0
	while y < s.y:
		draw_line(Vector2(0, y), Vector2(s.x, y), Color(0, 0, 0, 0.18), 1.0)
		y += 12.0

	# Tetto sul lato opposto alla strada
	var roof_h := minf(s.y * 0.3, 36.0)
	var roof_y := 0.0 if _door_bottom else s.y - roof_h
	draw_rect(Rect2(0, roof_y, s.x, roof_h), roof)
	draw_line(Vector2(0, roof_y + roof_h * 0.5), Vector2(s.x, roof_y + roof_h * 0.5), Color(0, 0, 0, 0.25), 2.0)

	# Porta sul lato strada
	var door_w := 30.0
	var door_h := 24.0
	var door_y := s.y - door_h if _door_bottom else 0.0
	draw_rect(Rect2(s.x * 0.5 - door_w * 0.5, door_y, door_w, door_h), edge)
	draw_rect(Rect2(s.x * 0.5 - door_w * 0.5 + 3, door_y + (3 if not _door_bottom else 3), door_w - 6, door_h - 6), WesternTheme.color("wood"))
	draw_circle(Vector2(s.x * 0.5 + 8, door_y + door_h * 0.5), 1.8, gold)

	# Finestre ai lati della porta
	var win_y := door_y + 4.0
	for fx in [0.2, 0.8]:
		var wx: float = s.x * fx - 12.0
		draw_rect(Rect2(wx, win_y, 24, 16), edge)
		draw_rect(Rect2(wx + 2, win_y + 2, 20, 12), Color(0.95, 0.82, 0.45, 0.85))
		draw_line(Vector2(wx + 12, win_y + 2), Vector2(wx + 12, win_y + 14), edge, 1.5)

	# Insegna
	var text := String(_def.get("sign", ""))
	if text != "":
		var font := WesternTheme.get_font()
		var fs := 15
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bw := minf(tw + 20.0, s.x - 8.0)
		var by := s.y * 0.5 - 12.0
		draw_rect(Rect2((s.x - bw) * 0.5, by, bw, 24), WesternTheme.color("wood"))
		draw_rect(Rect2((s.x - bw) * 0.5, by, bw, 24), gold, false, 2.0)
		draw_string(font, Vector2((s.x - bw) * 0.5, by + 17), text, HORIZONTAL_ALIGNMENT_CENTER, bw, fs, gold)

	draw_rect(Rect2(Vector2.ZERO, s), edge, false, 3.0)
