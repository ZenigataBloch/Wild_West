class_name NPCPanel
extends WesternPanel
## Scheda di un cittadino (basata su WesternPanel).
## Mostra nome, lavoro, ruolo, età, luogo di lavoro, statistiche e relazione.
## Il pulsante "Parla" apre la conversazione (DialoguePanel, Feature 8).
## Va aggiunto all'albero con title != "" (es. " ") per riservare il banner.

signal exit_requested
signal talk_requested(npc_id: String)
signal duel_requested(npc_id: String)

var npc_id := ""

var _rel_bar: ProgressBar
var _rel_label: Label


func setup(id: String) -> void:
	npc_id = id
	var npc := NPCRegistry.get_npc(id)
	if npc.is_empty():
		return
	for c in get_children():
		remove_child(c)
		c.queue_free()
	set_title(String(npc["name"]))
	custom_minimum_size = Vector2(440, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	# Lavoro e ruolo
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	var hat := WesternIcon.new()
	hat.kind = WesternIcon.Kind.HAT
	head.add_child(hat)
	var job := Label.new()
	job.text = "%s — %s, %d anni" % [npc["job_label"], npc["role"], int(npc["age"])]
	head.add_child(job)
	vb.add_child(head)

	var wp := String(npc["workplace"])
	if wp != "":
		var w := Label.new()
		w.text = "Lavora presso: %s" % String(BuildingDB.get_type(wp).get("name", wp))
		vb.add_child(w)

	var act := NPCRoutineDB.activity_text(String(npc.get("activity", "")))
	if act != "":
		var al := Label.new()
		al.text = "Ora: %s" % act
		vb.add_child(al)

	vb.add_child(HSeparator.new())

	# Statistiche
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 4)
	for s in NPCDB.data().get("stat_names", []):
		var l := Label.new()
		l.text = NPCDB.stat_label(s)
		l.custom_minimum_size = Vector2(110, 0)
		grid.add_child(l)
		var bar := ProgressBar.new()
		bar.min_value = 0
		bar.max_value = 10
		bar.value = int(npc["stats"].get(s, 0))
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(200, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(bar)
	vb.add_child(grid)

	vb.add_child(HSeparator.new())

	# Relazione
	var rel_row := HBoxContainer.new()
	rel_row.add_theme_constant_override("separation", 10)
	var star := WesternIcon.new()
	star.kind = WesternIcon.Kind.STAR
	rel_row.add_child(star)
	_rel_label = Label.new()
	_rel_label.custom_minimum_size = Vector2(120, 0)
	rel_row.add_child(_rel_label)
	_rel_bar = ProgressBar.new()
	var r: Dictionary = NPCDB.data().get("relationship", {})
	_rel_bar.min_value = float(r.get("min", -100))
	_rel_bar.max_value = float(r.get("max", 100))
	_rel_bar.show_percentage = false
	_rel_bar.custom_minimum_size = Vector2(200, 14)
	_rel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rel_row.add_child(_rel_bar)
	vb.add_child(rel_row)

	var talk := Button.new()
	talk.text = "Parla"
	talk.pressed.connect(func(): talk_requested.emit(npc_id))
	vb.add_child(talk)

	# Sfida a duello (Feature 14): non per chi non duella (lo sceriffo).
	if not DuelSystem.from_npc(npc).is_empty():
		var duel := Button.new()
		duel.text = "Sfida a duello"
		duel.tooltip_text = "Serve un'arma da fuoco in mano. La posta e la reputazione dipendono dall'avversario."
		duel.pressed.connect(func(): duel_requested.emit(npc_id))
		vb.add_child(duel)

	var exit_btn := Button.new()
	exit_btn.text = "Esci  [Esc]"
	exit_btn.pressed.connect(func(): exit_requested.emit())
	vb.add_child(exit_btn)

	_refresh()
	reset_size()


func _refresh() -> void:
	var npc := NPCRegistry.get_npc(npc_id)
	var rel := int(npc.get("relationship", 0))
	_rel_bar.value = rel
	_rel_label.text = NPCRegistry.relationship_label(rel)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
