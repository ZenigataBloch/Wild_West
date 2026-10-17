class_name CombatManager
extends Node2D
## Avvia e gestisce i combattimenti: imboscate casuali lontano dalla città, schermata dedicata
## (CombatPanel) con il gioco in pausa, esiti (bottino, reputazione, sconfitta).
## Uso:  var cm := CombatManager.new(); add_child(cm)
##       cm.message.connect(prompt_hud.show_message)
##       cm.setup(avatar, centro_citta)
##       cm.start_encounter(["bandito", "bandito"], "Imboscata!", true)
## Debug: X avvia un incontro casuale.

signal message(text: String)
signal combat_finished(result: String)

var avatar: CharacterBody2D
var origin := Vector2.ZERO
var in_combat := false

var _backdrop: ColorRect
var _panel: CombatPanel
var _acc := 0.0
var _cooldown := 30.0
var _pending: Array[String] = []
var _result := ""


func setup(p_avatar: CharacterBody2D, p_origin: Vector2) -> void:
	avatar = p_avatar
	origin = p_origin
	var layer := CanvasLayer.new()
	layer.layer = 30
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0, 0, 0, 0.72)
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.visible = false
	layer.add_child(_backdrop)

	_panel = CombatPanel.new()
	_panel.title = " "
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	layer.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.finished.connect(_on_finished)
	_panel.closed.connect(_on_closed)


func start_encounter(enemy_ids: Array, title: String, ambush: bool = false) -> void:
	if in_combat or _panel == null or enemy_ids.is_empty():
		return
	in_combat = true
	_backdrop.visible = true
	_panel.setup(enemy_ids, title, ambush)
	_panel.open()
	get_tree().paused = true


func start_random() -> void:
	var table: Array = CombatDB.encounters().get("table", [])
	if table.is_empty():
		return
	var total := 0
	for t in table:
		total += int(t.get("weight", 1))
	var roll := randi_range(1, maxi(1, total))
	for t in table:
		roll -= int(t.get("weight", 1))
		if roll <= 0:
			start_encounter(t.get("enemies", []), String(t.get("title", "Combattimento")), bool(t.get("ambush", false)))
			return


func _process(delta: float) -> void:
	if in_combat or avatar == null:
		return
	_cooldown = maxf(0.0, _cooldown - delta)
	_acc += delta
	var enc := CombatDB.encounters()
	if _acc < float(enc.get("check_interval", 3.0)):
		return
	_acc = 0.0
	if _cooldown > 0.0 or avatar.velocity.length() < 20.0 or int(PlayerState.health) <= 0:
		return
	if avatar.global_position.distance_to(origin) < float(enc.get("min_distance", 650.0)):
		return
	if randf() < float(enc.get("chance", 0.1)):
		start_random()


func _unhandled_key_input(e: InputEvent) -> void:
	if e.pressed and not e.echo and e.keycode == KEY_X:
		start_random()


func _on_finished(result: String) -> void:
	_result = result
	_pending = _panel.system.apply_results()
	if result == "lost":
		avatar.global_position = origin
		if GameTime.has_method("skip_to_hour"):
			GameTime.skip_to_hour(int(CombatDB.num("wake_hour", 7.0)))
	_panel.close()


func _on_closed() -> void:
	_backdrop.visible = false
	get_tree().paused = false
	in_combat = false
	_cooldown = float(CombatDB.encounters().get("cooldown", 120.0))
	if not _pending.is_empty():
		message.emit("\n".join(_pending))
	combat_finished.emit(_result)
