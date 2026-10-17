class_name LawManager
extends Node
## Sistema legge (Feature 21). Con notorietà alta lo sceriffo manda i vice a cercare il giocatore
## (PosseView). Se ti raggiungono si apre il confronto: paga la taglia, corrompi, fuggi, resisti
## o arrenditi. Il pannello riusa CrimePanel.

signal message(text: String)

var _avatar: Node2D
var _origin: Vector2 = Vector2.ZERO
var _combat: CombatManager
var _bm: BuildingManager

var _layer: CanvasLayer
var _panel: CrimePanel
var _posse: PosseView
var _actions: Array = []
var _timer: float = 0.0
var _since_pursuit: float = 999.0
var _lose: float = 0.0
var _paused_by_me: bool = false
var _pending_ids: Array = []
var _pending_title: String = ""
var _teleport: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(avatar: Node2D, origin: Vector2, combat: CombatManager, buildings: BuildingManager = null) -> void:
	_avatar = avatar
	_origin = origin
	_combat = combat
	_bm = buildings
	LawSystem.reset()


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 45
	add_child(_layer)
	_panel = CrimePanel.new()
	_panel.closable = false
	_layer.add_child(_panel)
	WesternTheme.apply(_panel)
	_panel.set_title("LA LEGGE")
	_panel.footer_menu_text = "[1-9] scegli"
	_panel.action_chosen.connect(_on_action)
	_panel.closed.connect(_on_closed)
	if _avatar == null:
		_avatar = get_tree().get_first_node_in_group("player") as Node2D


func _process(delta: float) -> void:
	if get_tree().paused or _avatar == null:
		return
	_since_pursuit += delta
	if _posse != null and is_instance_valid(_posse):
		_track_posse(delta)
		return
	_timer += delta
	var law := LawSystem.cfg()
	if _timer < float(law.get("check_interval", 4)):
		return
	_timer = 0.0
	_maybe_start_pursuit(law)


func _maybe_start_pursuit(law: Dictionary) -> void:
	var lvl := CrimeSystem.wanted_level()
	if lvl < int(law.get("min_level", 2)) or CrimeSystem.bounty() <= 0:
		return
	if _since_pursuit < float(law.get("pursuit_cooldown", 60)):
		return
	if _avatar.global_position.distance_to(_origin) > float(law.get("jurisdiction", 1400)):
		return
	var chances = law.get("chase_chance", [])
	var p := float(chances[lvl - 1]) if lvl - 1 < chances.size() else 0.5
	if randf() < p:
		_spawn_posse(law, lvl)


func _spawn_posse(law: Dictionary, lvl: int) -> void:
	var start := _sheriff_pos()
	var ppos := _avatar.global_position
	var mind := float(law.get("spawn_min_distance", 350))
	if start.distance_to(ppos) < mind:
		start = ppos + Vector2.from_angle(randf() * TAU) * mind
	_posse = PosseView.new()
	add_child(_posse)
	var speed := float(law.get("chase_speed", 200)) + float(law.get("speed_per_level", 12)) * float(lvl)
	_posse.setup(_avatar, clampi(lvl, 1, 4), start, speed, float(law.get("catch_radius", 36)))
	_posse.caught.connect(_on_caught)
	_lose = 0.0
	_since_pursuit = 0.0
	message.emit(str(law.get("texts", {}).get("warn", "")))


func _track_posse(delta: float) -> void:
	var law := LawSystem.cfg()
	if _posse.nearest_distance() > float(law.get("lose_distance", 1100)):
		_lose += delta
		if _lose >= float(law.get("lose_seconds", 12)):
			_end_posse()
			message.emit(str(law.get("texts", {}).get("lost", "")))
	else:
		_lose = 0.0


func _end_posse() -> void:
	if _posse != null and is_instance_valid(_posse):
		_posse.queue_free()
	_posse = null
	_since_pursuit = 0.0


