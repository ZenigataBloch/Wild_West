class_name CombatPanel
extends WesternPanel
## Schermata di combattimento a turni (basata su WesternPanel): nemici con barre salute
## (clic per scegliere il bersaglio), registro degli eventi, salute del giocatore e azioni (tasti 1-5).
## Va aggiunto all'albero con title != "" (es. " ") per riservare il banner.

signal finished(result: String)

var system: CombatSystem

var _cards: Array[Dictionary] = []
var _target := 0
var _busy := false
var _log: Label
var _log_lines: Array[String] = []
var _player_bar: ProgressBar
var _player_label: Label
var _footer: VBoxContainer
var _buttons: Array[Button] = []
var _action_ids: Array[String] = []


func setup(enemy_ids: Array, title_text: String, ambush: bool) -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_cards.clear()
	_buttons.clear()
	_action_ids.clear()
	_log_lines.clear()
	_target = 0
	_busy = false
	set_title(title_text)
	custom_minimum_size = Vector2(760, 0)

	system = CombatSystem.new()
	var first := system.start(enemy_ids, ambush)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	# Nemici
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in system.enemies.size():
		var e: Dictionary = system.enemies[i]
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(170, 0)
		var b := Button.new()
		b.toggle_mode = true
		b.text = String(e["name"])
		b.pressed.connect(_select.bind(i))
		box.add_child(b)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = int(e["max_hp"])
		bar.value = int(e["hp"])
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 14)
		box.add_child(bar)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.text = "Salute %d/%d" % [int(e["hp"]), int(e["max_hp"])]
		box.add_child(l)
		row.add_child(box)
		_cards.append({"box": box, "button": b, "bar": bar, "label": l})
	vb.add_child(row)
	vb.add_child(HSeparator.new())

	# Registro
	var paper := PanelContainer.new()
	paper.theme_type_variation = &"PaperPanel"
	_log = Label.new()
	_log.theme_type_variation = &"InkLabel"
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size = Vector2(700, 120)
	paper.add_child(_log)
	vb.add_child(paper)

	# Giocatore
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 8)
	var hat := WesternIcon.new()
	hat.kind = WesternIcon.Kind.HAT
	prow.add_child(hat)
	_player_label = Label.new()
	_player_label.custom_minimum_size = Vector2(170, 0)
	prow.add_child(_player_label)
	_player_bar = ProgressBar.new()
	_player_bar.min_value = 0
	_player_bar.max_value = system.player_max
	_player_bar.value = system.player_hp
	_player_bar.show_percentage = false
	_player_bar.custom_minimum_size = Vector2(0, 16)
	_player_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	prow.add_child(_player_bar)
	vb.add_child(prow)
	_set_player_hp(system.player_hp)

	# Azioni
	_footer = VBoxContainer.new()
	vb.add_child(_footer)
	_build_actions()

	reset_size()
	_select(0)
	_play(first)


func _build_actions() -> void:
	for c in _footer.get_children():
		_footer.remove_child(c)
		c.queue_free()
	_buttons.clear()
	_action_ids.clear()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var n := 1
	for a in system.actions():
		var b := Button.new()
		b.text = "%d. %s" % [n, String(a["label"])]
		b.tooltip_text = String(a["hint"])
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_action.bind(String(a["id"])))
		row.add_child(b)
		_buttons.append(b)
		_action_ids.append(String(a["id"]))
		n += 1
	_footer.add_child(row)


func _refresh_actions() -> void:
	var list := system.actions()
	for i in _buttons.size():
		_buttons[i].disabled = _busy or not bool(list[i]["enabled"])


func _select(i: int) -> void:
	if i < 0 or i >= _cards.size() or int(system.enemies[i]["hp"]) <= 0:
		_ensure_target()
		return
	_target = i
	for j in _cards.size():
		(_cards[j]["button"] as Button).button_pressed = (j == _target)


func _ensure_target() -> void:
	if _target < _cards.size() and int(system.enemies[_target]["hp"]) > 0:
		(_cards[_target]["button"] as Button).button_pressed = true
		return
	for j in _cards.size():
		if int(system.enemies[j]["hp"]) > 0:
			_target = j
			break
	for j in _cards.size():
		(_cards[j]["button"] as Button).button_pressed = (j == _target and int(system.enemies[j]["hp"]) > 0)


func _on_action(id: String) -> void:
	if _busy or system.state != "player":
		return
	_play(system.do_player(id, _target))


func _play(events: Array) -> void:
	_busy = true
	_refresh_actions()
	for e in events:
		_add_log(String(e["text"]))
		_apply_event(e)
		await get_tree().create_timer(0.6).timeout
	_busy = false
	_ensure_target()
	if system.state != "player":
		_show_result()
	else:
		_refresh_actions()


func _apply_event(e: Dictionary) -> void:
	var who = e.get("who", "")
	var hp := int(e.get("hp", -1))
	var kind := String(e.get("kind", ""))
	if who is int and int(who) >= 0 and int(who) < _cards.size():
		var c: Dictionary = _cards[int(who)]
		if hp >= 0:
			(c["bar"] as ProgressBar).value = hp
			(c["label"] as Label).text = "Salute %d/%d" % [hp, int(system.enemies[int(who)]["max_hp"])]
			if hp <= 0:
				(c["button"] as Button).disabled = true
				(c["box"] as Control).modulate = Color(1, 1, 1, 0.35)
		if kind == "hit":
			UIFx.shake(c["box"])
	elif who is String and String(who) == "player":
		if hp >= 0:
			_set_player_hp(hp)
		if kind == "hit":
			UIFx.shake(self)
			UIFx.flash(_player_bar, Color(1.0, 0.35, 0.3), 0.3)
		elif kind == "heal":
			UIFx.pop(_player_label)


func _set_player_hp(hp: int) -> void:
	_player_bar.value = hp
	_player_label.text = "Salute %d/%d" % [hp, system.player_max]


func _add_log(text: String) -> void:
	_log_lines.append(text)
	while _log_lines.size() > 6:
		_log_lines.pop_front()
	_log.text = "\n".join(_log_lines)


func _show_result() -> void:
	for c in _footer.get_children():
		_footer.remove_child(c)
		c.queue_free()
	_buttons.clear()
	var l := Label.new()
	l.text = system.result_text()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(700, 0)
	l.add_theme_color_override("font_color", WesternTheme.color("gold"))
	_footer.add_child(l)
	var b := Button.new()
	b.text = "Continua"
	b.pressed.connect(func(): finished.emit(system.state))
	_footer.add_child(b)
	reset_size()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _busy or _buttons.is_empty():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var n: int = int(event.keycode) - KEY_1
		if n >= 0 and n < _buttons.size() and not _buttons[n].disabled:
			get_viewport().set_input_as_handled()
			_buttons[n].pressed.emit()
