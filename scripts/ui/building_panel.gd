class_name BuildingPanel
extends WesternPanel
## UI dedicata di un edificio. Si costruisce da data/buildings.json:
## descrizione, soldi (e saldo bancario), pulsanti azione, bacheca ricercati e, per la banca
## ("bank_ui": true), la sezione deposito / debiti / prestiti (BankSection, Feature 17).
## Nota: va aggiunto all'albero con title != "" (es. " ") così WesternPanel
## riserva lo spazio del banner; il titolo vero lo imposta setup().

signal action_done(building_id: String, action_id: String, ok: bool)
signal exit_requested

var building_id := ""
var def: Dictionary = {}

var _money_label: Label
var _bank_label: Label
var _bank_section: BankSection
var _status: Label
var _action_buttons: Array = []   # [{button, action}] per aggiornare i prezzi dopo ogni acquisto


func setup(id: String, building_def: Dictionary) -> void:
	building_id = id
	def = building_def
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_bank_label = null
	_bank_section = null
	_action_buttons.clear()
	set_title(String(def.get("name", id)))
	custom_minimum_size = Vector2(470, 0)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	add_child(outer)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vb)

	var info := Label.new()
	info.text = String(def.get("function", ""))
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(430, 0)
	vb.add_child(info)
	vb.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var coin := WesternIcon.new()
	coin.kind = WesternIcon.Kind.COIN
	row.add_child(coin)
	_money_label = Label.new()
	row.add_child(_money_label)
	if def.get("show_bank", false):
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(24, 0)
		row.add_child(gap)
		var bag := WesternIcon.new()
		bag.kind = WesternIcon.Kind.BAG
		row.add_child(bag)
		_bank_label = Label.new()
		row.add_child(_bank_label)
	vb.add_child(row)

	if not BuildingActions.is_open(def):
		var closed := Label.new()
		closed.text = "Chiuso. Riapre alle %s." % BuildingActions.opening_text(def)
		vb.add_child(closed)
	else:
		for a in def.get("actions", []):
			var b := Button.new()
			b.text = _button_text(a)
			_action_buttons.append({"button": b, "action": a})
			b.tooltip_text = BuildingActions.action_tooltip(a)
			b.pressed.connect(_on_action.bind(a))
			vb.add_child(b)

	if def.get("bank_ui", false) and BuildingActions.is_open(def):
		_bank_section = BankSection.new()
		_bank_section.result.connect(_on_bank_result)
		vb.add_child(_bank_section)

	var wanted: Array = def.get("wanted", [])
	if not wanted.is_empty():
		vb.add_child(HSeparator.new())
		var head := Label.new()
		head.theme_type_variation = &"TitleLabel"
		head.text = "RICERCATI"
		var star := WesternIcon.new()
		star.kind = WesternIcon.Kind.STAR
		var hrow := HBoxContainer.new()
		hrow.add_child(star)
		hrow.add_child(head)
		vb.add_child(hrow)
		for w in wanted:
			var l := Label.new()
			l.text = "• %s — taglia $%d (%s)" % [w.get("name", "?"), int(w.get("reward", 0)), w.get("crime", "")]
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size = Vector2(430, 0)
			vb.add_child(l)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(430, 0)
	_status.add_theme_color_override("font_color", WesternTheme.color("gold"))
	outer.add_child(_status)

	var exit_btn := Button.new()
	exit_btn.text = "Esci  [Esc]"
	exit_btn.pressed.connect(func(): exit_requested.emit())
	outer.add_child(exit_btn)

	_refresh()
	# Il contenuto scorre se supera lo schermo (es. «Ricercati» in fondo); stato ed Esci restano visibili
	var max_h := get_viewport_rect().size.y * 0.9 - 170.0
	scroll.custom_minimum_size = Vector2(0, minf(vb.get_combined_minimum_size().y, max_h))
	reset_size()
	center_on_screen.call_deferred()


func center_on_screen() -> void:
	var vp := get_viewport_rect().size
	reset_size()
	position = ((vp - size) * 0.5).floor()
	position.y = maxf(position.y, 8.0)


func _button_text(a: Dictionary) -> String:
	var label := BuildingActions.action_label(a)
	if BuildingActions.action_cost(a) > 0:
		label += "  —  $%d" % BuildingActions.price(a)
	return label


func _refresh() -> void:
	for e in _action_buttons:
		if is_instance_valid(e["button"]):
			(e["button"] as Button).text = _button_text(e["action"])
	_money_label.text = "$%d" % BuildingActions.player_money()
	if _bank_label:
		_bank_label.text = "Saldo banca: $%d" % BankSystem.balance
	if _bank_section:
		_bank_section.refresh()


func _on_action(action: Dictionary) -> void:
	var r: Dictionary = BuildingActions.execute(action, def)
	_status.text = String(r.get("msg", ""))
	_refresh()
	if r.get("ok", false):
		UIFx.pop(_money_label)
	else:
		UIFx.shake(self)
	action_done.emit(building_id, String(action.get("id", "")), bool(r.get("ok", false)))


func _on_bank_result(msg: String, ok: bool) -> void:
	_status.text = msg
	_refresh()
	if ok:
		UIFx.pop(_money_label)
	else:
		UIFx.shake(self)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
