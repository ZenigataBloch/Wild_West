class_name GangPanel
extends Control
## Pannello "Bande e reputazione" (Feature 19). Si apre con N, si chiude con Esc o N.
## Stile western a carta, costruito da codice; usa WesternTheme per font e pulsanti.

signal closed

const INK := Color("2b1d12")
const PAPER := Color("d9c394")
const PAPER_DARK := Color("c7ad78")
const BORDER := Color("5a3a1c")

var _origin: Vector2 = Vector2.ZERO
var _scroll: ScrollContainer
var _content: VBoxContainer


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", box(PAPER, BORDER, 4, 18))
	center.add_child(panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	panel.add_child(root)

	root.add_child(label("BANDE DEL DESERTO", 26, INK))
	root.add_child(label("Chi comanda dove, e che cosa pensano di te.", 14, INK.lightened(0.25)))

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(_scroll)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	_scroll.add_child(_content)

	var close_btn := Button.new()
	close_btn.text = "Chiudi [Esc]"
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.pressed.connect(close)
	root.add_child(close_btn)


func _ready() -> void:
	WesternTheme.apply(self)


func open(origin: Vector2) -> void:
	_origin = origin
	var vp: Vector2 = get_viewport_rect().size
	_scroll.custom_minimum_size = Vector2(700.0, clampf(vp.y - 230.0, 240.0, 520.0))
	_refresh()
	visible = true
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 1.0, 0.15)


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and (k.keycode == KEY_ESCAPE or k.keycode == KEY_N):
			close()
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ contenuto

func _refresh() -> void:
	for c in _content.get_children():
		c.queue_free()

	var group_text: String = "Reputazione generale presso le bande: %s (%d)" % [
		str(ReputationSystem.tier_label("gang")), int(round(float(ReputationSystem.value("gang"))))]
	_content.add_child(wrapped(group_text, 15, INK))

	if GangSystem.gangs.is_empty():
		_content.add_child(wrapped("Nel deserto non c'è più nessuna banda organizzata. Ma presto qualcuno si farà avanti.", 15, INK))
	for g in GangSystem.gangs:
		_add_card(g)

	_content.add_child(label("VOCI DAL TERRITORIO", 18, INK))
	if GangSystem.news.is_empty():
		_content.add_child(wrapped("Nessuna notizia, per ora.", 14, INK.lightened(0.25)))
	else:
		var shown: int = 0
		for i in range(GangSystem.news.size() - 1, -1, -1):
			var n: Dictionary = GangSystem.news[i]
			_content.add_child(wrapped("Giorno %d: %s" % [int(n["day"]), str(n["text"])], 14, INK))
			shown += 1
			if shown >= 8:
				break


func _add_card(g: Dictionary) -> void:
	var col := Color(str(g["color"]))
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", box(PAPER_DARK, col, 3, 10))
	_content.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var flag := ColorRect.new()
	flag.color = col
	flag.custom_minimum_size = Vector2(14, 24)
	head.add_child(flag)
	head.add_child(label("«%s»" % g["name"], 20, INK))
	var st: Label = label("— %s" % GangSystem.stance_label(g), 16, col.darkened(0.2))
	head.add_child(st)

	# barra reputazione
	var rep: float = GangSystem.effective_rep(g)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	var bar := ProgressBar.new()
	bar.min_value = -100.0
	bar.max_value = 100.0
	bar.value = rep
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(300, 16)
	bar.add_theme_stylebox_override("background", box(Color(0.25, 0.18, 0.1), BORDER, 1, 0))
	var stance: String = GangSystem.stance(g)
	var fill_color := Color(0.65, 0.2, 0.15) if stance == "hostile" else (Color(0.3, 0.55, 0.25) if stance == "friendly" else Color(0.6, 0.5, 0.2))
	bar.add_theme_stylebox_override("fill", box(fill_color, fill_color, 0, 0))
	row.add_child(bar)
	row.add_child(label("Stima verso di te: %+d" % int(round(rep)), 14, INK))

	# dettagli, solo per quello che il giocatore conosce
	if bool(g["discovered"]):
		var dir: String = GangSystem.direction_text(g["hideout"])
		v.add_child(wrapped("Rifugio: a %s della città, a circa %d passi. Territorio di raggio %d." % [
			dir, GangSystem.distance_from_town(g), int(round(GangSystem.radius_of(g)))], 14, INK))
		var members: Array = g["members"]
		v.add_child(wrapped("Uomini: %d — capo: %s. Forza: %d." % [
			members.size(), str(g["boss"]), int(round(GangSystem.strength(g) * 10.0))], 14, INK))
	elif bool(g["rumored"]):
		v.add_child(wrapped("Voci: sembra annidata a %s della città. Non l'hai ancora trovata." % GangSystem.direction_text(g["hideout"]), 14, INK))
	else:
		v.add_child(wrapped("Posizione sconosciuta: esplora il deserto, o ascolta le voci.", 14, INK))

	if bool(g["known_goal"]):
		v.add_child(wrapped("Obiettivo: %s." % GangSystem.goal_label(g), 14, INK))
		v.add_child(wrapped("Nemici: %s." % GangSystem.enemy_names(g), 14, INK))
	else:
		v.add_child(wrapped("Obiettivi e nemici: ignoti (parla con loro, o chiedi in giro se sono amici).", 14, INK.lightened(0.2)))


# ------------------------------------------------------------------ helper di stile (usati anche dal pannello incontri)

static func box(bg: Color, border: Color, border_w: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(4)
	s.content_margin_left = float(margin)
	s.content_margin_right = float(margin)
	s.content_margin_top = float(margin)
	s.content_margin_bottom = float(margin)
	return s


static func label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrapped(text: String, size: int, color: Color) -> Label:
	var l: Label = label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(640, 0)
	return l
