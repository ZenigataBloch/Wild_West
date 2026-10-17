class_name NPCManager
extends Node2D
## Genera, piazza e fa vivere i cittadini.
## Uso (dopo BuildingManager.spawn):
##   $NPCManager.spawn($BuildingManager.buildings, $BuildingManager.street_y)

signal npc_talked(npc_id: String)
signal slot_changed(slot_id: String)
signal duel_requested(npc_id: String)   # il mondo la collega a DuelManager.challenge_npc

@export var pause_game_while_open: bool = true

var scheduler: NPCScheduler

var _layer: CanvasLayer
var _panel: NPCPanel
var _dialogue: DialoguePanel


func spawn(buildings: Array, street_y: float) -> void:
	_clear()
	var list := NPCGenerator.generate(buildings, street_y)
	NPCRegistry.set_all(list)

	var ctx := _make_context(buildings, street_y)
	scheduler = NPCScheduler.new()
	add_child(scheduler)
	scheduler.slot_changed.connect(func(id: String): slot_changed.emit(id))

	for n in list:
		var avatar := NPCAvatar.new()
		add_child(avatar)
		avatar.setup(n)
		avatar.talk_requested.connect(_on_talk_requested)
		var routine := NPCRoutine.new()
		avatar.add_child(routine)
		routine.setup(avatar, n, ctx)
		scheduler.register(routine)

	_setup_ui()
	scheduler.force_check()   # posiziona subito tutti secondo l'ora attuale


func _make_context(buildings: Array, street_y: float) -> Dictionary:
	var x_min := -300.0
	var x_max := 300.0
	if not buildings.is_empty():
		x_min = INF
		x_max = -INF
		for b in buildings:
			var r: Rect2 = b["rect"]
			x_min = minf(x_min, r.position.x)
			x_max = maxf(x_max, r.end.x)
	return {"buildings": buildings, "street_y": street_y, "x_min": x_min, "x_max": x_max}


func _setup_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 20
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_panel = NPCPanel.new()
	_panel.title = " "   # riserva lo spazio del banner; il nome vero arriva da setup()
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_layer.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.exit_requested.connect(func(): _panel.close())
	_panel.closed.connect(_on_panel_closed)
	_panel.talk_requested.connect(_on_dialogue_requested)
	_panel.duel_requested.connect(_on_duel_requested)

	_dialogue = DialoguePanel.new()
	_dialogue.title = " "
	_dialogue.process_mode = Node.PROCESS_MODE_ALWAYS
	_dialogue.visible = false
	_layer.add_child(_dialogue)
	_dialogue.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_dialogue.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_dialogue.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dialogue.exit_requested.connect(func(): _dialogue.close())
	_dialogue.closed.connect(_on_panel_closed)


func _on_talk_requested(id: String) -> void:
	if _panel == null or _panel.visible or get_tree().paused:
		return
	_panel.setup(id)
	_panel.open()
	if pause_game_while_open:
		get_tree().paused = true
	npc_talked.emit(id)


func _on_dialogue_requested(id: String) -> void:
	if _dialogue == null or _dialogue.visible:
		return
	_panel.visible = false   # il gioco resta in pausa: si sblocca alla chiusura del dialogo
	_dialogue.setup(id)
	_dialogue.open()


func _on_duel_requested(id: String) -> void:
	_panel.visible = false
	if pause_game_while_open:
		get_tree().paused = false   # il DuelManager rimette in pausa da solo
	duel_requested.emit(id)


func _on_panel_closed() -> void:
	if pause_game_while_open:
		get_tree().paused = false


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	scheduler = null
	_layer = null
	_panel = null
	_dialogue = null
