class_name GameMenu
extends Node
## Menu di gioco e comandi (Feature 26). F1 lo apre e lo chiude; il testo viene da data/help.json.
## Pulsanti: Riprendi, Salva, Carica. Salva e Carica chiudono il menu e chiedono l'azione a World.

signal save_requested
signal load_requested

const PATH := "res://data/help.json"
const KEY := KEY_F1

var _layer: CanvasLayer
var _open: bool = false
var _paused_by_me: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var cfg: Dictionary = {}
	if FileAccess.file_exists(PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if parsed is Dictionary:
			cfg = parsed
	_layer = CanvasLayer.new()
	_layer.layer = 80
	_layer.visible = false
	add_child(_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)
	WesternTheme.apply(center)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = WesternTheme.color("parchment")
	sb.border_color = WesternTheme.color("wood")
	sb.set_border_width_all(5)
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(22)
	card.add_theme_stylebox_override("panel", sb)
	center.add_child(card)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(480, 0)
	box.add_theme_constant_override("separation", 8)
	card.add_child(box)

	var ink := WesternTheme.color("ink")
	box.add_child(_label(str(cfg.get("title", "WILD WEST")), 40, ink, true))
	box.add_child(_label(str(cfg.get("subtitle", "")), 18, WesternTheme.color("gold_dark"), true))
	for sec in cfg.get("sections", []):
		box.add_child(_label(str(sec.get("title", "")).to_upper(), 20, WesternTheme.color("blood"), false))
		for line in sec.get("lines", []):
			box.add_child(_label("   " + str(line), 17, ink, false))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	row.add_child(_button("Riprendi [F1]", _close))
	row.add_child(_button("Salva [F5]", func(): _close(); save_requested.emit()))
	row.add_child(_button("Carica [F6]", func(): _close(); load_requested.emit()))


func _label(text: String, size: int, color: Color, centered: bool) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if centered:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	return b


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.pressed or e.echo or e.keycode != KEY:
		return
	if _open:
		_close()
	elif not get_tree().paused and PlayerState.health > 0:
		_open = true
		_layer.visible = true
		_paused_by_me = true
		get_tree().paused = true
	get_viewport().set_input_as_handled()


func _close() -> void:
	_open = false
	_layer.visible = false
	if _paused_by_me:
		get_tree().paused = false
	_paused_by_me = false
