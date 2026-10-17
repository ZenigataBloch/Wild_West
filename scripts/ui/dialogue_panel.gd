class_name DialoguePanel
extends WesternPanel
## Pannello di conversazione (basato su WesternPanel).
## Il testo dell'NPC appare a "macchina da scrivere" su un riquadro di carta;
## le scelte sono pulsanti selezionabili anche con i tasti 1-9.
## Spazio / Invio / clic sul testo saltano l'animazione. Esc chiude.
## Va aggiunto all'albero con title != "" (es. " ") per riservare il banner.

signal exit_requested

var npc_id := ""

var _runner := DialogueRunner.new()
var _text: Label
var _status: Label
var _rel_label: Label
var _choices_box: VBoxContainer
var _buttons: Array[Button] = []
var _pending: Array = []
var _typing: Tween
var _choices_built := false


func setup(id: String) -> void:
	npc_id = id
	var npc := NPCRegistry.get_npc(id)
	if npc.is_empty():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()
	set_title(String(npc["name"]))
	custom_minimum_size = Vector2(500, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	# Intestazione: lavoro e relazione
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var hat := WesternIcon.new()
	hat.kind = WesternIcon.Kind.HAT
	head.add_child(hat)
	var job := Label.new()
	job.text = "%s — %s" % [npc["job_label"], npc["role"]]
	job.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(job)
	var star := WesternIcon.new()
	star.kind = WesternIcon.Kind.STAR
	head.add_child(star)
	_rel_label = Label.new()
	head.add_child(_rel_label)
	vb.add_child(head)

	# Riquadro di carta con la battuta dell'NPC
	var paper := PanelContainer.new()
	paper.theme_type_variation = &"PaperPanel"
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	paper.gui_input.connect(_on_paper_input)
	_text = Label.new()
	_text.theme_type_variation = &"InkLabel"
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(440, 84)
	paper.add_child(_text)
	vb.add_child(paper)

	# Esiti dell'ultima scelta
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(440, 0)
	_status.add_theme_color_override("font_color", WesternTheme.color("gold"))
	vb.add_child(_status)

	vb.add_child(HSeparator.new())

	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", 6)
	vb.add_child(_choices_box)

	_runner = DialogueRunner.new()
	_runner.start(npc)
	_show_node()
	reset_size()


func _show_node() -> void:
	if _runner.finished:
		exit_requested.emit()
		return
	var cur := _runner.current()
	_pending = cur["choices"]
	_choices_built = false
	_clear_choices()
	_text.text = String(cur["text"])
	_status.text = "\n".join(_runner.messages)
	_refresh_relationship()

	_text.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	var dur := clampf(_text.text.length() * 0.018, 0.25, 2.5)
	_typing = create_tween()
	_typing.tween_property(_text, "visible_ratio", 1.0, dur)
	_typing.finished.connect(_build_choices)


func _build_choices() -> void:
	if _choices_built:
		return
	_choices_built = true
	_clear_choices()
	if _pending.is_empty():
		var b := Button.new()
		b.text = "Chiudi"
		b.pressed.connect(func(): exit_requested.emit())
		_choices_box.add_child(b)
		_buttons.append(b)
		return
	for i in _pending.size():
		var c: Dictionary = _pending[i]
		var b := Button.new()
		b.text = "%d. %s" % [i + 1, c["text"]]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not bool(c["enabled"])
		b.pressed.connect(_on_choice.bind(int(c["index"])))
		_choices_box.add_child(b)
		_buttons.append(b)
	reset_size()


func _clear_choices() -> void:
	_buttons.clear()
	for c in _choices_box.get_children():
		_choices_box.remove_child(c)
		c.queue_free()


func _on_choice(index: int) -> void:
	_runner.choose(index)
	if _runner.finished and _runner.messages.is_empty():
		exit_requested.emit()
		return
	if _runner.finished:
		# Mostra gli esiti finali prima di chiudere
		_status.text = "\n".join(_runner.messages)
		_clear_choices()
		_refresh_relationship()
		var b := Button.new()
		b.text = "Chiudi"
		b.pressed.connect(func(): exit_requested.emit())
		_choices_box.add_child(b)
		_buttons.append(b)
		_pending = []
		_text.visible_ratio = 1.0
		return
	_show_node()
	if not _runner.messages.is_empty():
		UIFx.flash(_status, WesternTheme.color("gold").lightened(0.5), 0.5)


func _refresh_relationship() -> void:
	var rel := int(NPCRegistry.get_npc(npc_id).get("relationship", 0))
	_rel_label.text = NPCRegistry.relationship_label(rel)


func _skip_typing() -> void:
	if _typing:
		_typing.kill()
	_text.visible_ratio = 1.0
	_build_choices()


func _on_paper_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_skip_typing()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
		return
	if event.is_action_pressed("ui_accept") and not _choices_built:
		get_viewport().set_input_as_handled()
		_skip_typing()
		return
	if event is InputEventKey and event.pressed and not event.echo and _choices_built:
		var n: int = int(event.keycode) - KEY_1
		if n >= 0 and n < 9 and n < _buttons.size() and not _buttons[n].disabled:
			get_viewport().set_input_as_handled()
			_buttons[n].pressed.emit()
