class_name MarketPanel
extends WesternPanel
## Pannello del mercato locale (basato su WesternPanel): indice prezzo di ogni bene, tendenza e notizia.
## Va aggiunto all'albero con title != "" (es. " ") per riservare il banner.

signal exit_requested


func setup() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	set_title("Mercato")
	custom_minimum_size = Vector2(500, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	add_child(vb)

	var intro := Label.new()
	intro.text = "Prezzi di oggi rispetto alla norma. I tuoi acquisti li fanno salire, il tuo lavoro li fa scendere."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(460, 0)
	intro.modulate = Color(1, 1, 1, 0.7)
	vb.add_child(intro)
	vb.add_child(HSeparator.new())

	for g in EconomySystem.good_ids():
		var row := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = EconomySystem.good_label(g)
		name_l.tooltip_text = EconomySystem.good_desc(g)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_l)
		var arrow: String = ["▼", "=", "▲"][EconomySystem.trend(g) + 1]
		var val := Label.new()
		val.text = "%s  %s" % [EconomySystem.pct_text(g), arrow]
		val.custom_minimum_size = Vector2(130, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var good_for_player := (EconomySystem.index(g) < 0.97) if EconomySystem.good_kind(g) == "buy" else (EconomySystem.index(g) > 1.03)
		var bad_for_player := (EconomySystem.index(g) > 1.03) if EconomySystem.good_kind(g) == "buy" else (EconomySystem.index(g) < 0.97)
		if good_for_player:
			val.add_theme_color_override("font_color", Color("#7fbf6a"))
		elif bad_for_player:
			val.add_theme_color_override("font_color", Color("#d9694f"))
		row.add_child(val)
		vb.add_child(row)

	vb.add_child(HSeparator.new())
	var news := Label.new()
	var n := EconomySystem.news()
	news.text = n if n != "" else "Nessuna notizia dal mercato."
	news.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	news.custom_minimum_size = Vector2(460, 0)
	vb.add_child(news)

	var exit_btn := Button.new()
	exit_btn.text = "Esci  [Esc]"
	exit_btn.pressed.connect(func(): exit_requested.emit())
	vb.add_child(exit_btn)
	reset_size()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
