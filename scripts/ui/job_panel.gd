class_name JobPanel
extends Control
## Pannello dei lavori (tasto L): elenco mestieri, dettagli, rango, requisiti e turno di lavoro.

signal closed(pending_combat: Dictionary)
signal message(text: String)

const INK := Color(0.10, 0.07, 0.05)

var avatar: Node2D
var origin: Vector2 = Vector2.ZERO

var _selected: String = ""
var _result: Dictionary = {}
var _pending: Dictionary = {}   # scontro scatenato dall'ultimo turno
var _reveal: Array = []
var _reveal_t: float = 0.0
var _revealing: bool = false
var _log: Array[String] = []
var _rng := RandomNumberGenerator.new()

var _list: VBoxContainer
var _details: Label
var _status: Label
var _btn_hire: Button
var _btn_work: Button


func setup(av: Node2D, org: Vector2) -> void:
	avatar = av
	origin = org
	_rng.randomize()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	WesternTheme.apply(self)
	_build_ui()
	var order: Array = JobDB.order()
	_selected = JobState.current if JobState.current != "" else (str(order[0]) if not order.is_empty() else "")
	_refresh()


func _build_ui() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var card := PanelContainer.new()
	card.theme_type_variation = "PaperPanel"
	card.anchor_left = 0.5
	card.anchor_right = 0.5
	card.anchor_top = 0.5
	card.anchor_bottom = 0.5
	card.offset_left = -400
	card.offset_right = 400
	card.offset_top = -270
	card.offset_bottom = 270
	add_child(card)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	card.add_child(root)

	var title := Label.new()
	title.text = "LAVORI"
	title.theme_type_variation = "TitleLabel"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var cols := HBoxContainer.new()
	cols.size_flags_vertical = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 16)
	root.add_child(cols)

	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(230, 0)
	_list.add_theme_constant_override("separation", 6)
	cols.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_color_override("font_color", INK)
	right.add_child(_details)

	_status = Label.new()
	_status.add_theme_color_override("font_color", INK)
	root.add_child(_status)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	root.add_child(row)
	_btn_hire = Button.new()
	_btn_hire.custom_minimum_size = Vector2(200, 38)
	_btn_hire.pressed.connect(_on_hire)
	row.add_child(_btn_hire)
	_btn_work = Button.new()
	_btn_work.text = "Lavora un turno"
	_btn_work.custom_minimum_size = Vector2(200, 38)
	_btn_work.pressed.connect(_on_work)
	row.add_child(_btn_work)
	var close := Button.new()
	close.text = "Chiudi (Esc)"
	close.custom_minimum_size = Vector2(160, 38)
	close.pressed.connect(_close)
	row.add_child(close)


# ------------------------------------------------------------------ contenuto

func _refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	for id in JobDB.order():
		var j := JobDB.job(str(id))
		var b := Button.new()
		var mark := "★ " if JobState.current == id else ""
		var rk := JobSystem.rank_name(str(id))
		b.text = "%s%s  —  %s" % [mark, str(j.get("name", id)), rk]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.toggle_mode = true
		b.button_pressed = (id == _selected)
		b.custom_minimum_size = Vector2(0, 38)
		b.pressed.connect(_on_select.bind(str(id)))
		_list.add_child(b)

	var j2 := JobDB.job(_selected)
	if not _revealing and _log.is_empty():
		_details.text = _describe(j2)
	else:
		_details.text = "\n".join(_log)

	var is_current := (JobState.current == _selected)
	_btn_hire.text = "Lascia il lavoro" if is_current else "Prendi servizio"
	var chk := _check()
	_btn_work.disabled = _revealing or not bool(chk["ok"])
	_btn_work.tooltip_text = str(chk["reason"])
	_btn_hire.disabled = _revealing

	var cur := "nessuno"
	if JobState.current != "":
		cur = "%s (%s)" % [str(JobDB.job(JobState.current).get("name", "")), JobSystem.rank_name(JobState.current)]
	var hint := ""
	if not bool(chk["ok"]) and str(chk["reason"]) != "":
		hint = "   —   " + str(chk["reason"])
	_status.text = "Lavoro attuale: %s   |   Oggi: $%d   |   Totale guadagnato: $%d%s" % [
		cur, JobState.today_earned(), JobState.earned_total, hint]


