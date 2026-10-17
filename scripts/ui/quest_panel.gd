class_name QuestPanel
extends WesternPanel
## Diario delle missioni (basato su WesternPanel): missioni attive con stato e ricompensa.
## Va aggiunto all'albero con title != "" (es. " ") per riservare il banner.

signal exit_requested


func setup() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	set_title("Missioni")
	custom_minimum_size = Vector2(500, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	if QuestState.active.is_empty():
		var none := Label.new()
		none.text = "Nessuna missione attiva. Chiedi lavoro ai cittadini (\"Hai del lavoro per me?\")."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(460, 0)
		vb.add_child(none)
	for q in QuestState.active:
		var head := Label.new()
		head.text = "%s — %s" % [String(q["title"]), QuestDB.type_label(String(q["type"]))]
		head.add_theme_color_override("font_color", WesternTheme.color("gold"))
		vb.add_child(head)
		var body := Label.new()
		body.text = String(q["text"])
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.custom_minimum_size = Vector2(460, 0)
		vb.add_child(body)
		var st := Label.new()
		var status := QuestState.progress_text(q)
		if q["state"] == "ready":
			status = QuestState.ready_text(q, true)
		st.text = "%s   |   Ricompensa: %s" % [status, QuestState.reward_text(q)]
		st.modulate = Color(1, 1, 1, 0.75)
		vb.add_child(st)
		vb.add_child(HSeparator.new())

	var done := Label.new()
	done.text = "Missioni completate: %d" % QuestState.completed.size()
	vb.add_child(done)

	var exit_btn := Button.new()
	exit_btn.text = "Esci  [Esc]"
	exit_btn.pressed.connect(func(): exit_requested.emit())
	vb.add_child(exit_btn)
	reset_size()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
