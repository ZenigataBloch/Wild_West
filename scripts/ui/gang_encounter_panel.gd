class_name GangEncounterPanel
extends Control
## Incontro con una pattuglia o con il rifugio di una banda (Feature 19).
## Mostra il testo d'apertura e le opzioni disponibili per la stima attuale (tasti 1-9);
## dopo la scelta mostra l'esito e un pulsante "Continua" (Spazio/Invio).

signal option_chosen(gang_id: String, option_id: String)
signal closed

const INK := Color("2b1d12")
const PAPER := Color("d9c394")
const BORDER := Color("5a3a1c")

var _gang_id: String = ""
var _title: Label
var _subtitle: Label
var _body: Label
var _buttons: VBoxContainer
var _mode: String = "options"   # options | result
var _option_ids: Array = []


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", GangPanel.box(PAPER, BORDER, 4, 20))
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	_title = GangPanel.label("", 24, INK)
	root.add_child(_title)
	_subtitle = GangPanel.label("", 15, INK.lightened(0.25))
	root.add_child(_subtitle)
	root.add_child(HSeparator.new())

	_body = GangPanel.wrapped("", 16, INK)
	_body.custom_minimum_size = Vector2(560, 0)
	root.add_child(_body)

	_buttons = VBoxContainer.new()
	_buttons.add_theme_constant_override("separation", 6)
	root.add_child(_buttons)


func _ready() -> void:
	WesternTheme.apply(self)


## Apre l'incontro con la banda indicata.
func open_encounter(gang_id: String) -> void:
	var g: Dictionary = GangSystem.by_id(gang_id)
	if g.is_empty():
		return
	_gang_id = gang_id
	_title.text = "Banda «%s»" % g["name"]
	_title.add_theme_color_override("font_color", Color(str(g["color"])).darkened(0.25))
	_subtitle.text = "Stima verso di te: %s" % GangSystem.stance_label(g)
	_body.text = GangSystem.intro_text(gang_id)
	_show_options(GangSystem.options_for(gang_id))
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)


## La scelta non è andata a buon fine: mostra il motivo e lascia le opzioni.
func show_notice(text: String, options: Array) -> void:
	_body.text = text
	_show_options(options)


## Mostra l'esito e il pulsante per proseguire.
func show_result(text: String) -> void:
	_mode = "result"
	_body.text = text
	_clear_buttons()
	_option_ids = []
	var b := Button.new()
	b.text = "Continua [Spazio]"
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(_finish)
	_buttons.add_child(b)


func _show_options(options: Array) -> void:
	_mode = "options"
	_clear_buttons()
	_option_ids = []
	var i: int = 0
	for o in options:
		i += 1
		var b := Button.new()
		b.text = "%d. %s" % [i, str(o["label"])]
		b.tooltip_text = str(o["tip"])
		b.disabled = not bool(o["enabled"])
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_on_pressed.bind(str(o["id"])))
		_buttons.add_child(b)
		_option_ids.append(str(o["id"]) if bool(o["enabled"]) else "")


func _clear_buttons() -> void:
	for c in _buttons.get_children():
		_buttons.remove_child(c)
		c.queue_free()


func _on_pressed(option_id: String) -> void:
	if _mode != "options":
		return
	option_chosen.emit(_gang_id, option_id)


func _finish() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey):
		return
	var k := event as InputEventKey
	if not k.pressed or k.echo:
		return
	if _mode == "result":
		if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			_finish()
			get_viewport().set_input_as_handled()
		return
	var idx: int = int(k.keycode) - int(KEY_1)
	if idx >= 0 and idx < _option_ids.size() and str(_option_ids[idx]) != "":
		_on_pressed(str(_option_ids[idx]))
		get_viewport().set_input_as_handled()
