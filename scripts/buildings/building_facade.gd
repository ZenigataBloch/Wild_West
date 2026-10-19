class_name BuildingFacade
extends Node2D
## Aspetto di un edificio visto dall'alto (disegnato da codice, sostituibile con sprite).
## Viene disegnato sopra il lotto: tetto (tegole, lamiera o assi, con colmo, comignolo e fumo) sul lato
## lontano dalla strada, fronte con porta, finestre e architrave sul lato strada, insegna sul tetto
## e dettagli per tipo (saloon, banca, sceriffo). Le finestre restano dove le cerca NightLights.

const FRONT := 28.0   # altezza della fascia di facciata sul lato strada

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


# Coordinate "da edificio": y cresce verso la strada. Se la strada è sopra, si specchia in verticale.
func _r(x: float, y: float, w: float, h: float) -> Rect2:
	if _door_bottom:
		return Rect2(x, y, w, h)
	return Rect2(x, _size.y - y - h, w, h)


func _pt(x: float, y: float) -> Vector2:
	return Vector2(x, y if _door_bottom else _size.y - y)


func _draw() -> void:
	var s := _size
	var wall := Color(_def.get("color", "#7a5a3a"))
	var roof := Color(_def.get("roof", "#4a2f1a"))
	var edge := WesternTheme.color("wood_dark")
	var gold := WesternTheme.color("gold")
	var text := String(_def.get("sign", ""))
	var variant := absi(text.hash()) % 3
	var roof_h := s.y - FRONT
	var cx := s.x * 0.5

	# Ombra a terra (luce da in alto a sinistra).
	draw_rect(Rect2(Vector2(7, 7), s), Color(0, 0, 0, 0.22))

	# Fronte: assi verticali e luce sul bordo.
	draw_rect(_r(0, roof_h, s.x, FRONT), wall)
	var x := 6.0
	while x < s.x:
		draw_line(_pt(x, roof_h), _pt(x, s.y), Color(0, 0, 0, 0.16), 1.0)
		x += 10.0
	draw_rect(_r(0, s.y - 2.0, s.x, 2.0), wall.lightened(0.25))

	# Tetto: due falde (la più lontana dalla strada più chiara) e rivestimento.
	var rr := _r(-3, -3, s.x + 6.0, roof_h + 3.0)
	draw_rect(rr, roof)
	draw_rect(_r(-3, -3, s.x + 6.0, roof_h * 0.5 + 1.5), roof.lightened(0.10))
	match variant:
		0:   # tegole a file sfalsate
			var y := 6.0
			var row := 0
			while y < roof_h:
				draw_line(_pt(-3, y), _pt(s.x + 3.0, y), Color(0, 0, 0, 0.20), 1.0)
				var tx := 5.0 if row % 2 == 0 else 11.0
				while tx < s.x:
					draw_line(_pt(tx, y - 6.0), _pt(tx, y), Color(0, 0, 0, 0.12), 1.0)
					tx += 12.0
				y += 6.0
				row += 1
		1:   # lamiera ondulata
			var tx := 2.0
			while tx < s.x:
				draw_line(_pt(tx, 0), _pt(tx, roof_h), Color(0, 0, 0, 0.18), 1.5)
				draw_line(_pt(tx + 3.0, 0), _pt(tx + 3.0, roof_h), Color(1, 1, 1, 0.07), 1.0)
				tx += 9.0
		_:   # assi orizzontali
			var y := 8.0
			while y < roof_h:
				draw_line(_pt(-3, y), _pt(s.x + 3.0, y), Color(0, 0, 0, 0.22), 1.5)
				y += 10.0
	draw_rect(_r(-3, roof_h * 0.5 - 1.5, s.x + 6.0, 3.0), roof.darkened(0.35))
	draw_rect(rr, edge, false, 2.0)
	# Ombra della grondaia sul fronte.
	draw_rect(_r(0, roof_h, s.x, 5.0), Color(0, 0, 0, 0.30))

	# Comignolo e fumo.
	if s.x > 90.0:
		var chim := _pt(s.x * 0.78, roof_h * 0.28)
		draw_rect(Rect2(chim + Vector2(3, 3), Vector2(12, 14)), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(chim, Vector2(12, 14)), Color(0.50, 0.28, 0.22))
		draw_rect(Rect2(chim + Vector2(2, 2), Vector2(8, 6)), Color(0.12, 0.09, 0.08))
		draw_circle(chim + Vector2(8, -8), 5.0, Color(1, 1, 1, 0.14))
		draw_circle(chim + Vector2(13, -18), 7.0, Color(1, 1, 1, 0.10))
		draw_circle(chim + Vector2(20, -30), 9.0, Color(1, 1, 1, 0.07))

	# Porta sul fronte (stessa posizione di sempre).
	var door_w := 30.0
	var door_h := 24.0
	draw_rect(_r(cx - door_w * 0.5, s.y - door_h, door_w, door_h), edge)
	draw_rect(_r(cx - door_w * 0.5 + 3.0, s.y - door_h + 3.0, door_w - 6.0, door_h - 6.0), WesternTheme.color("wood"))
	draw_circle(_pt(cx + 8.0, s.y - door_h * 0.5), 1.8, gold)
	draw_rect(_r(cx - door_w * 0.5 - 2.0, s.y - door_h - 3.0, door_w + 4.0, 3.0), edge)

	# Finestre ai lati della porta (NightLights le accende alle stesse coordinate).
	for fx in [0.2, 0.8]:
		var wx: float = s.x * fx - 12.0
		draw_rect(_r(wx - 2.0, s.y - 23.0, 28.0, 3.0), edge)
		draw_rect(_r(wx, s.y - 20.0, 24.0, 16.0), edge)
		draw_rect(_r(wx + 2.0, s.y - 18.0, 20.0, 12.0), Color(0.95, 0.82, 0.45, 0.85))
		draw_rect(_r(wx + 2.0, s.y - 18.0, 20.0, 3.0), Color(1, 1, 1, 0.22))
		draw_line(_pt(wx + 12.0, s.y - 18.0), _pt(wx + 12.0, s.y - 6.0), edge, 1.5)
		draw_rect(_r(wx - 2.0, s.y - 4.0, 28.0, 3.0), wall.lightened(0.2))

	# Dettagli per tipo.
	match text:
		"SALOON":
			draw_rect(_r(cx - 13.0, s.y - 21.0, 13.0, 15.0), Color(0.78, 0.62, 0.40))
			draw_rect(_r(cx, s.y - 21.0, 13.0, 15.0), Color(0.72, 0.56, 0.36))
			for k in 4:
				draw_line(_pt(cx - 13.0 + float(k) * 6.5, s.y - 21.0), _pt(cx - 13.0 + float(k) * 6.5, s.y - 6.0), edge, 1.0)
		"BANCA":
			for sx in [cx - 24.0, cx + 20.0]:
				var px: float = sx
				draw_rect(_r(px, s.y - 24.0, 5.0, 24.0), Color(0.84, 0.82, 0.74))
				draw_rect(_r(px + 3.0, s.y - 24.0, 2.0, 24.0), Color(0, 0, 0, 0.18))
			draw_rect(_r(cx - 26.0, s.y - 28.0, 52.0, 3.0), gold)
		"SCERIFFO":
			var c := _pt(cx, roof_h - 12.0)
			var star := PackedVector2Array()
			for k in 10:
				var a := float(k) / 10.0 * TAU - PI * 0.5
				star.append(c + Vector2(cos(a), sin(a)) * (8.0 if k % 2 == 0 else 3.5))
			draw_colored_polygon(star, gold)
			draw_polyline(star + PackedVector2Array([star[0]]), edge, 1.0)

	# Insegna in mezzo al tetto.
	if text != "":
		var font := WesternTheme.get_font()
		var fs := 15
		var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bw := minf(tw + 20.0, s.x - 8.0)
		var by := _pt(0, roof_h * 0.5).y - 12.0
		draw_rect(Rect2((s.x - bw) * 0.5 + 3.0, by + 3.0, bw, 24), Color(0, 0, 0, 0.25))
		draw_rect(Rect2((s.x - bw) * 0.5, by, bw, 24), WesternTheme.color("wood"))
		draw_rect(Rect2((s.x - bw) * 0.5, by, bw, 24), gold, false, 2.0)
		draw_string(font, Vector2((s.x - bw) * 0.5, by + 17), text, HORIZONTAL_ALIGNMENT_CENTER, bw, fs, gold)

	draw_rect(Rect2(Vector2.ZERO, s), edge, false, 3.0)