func _check() -> Dictionary:
	if avatar == null or not is_instance_valid(avatar):
		return {"ok": false, "reason": ""}
	if not _pending.is_empty():
		return {"ok": false, "reason": "Prima devi affrontare lo scontro: chiudi il pannello."}
	return JobSystem.can_work(_selected, avatar.global_position, origin)


func _describe(j: Dictionary) -> String:
	if j.is_empty():
		return ""
	var w: Array = j.get("window", [0, 24])
	var area_names := {"town": "in città", "wilds": "fuori città", "any": "ovunque"}
	var area: String = str(area_names.get(str(j.get("area", "any")), "ovunque"))
	var lines: Array[String] = []
	lines.append(str(j.get("name", "")).to_upper())
	lines.append(str(j.get("desc", "")))
	lines.append("")
	lines.append("Rango: %s  (%s, %d turni svolti)" % [JobSystem.rank_name(_selected), JobSystem.next_rank_text(_selected), JobState.shifts_of(_selected)])
	lines.append("Paga base per turno: ~$%d  (statistica: %s)" % [JobSystem.pay_per_shift(_selected), str(j.get("stat", ""))])
	if str(j.get("good", "")) != "":
		lines.append("Mercato attuale (%s): %s." % [EconomySystem.good_label(str(j["good"])).to_lower(), EconomySystem.pct_text(str(j["good"]))])
	lines.append("Turno: %d ore, si inizia tra le %d:00 e le %d:00, %s." % [int(j.get("hours", 6)), int(w[0]), int(w[1]), area])
	var place: Dictionary = j.get("place", {})
	if not place.is_empty():
		lines.append("Luogo: devi trovarti presso %s." % str(place.get("label", "il luogo di lavoro")))
	if bool(j.get("needs_weapon", false)):
		lines.append("Richiede un'arma da fuoco in mano.")
	if int(j.get("min_money", 0)) > 0:
		lines.append("Richiede almeno $%d di capitale." % int(j.get("min_money", 0)))
	lines.append("")
	lines.append("Rischi: " + str(j.get("risks", "")))
	return "\n".join(lines)


# ------------------------------------------------------------------- azioni

func _on_select(id: String) -> void:
	if _revealing:
		return
	_selected = id
	_log.clear()
	_result = {}
	_refresh()


func _on_hire() -> void:
	if JobState.current == _selected:
		message.emit(JobDB.text("quit", {"job": str(JobDB.job(_selected).get("name", ""))}))
		JobState.current = ""
	else:
		JobState.current = _selected
		message.emit(JobDB.text("hired", {"job": str(JobDB.job(_selected).get("name", ""))}))
	_log.clear()
	_refresh()


func _on_work() -> void:
	var chk := _check()
	if not bool(chk["ok"]):
		return
	_result = JobSystem.run_shift(_selected, _rng)
	JobSystem.apply_result(_result, _rng)
	var cb = _result.get("combat", {})
	if cb is Dictionary and not cb.is_empty():
		_pending = cb
	_reveal = (_result.get("lines", []) as Array).duplicate()
	_log.clear()
	_revealing = true
	_reveal_t = 0.2
	_refresh()


func _process(delta: float) -> void:
	if not _revealing:
		return
	_reveal_t -= delta
	if _reveal_t > 0.0:
		return
	if _reveal.is_empty():
		_revealing = false
		_refresh()
		return
	_log.append(str(_reveal.pop_front()))
	_details.text = "\n".join(_log)
	_reveal_t = 0.7
	if _reveal.is_empty():
		_revealing = false
		_status.text = "Lavoro attuale: %s   |   Oggi: $%d   |   Totale guadagnato: $%d" % [
			str(JobDB.job(JobState.current).get("name", "nessuno")), JobState.today_earned(), JobState.earned_total]
		_btn_hire.disabled = false
		var chk := _check()
		_btn_work.disabled = not bool(chk["ok"])


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_ESCAPE or event.keycode == KEY_L):
		_close()
		accept_event()


func _close() -> void:
	closed.emit(_pending)
