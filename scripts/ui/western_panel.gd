class_name WesternPanel
extends PanelContainer
## Pannello riutilizzabile: cornice decorata, chiodi agli angoli,
## banner del titolo, texture (shader) e animazione di apertura/chiusura.
## Sarà la base di tutti i pannelli futuri (combattimento, lavori, gang...).

signal opened
signal closed

@export var title: String = ""
@export var paper_style: bool = false   ## true = interno pergamena
@export var use_grain: bool = true
@export var animate: bool = true

const GRAIN_SHADER := preload("res://shaders/paper_grain.gdshader")

var _tween: Tween


func _ready() -> void:
	theme = WesternTheme.get_theme()
	if paper_style:
		theme_type_variation = &"PaperPanel"
	var base: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
	var extra := int(WesternTheme.config()["panel"]["title_height"]) if title != "" else 0
	base.content_margin_top += extra
	add_theme_stylebox_override("panel", base)

	if use_grain:
		var mat := ShaderMaterial.new()
		mat.shader = GRAIN_SHADER
		var s: Dictionary = WesternTheme.config()["shader"]
		mat.set_shader_parameter("grain", float(s["grain"]))
		mat.set_shader_parameter("vignette", float(s["vignette"]))
		material = mat

	resized.connect(func(): pivot_offset = size * 0.5)
	pivot_offset = size * 0.5


func open() -> void:
	if _tween:
		_tween.kill()
	visible = true
	if not animate:
		opened.emit()
		return
	scale = Vector2(0.92, 0.92)
	modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	var t := float(WesternTheme.config()["panel"]["open_time"])
	_tween.tween_property(self, "scale", Vector2.ONE, t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "modulate:a", 1.0, t * 0.8)
	_tween.chain().tween_callback(func(): opened.emit())


func close() -> void:
	if _tween:
		_tween.kill()
	if not animate:
		visible = false
		closed.emit()
		return
	var t := float(WesternTheme.config()["panel"]["open_time"]) * 0.7
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "scale", Vector2(0.95, 0.95), t)
	_tween.tween_property(self, "modulate:a", 0.0, t)
	_tween.chain().tween_callback(func():
		visible = false
		closed.emit())


func set_title(value: String) -> void:
	title = value
	queue_redraw()


func _draw() -> void:
	var gold := WesternTheme.color("gold")
	var gold_d := WesternTheme.color("gold_dark")
	var w := size.x
	var h := size.y

	# Filetto interno
	draw_rect(Rect2(7, 7, w - 14, h - 14), gold_d, false, 1.5)

	# Angoli ornamentali ad L
	var L := 16.0
	for c in [Vector2(7, 7), Vector2(w - 7, 7), Vector2(7, h - 7), Vector2(w - 7, h - 7)]:
		var sx := 1.0 if c.x < w * 0.5 else -1.0
		var sy := 1.0 if c.y < h * 0.5 else -1.0
		draw_line(c, c + Vector2(L * sx, 0), gold, 3.0)
		draw_line(c, c + Vector2(0, L * sy), gold, 3.0)
		# chiodo
		var nail: Vector2 = c + Vector2(6 * sx, 6 * sy)
		draw_circle(nail, 3.2, gold_d)
		draw_circle(nail + Vector2(-0.8, -0.8), 1.2, gold.lightened(0.4))

	# Banner titolo
	if title != "":
		var font := get_theme_font("font", "TitleLabel")
		var fs := get_theme_font_size("font_size", "TitleLabel")
		var tw := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bw := minf(tw + 48.0, w - 40.0)
		var bx := (w - bw) * 0.5
		var by := -4.0
		var bh := float(WesternTheme.config()["panel"]["title_height"]) + 2.0
		draw_rect(Rect2(bx, by, bw, bh), WesternTheme.color("wood"))
		draw_rect(Rect2(bx, by, bw, bh), gold, false, 2.0)
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx - 12, by + 6), Vector2(bx, by + 6), Vector2(bx, by + bh - 6), Vector2(bx - 12, by + bh - 6), Vector2(bx - 6, by + bh * 0.5)
		]), WesternTheme.color("wood_dark"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(bx + bw + 12, by + 6), Vector2(bx + bw, by + 6), Vector2(bx + bw, by + bh - 6), Vector2(bx + bw + 12, by + bh - 6), Vector2(bx + bw + 6, by + bh * 0.5)
		]), WesternTheme.color("wood_dark"))
		draw_string(font, Vector2(bx, by + bh * 0.5 + fs * 0.35), title,
			HORIZONTAL_ALIGNMENT_CENTER, bw, fs, gold)
