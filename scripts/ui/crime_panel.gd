class_name CrimePanel
extends Control
## Pannello "Malaffare" (Feature 20, tasto C). Costruito da codice con stile a carta.
## Il manager gli passa la lista delle azioni; il pannello emette action_chosen(indice).

signal action_chosen(index: int)
signal closed

const INK := Color(0.18, 0.10, 0.05)
const PAPER := Color(0.87, 0.78, 0.58)
const GOLD := Color(0.72, 0.53, 0.18)
const RED := Color(0.62, 0.12, 0.08)

var _mode: String = "menu"
var _title: Label
var _status: Label
var _scroll: ScrollContainer
var _list: VBoxContainer
var _footer: Label
var _hotkeys: Array = []
## Se false Esc e C non chiudono il menu (es. durante un arresto).
var closable: bool = true
## Se non vuoto sostituisce il piè di pagina del menu.
var footer_menu_text: String = ""
## Se false il testo di stato non è rosso (eventi).
var alert_status: bool = true


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.border_color = GOLD
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(4)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 12
	panel.add_theme_stylebox_override("panel", sb)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(side, 18)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_title = Label.new()
	_title.text = str(CrimeDB.section("ui").get("title", "MALAFFARE"))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 26)
	_title.add_theme_color_override("font_color", RED)
	box.add_child(_title)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", INK)
	box.add_child(_status)

	box.add_child(HSeparator.new())

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(_scroll)

	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 6)
	_scroll.add_child(_list)

	box.add_child(HSeparator.new())

	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_footer.add_theme_color_override("font_color", INK)
	box.add_child(_footer)


func set_title(text: String) -> void:
	_title.text = text


func _fit_scroll() -> void:
	var vp := get_viewport_rect().size
	_scroll.custom_minimum_size = Vector2(600, clampf(vp.y * 0.55, 220.0, 480.0))


func _clear() -> void:
	for c in _list.get_children():
		c.queue_free()
		_list.remove_child(c)


func _add_text(text: String, color: Color = INK, size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(580, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	_list.add_child(l)
	return l


# ---------------------------------------------------------------- menu

func open_menu(status: String, history: String, actions: Array) -> void:
	_mode = "menu"
	visible = true
	_fit_scroll()
	_status.text = status
	_status.add_theme_color_override("font_color", RED if alert_status and status != str(CrimeDB.section("ui").get("clean", "")) else INK)
	_footer.text = footer_menu_text if footer_menu_text != "" else str(CrimeDB.section("ui").get("footer_menu", ""))
	_clear()
	_hotkeys = []
	var groups: Dictionary = CrimeDB.section("ui").get("groups", {})
	var last_group := ""
	var n := 0
	for i in actions.size():
		var a: Dictionary = actions[i]
		var g := str(a.get("group", ""))
		if g != last_group:
			last_group = g
			var info: Dictionary = groups.get(g, {})
			_list.add_child(HSeparator.new())
			_add_text(str(info.get("title", g)), RED, 18)
			if str(info.get("desc", "")) != "":
				_add_text(str(info.get("desc", "")), INK, 13)
		var enabled := bool(a.get("enabled", false))
		var b := Button.new()
		var label := str(a.get("label", ""))
		if enabled and n < 9:
			n += 1
			label = "[%d] %s" % [n, label]
			_hotkeys.append(i)
		b.text = label
		b.tooltip_text = str(a.get("tip", ""))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not enabled
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if enabled:
			b.pressed.connect(_on_pick.bind(i))
		_list.add_child(b)
		if not enabled and str(a.get("tip", "")) != "" and str(a.get("tip", "")) != str(a.get("label", "")):
			_add_text(str(a.get("tip", "")), RED, 12)
	if history != "":
		_list.add_child(HSeparator.new())
		_add_text(str(CrimeDB.section("ui").get("history_title", "Ultimi colpi")), RED, 16)
		_add_text(history, INK, 13)


func _on_pick(index: int) -> void:
	action_chosen.emit(index)


# ---------------------------------------------------------------- esito

func show_result(title: String, lines: Array, ok: bool) -> void:
	_mode = "result"
	visible = true
	_fit_scroll()
	_status.text = title
	_status.add_theme_color_override("font_color", INK if ok else RED)
	_footer.text = str(CrimeDB.section("ui").get("footer_result", ""))
	_clear()
	for l in lines:
		_add_text(str(l), INK, 16)
	var b := Button.new()
	b.text = str(CrimeDB.section("ui").get("continue", "Continua"))
	b.pressed.connect(_finish)
	_list.add_child(b)
	b.grab_focus()


func _finish() -> void:
	visible = false
	closed.emit()


# ---------------------------------------------------------------- tastiera

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var k: int = event.keycode
	if k == KEY_ESCAPE or (_mode == "menu" and k == KEY_C):
		get_viewport().set_input_as_handled()
		if _mode == "menu" and not closable:
			return
		_finish()
		return
	if _mode == "result" and (k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE):
		get_viewport().set_input_as_handled()
		_finish()
		return
	if _mode == "menu" and k >= KEY_1 and k <= KEY_9:
		var idx := k - KEY_1
		if idx < _hotkeys.size():
			get_viewport().set_input_as_handled()
			_on_pick(int(_hotkeys[idx]))
