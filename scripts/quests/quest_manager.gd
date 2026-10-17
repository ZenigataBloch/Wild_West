class_name QuestManager
extends Node2D
## Fa vivere le missioni: crea gli oggetti nel mondo (recupero, caccia), conta la protezione,
## mostra il tracker in alto a destra e apre il diario con il tasto Q.
## Uso (dopo NPCManager.spawn):
##   var qm := QuestManager.new(); add_child(qm)
##   qm.message.connect(prompt_hud.show_message)
##   qm.setup(avatar, bounds, origin, rettangoli_da_evitare)

signal message(text: String)

@export var pause_game_while_open: bool = true

var avatar: Node2D
var bounds: Rect2
var origin: Vector2
var avoid: Array[Rect2] = []

var _props: Dictionary = {}   # id missione -> Array[Node]
var _tracker: Label
var _panel: QuestPanel
var _seen_version := -1
var _combat: CombatManager
var _hunt: Dictionary = {}   # caccia in corso: {q, prop}
var _acc := 0.0


func setup(p_avatar: Node2D, p_bounds: Rect2, p_origin: Vector2, p_avoid: Array[Rect2]) -> void:
	QuestState.reset()
	avatar = p_avatar
	bounds = p_bounds
	origin = p_origin
	avoid = p_avoid
	_setup_ui()


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_tracker = Label.new()
	_tracker.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_tracker.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_tracker.offset_left = -360.0
	_tracker.offset_right = -16.0
	_tracker.offset_top = 12.0
	_tracker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_tracker.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tracker.add_theme_font_size_override("font_size", 16)
	_tracker.add_theme_color_override("font_outline_color", Color.BLACK)
	_tracker.add_theme_constant_override("outline_size", 5)
	_tracker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_tracker)

	_panel = QuestPanel.new()
	_panel.title = " "
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	layer.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.exit_requested.connect(func(): _panel.close())
	_panel.closed.connect(func():
		if pause_game_while_open:
			get_tree().paused = false)


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.pressed or e.echo or e.keycode != KEY_Q or _panel == null:
		return
	if _panel.visible:
		_panel.close()
	elif not get_tree().paused:
		_panel.setup()
		_panel.open()
		if pause_game_while_open:
			get_tree().paused = true


func _process(delta: float) -> void:
	if QuestState.version != _seen_version:
		_seen_version = QuestState.version
		_sync()
		_refresh_tracker()
	if get_tree().paused:
		return
	_update_protection(delta)
	_acc += delta
	if _acc >= 0.5:
		_acc = 0.0
		_refresh_tracker()


# --- oggetti nel mondo ---

func _sync() -> void:
	var alive := {}
	for q in QuestState.active:
		if q["state"] == "active" and (q["type"] == "retrieval" or q["type"] == "hunt"):
			alive[q["id"]] = true
			if not _props.has(q["id"]):
				_spawn_props(q)
	for id in _props.keys():
		if not alive.has(id):
			for p in _props[id]:
				if is_instance_valid(p):
					p.queue_free()
			_props.erase(id)


func _spawn_props(q: Dictionary) -> void:
	var rng: RandomNumberGenerator = WorldSeed.rng_for("quest_pos_%s" % q["id"])
	var list: Array = []
	var n := 1 if q["type"] == "retrieval" else int(q["goal"])
	for i in n:
		var p := QuestProp.new()
		p.quest_id = String(q["id"])
		p.position = _random_point(rng)
		if q["type"] == "retrieval":
			p.kind = "item"
			p.prompt = "Raccogli %s" % String(q["item"])
			p.interacted.connect(_on_item.bind(q, p))
		else:
			p.kind = "animal"
			p.prompt = "Affronta: %s" % String(q["animal"])
			p.radius = 80.0
			p.interacted.connect(_on_animal.bind(q, p))
		add_child(p)
		list.append(p)
	_props[q["id"]] = list


func _random_point(rng: RandomNumberGenerator) -> Vector2:
	var dist: Array = QuestDB.data().get("spawn_distance", [450, 1100])
	var area := bounds.grow(-80.0)
	for i in 60:
		var a := rng.randf_range(0.0, TAU)
		var d := rng.randf_range(float(dist[0]), float(dist[1]))
		var pt := origin + Vector2(cos(a), sin(a)) * d
		if not area.has_point(pt):
			continue
		var bad := false
		for r in avoid:
			if r.grow(50.0).has_point(pt):
				bad = true
				break
		if not bad:
			return pt
	return origin + Vector2(float(dist[0]), 0.0)


func _on_item(q: Dictionary, prop: Node) -> void:
	if q["state"] != "active":
		return
	prop.queue_free()
	q["progress"] = 1
	QuestState.set_ready(q)
	message.emit("Hai recuperato %s. Riportalo a %s." % [String(q["item"]), String(q["giver_name"]).split(" ")[0]])


## La caccia usa il sistema di combattimento a turni (Feature 11): serve vincere lo scontro.
func set_combat(cm: CombatManager) -> void:
	_combat = cm
	if _combat != null and not _combat.combat_finished.is_connected(_on_hunt_finished):
		_combat.combat_finished.connect(_on_hunt_finished)


func _on_animal(q: Dictionary, prop: Node) -> void:
	if q["state"] != "active" or not _hunt.is_empty():
		return
	if _combat == null or _combat.in_combat:
		return
	_hunt = {"q": q, "prop": prop}
	_combat.start_encounter([String(q["animal"])], "Caccia: %s" % String(q["animal"]), false)


func _on_hunt_finished(result: String) -> void:
	if _hunt.is_empty():
		return
	var q: Dictionary = _hunt["q"]
	var prop = _hunt["prop"]
	_hunt = {}
	if result == "fled":
		message.emit("Il %s ti è sfuggito. Puoi riprovare." % String(q["animal"]))
		return
	if result != "won" or q["state"] != "active":
		return
	if is_instance_valid(prop):
		prop.queue_free()
	q["progress"] = int(q["progress"]) + 1
	if int(q["progress"]) >= int(q["goal"]):
		QuestState.set_ready(q)
		message.emit("Caccia finita. Torna da %s." % String(q["giver_name"]).split(" ")[0])
	else:
		QuestState.version += 1
		message.emit("Preso! (%d/%d)" % [int(q["progress"]), int(q["goal"])])


# --- protezione ---

func _update_protection(delta: float) -> void:
	if avatar == null:
		return
	var radius := float(QuestDB.data().get("protect_radius", 160.0))
	for q in QuestState.active:
		if q["type"] != "protection" or q["state"] != "active":
			continue
		var npc := NPCRegistry.get_npc(String(q["target"]))
		if npc.is_empty() or String(npc.get("inside", "")) != "":
			continue
		var npos: Vector2 = npc["position"]
		if avatar.global_position.distance_to(npos) <= radius:
			q["progress"] = float(q["progress"]) + delta
			if float(q["progress"]) >= float(q["goal"]):
				q["progress"] = q["goal"]
				QuestState.set_ready(q)
				message.emit("%s è al sicuro. Torna da %s." % [String(q["target_name"]).split(" ")[0], String(q["giver_name"]).split(" ")[0]])


# --- tracker ---

func _refresh_tracker() -> void:
	if _tracker == null:
		return
	var lines: Array[String] = []
	for q in QuestState.active:
		var line := "• %s" % String(q["title"])
		if q["state"] == "ready":
			line += " — " + QuestState.ready_text(q)
		else:
			line += " — " + QuestState.progress_text(q)
		lines.append(line)
	_tracker.text = "\n".join(lines)
	_tracker.visible = not lines.is_empty()
