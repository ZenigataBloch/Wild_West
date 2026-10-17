class_name ReputationPanel
extends WesternPanel
## Pannello reputazione (basato su WesternPanel): una barra per gruppo con fascia attuale.
## Va aggiunto all'albero con title != "" (es. " ") per riservare il banner.

signal exit_requested

var _rows: Dictionary = {}   # gruppo -> {bar, tier}
var _price: Label


func setup() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_rows.clear()
	set_title("Reputazione")
	custom_minimum_size = Vector2(460, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	var lo := float(ReputationSystem.data().get("min", -100))
	var hi := float(ReputationSystem.data().get("max", 100))
	for g in ReputationSystem.groups():
		var head := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = ReputationSystem.group_label(g)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(name_l)
		var tier_l := Label.new()
		head.add_child(tier_l)
		vb.add_child(head)
		var bar := ProgressBar.new()
		bar.min_value = lo
		bar.max_value = hi
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(420, 14)
		vb.add_child(bar)
		var desc := Label.new()
		desc.text = ReputationSystem.group_desc(g)
		desc.modulate = Color(1, 1, 1, 0.6)
		vb.add_child(desc)
		_rows[g] = {"bar": bar, "tier": tier_l}

	vb.add_child(HSeparator.new())
	_price = Label.new()
	vb.add_child(_price)

	var exit_btn := Button.new()
	exit_btn.text = "Esci  [Esc]"
	exit_btn.pressed.connect(func(): exit_requested.emit())
	vb.add_child(exit_btn)
	refresh()
	reset_size()


func refresh() -> void:
	for g in _rows:
		var v := ReputationSystem.value(g)
		_rows[g]["bar"].value = v
		_rows[g]["tier"].text = "%s (%+d)" % [ReputationSystem.tier_label(g), v]
	var m := ReputationSystem.price_mult()
	var pct := roundi((m - 1.0) * 100.0)
	_price.text = "Prezzi dei commercianti: %s" % ("nella norma" if pct == 0 else "%+d%%" % pct)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