func _on_caught() -> void:
	var deputies := _posse.count() if _posse != null else 2
	_end_posse()
	var law := LawSystem.cfg()
	var texts: Dictionary = law.get("texts", {})
	_actions = []
	var pay := LawSystem.pay_cost()
	var bribe := LawSystem.bribe_cost()
	var money := CrimeSystem.money()
	_actions.append(_act("Paga la taglia ($%d)" % pay, "Cancella la taglia: niente cella.", money >= pay and pay > 0, "Non hai abbastanza soldi.", func(): return LawSystem.pay_bounty()))
	_actions.append(_act("Corrompi il vice ($%d) - %d%%" % [bribe, int(round(LawSystem.chance_bribe() * 100.0))], "Prova di Carisma. Se fallisci perdi i soldi e finisci in cella.", money >= bribe, "Non hai abbastanza soldi.", func(): return LawSystem.do_bribe()))
	_actions.append(_act("Fuggi - %d%%" % int(round(LawSystem.chance_flee() * 100.0)), "Prova di Agilità. Se fallisci, un giorno di cella in più.", true, "", func(): return LawSystem.do_flee()))
	_actions.append(_act("Resisti all'arresto", "Combatti i vice: la legge non lo dimenticherà.", true, "", func(): return LawSystem.do_resist(deputies)))
	_actions.append(_act("Arrenditi", "Multa e cella; la notorietà scende.", true, "", func(): return LawSystem.do_arrest()))
	_pause(true)
	_panel.open_menu(CrimeSystem.hud_text(), str(texts.get("open", "")), _actions)


func _act(label: String, tip: String, enabled: bool, reason: String, run: Callable) -> Dictionary:
	return {"group": "law", "label": label, "tip": tip if enabled or reason == "" else reason, "enabled": enabled, "run": run}


func _on_action(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	var run: Callable = _actions[index].get("run", Callable())
	if not run.is_valid():
		return
	var res: Dictionary = run.call()
	_pending_ids = res.get("combat", [])
	_pending_title = str(res.get("combat_title", ""))
	_teleport = bool(res.get("teleport", false))
	var title := "Sei un uomo libero" if bool(res.get("ok", false)) else "La legge ti ha preso"
	_panel.show_result(title, res.get("lines", []), bool(res.get("ok", false)))


func _on_closed() -> void:
	_pause(false)
	if _teleport and _avatar != null:
		_avatar.global_position = _sheriff_pos() + Vector2(0, 60)
		_teleport = false
	if not _pending_ids.is_empty() and _combat != null:
		var ids := _pending_ids.duplicate()
		var title := _pending_title
		_pending_ids = []
		_pending_title = ""
		_combat.call_deferred("start_encounter", ids, title, false)


func _pause(on: bool) -> void:
	if on:
		_paused_by_me = not get_tree().paused
		get_tree().paused = true
	elif _paused_by_me:
		get_tree().paused = false
		_paused_by_me = false


## Ingresso dell'Ufficio dello Sceriffo; se non si trova, il centro della città.
func _sheriff_pos() -> Vector2:
	if _bm == null or not is_instance_valid(_bm):
		return _origin
	var list = _bm.get("buildings")
	if not (list is Array):
		return _origin
	var tokens = LawSystem.cfg().get("sheriff_match", [])
	for b in list:
		var text := ("%s %s %s" % [str(CrimeSystem.npc_get(b, "id", "")), str(CrimeSystem.npc_get(b, "name", "")), str(CrimeSystem.npc_get(b, "sign", ""))]).to_lower()
		for t in tokens:
			if text.find(str(t)) >= 0:
				for k in ["entrance", "entrance_pos", "position", "pos"]:
					var v = CrimeSystem.npc_get(b, k, null)
					if v is Vector2:
						return v
				var r = CrimeSystem.npc_get(b, "rect", null)
				if r is Rect2:
					return r.get_center()
	return _origin
