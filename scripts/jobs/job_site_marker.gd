class_name JobSiteMarker
extends Node2D
## Segnale nel mondo di un luogo di lavoro fuori città (la miniera): ingresso di galleria con travi e nome.

var label_text := "Miniera"


func _ready() -> void:
	z_index = 1
	var l := Label.new()
	WesternTheme.apply(l)
	l.text = label_text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(160, 0)
	l.position = Vector2(-80, -64)
	add_child(l)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-30, -34, 60, 38), Color("#2a1b10"))               # imbocco scuro
	draw_rect(Rect2(-34, -38, 6, 44), Color("#6b4a2b"))                # trave sinistra
	draw_rect(Rect2(28, -38, 6, 44), Color("#6b4a2b"))                 # trave destra
	draw_rect(Rect2(-36, -42, 72, 8), Color("#8a5a2b"))                # architrave
	draw_rect(Rect2(-36, -42, 72, 8), Color("#3b2614"), false, 2.0)
	draw_circle(Vector2(46, 4), 9, Color("#7d746a"))                   # mucchio di detriti
	draw_circle(Vector2(38, 7), 6, Color("#9a9086"))
