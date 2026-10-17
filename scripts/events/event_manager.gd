class_name EventManager
extends Node
## Eventi casuali (Feature 22). Dati in data/events.json: rapina in banca, incendio, aggressione,
## carovana, duello casuale, incontro misterioso. Ogni evento ha un testo e opzioni con prove
## su statistica, ricompense, reputazione, notorietà, scontri o duello. Riusa CrimePanel.
## Debug: tasto Y fa partire subito un evento.

signal message(text: String)

const PATH := "res://data/events.json"

var _data: Dictionary = {}
var _avatar: Node2D
var _origin: Vector2 = Vector2.ZERO
var _combat: CombatManager
var _duels: DuelManager

var _layer: CanvasLayer
var _panel: CrimePanel
var _actions: Array = []
var _timer: float = 0.0
var _since: float = 999.0
var _day: int = -1
var _day_n: int = 0
var _paused_by_me: bool = false
var _pending_ids: Array = []
var _pending_title: String = ""
var _pending_duel: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(avatar: Node2D, origin: Vector2, combat: CombatManager, duels: DuelManager) -> void:
	_avatar = avatar
	_origin = origin
	_combat = combat
	_duels = duels


func _ready() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	else:
		push_warning("EventManager: manca " + PATH)
	_layer = CanvasLayer.new()
	_layer.layer = 44
	add_child(_layer)
	_panel = CrimePanel.new()
	_panel.closable = false
	_panel.alert_status = false
	_panel.footer_menu_text = "[1-9] scegli"
	_layer.add_child(_panel)
	WesternTheme.apply(_panel)
	_panel.action_chosen.connect(_on_action)
	_panel.closed.connect(_on_closed)
	if _avatar == null:
		_avatar = get_tree().get_first_node_in_group("player") as Node2D


func _process(delta: float) -> void:
	if get_tree().paused or _avatar == null or _panel.visible:
		return
	_since += delta
	_timer += delta
	if _timer < float(_data.get("check_interval", 5)):
		return
	_timer = 0.0
	if _since < float(_data.get("cooldown_seconds", 150)):
		return
	var day := CrimeSystem.current_day()
	if day != _day:
		_day = day
		_day_n = 0
	if _day_n >= int(_data.get("max_per_day", 2)):
		return
	if randf() > float(_data.get("chance_per_check", 0.12)):
		return
	var ev := _pick(day, _day_n, true)
	if not ev.is_empty():
		_start(ev)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Y:
		if get_tree().paused or _panel.visible or _avatar == null:
			return
		var ev := _pick(CrimeSystem.current_day(), randi() % 1000, false)
		if not ev.is_empty():
			_start(ev)


# ---------------------------------------------------------------- scelta dell'evento

func _eligible(ev: Dictionary, check_place: bool) -> bool:
	if check_place and bool(ev.get("town_only", false)):
		if _avatar.global_position.distance_to(_origin) > float(_data.get("town_radius", 700)):
			return false
	var hours = ev.get("hours", null)
	if hours is Array and hours.size() == 2:
		var h := CrimeSystem.current_hour()
		if h < float(hours[0]) or h >= float(hours[1]):
			return false
	return true


func _pick(day: int, n: int, check_place: bool) -> Dictionary:
	var pool: Array = []
	var total := 0.0
	for ev in _data.get("events", []):
		if _eligible(ev, check_place):
			pool.append(ev)
			total += float(ev.get("weight", 1))
	if pool.is_empty():
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_event_%d_%d" % [str(WorldSeed.world_seed), day, n])
	var roll := rng.randf() * total
	for ev in pool:
		roll -= float(ev.get("weight", 1))
		if roll <= 0.0:
			return ev
	return pool[pool.size() - 1]


# ---------------------------------------------------------------- pannello

func _start(ev: Dictionary) -> void:
	_since = 0.0
	_day_n += 1
	_actions = []
	var money := CrimeSystem.money()
	var firearm := CrimeSystem.has_firearm()
	for o in ev.get("options", []):
		var opt: Dictionary = o
		var label := str(opt.get("label", "?"))
		var tip := str(opt.get("tip", ""))
		var enabled := true
		if opt.has("check"):
			var p := _chance(opt["check"])
			label += " - %d%%" % int(round(p * 100.0))
		if bool(opt.get("firearm", false)) and not firearm:
			enabled = false
			tip = "Serve un'arma da fuoco in mano."
		if money < int(opt.get("min_money", 0)):
			enabled = false
			tip = "Non hai abbastanza soldi."
		_actions.append({"group": "event", "label": label, "tip": tip, "enabled": enabled, "run": func(): return _resolve(opt)})
	_pause(true)
	_panel.set_title(str(ev.get("title", "EVENTO")))
	_panel.open_menu(str(ev.get("text", "")), "", _actions)


func _chance(c: Dictionary) -> float:
	var p := float(c.get("base", 0.5)) + CrimeSystem._stat(str(c.get("stat", "carisma"))) * float(c.get("per_stat", 0.05))
	return CrimeSystem._clamp_chance(p)


func _resolve(opt: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ok := true
	var out: Dictionary = {}
	if opt.has("check"):
		ok = rng.randf() < _chance(opt["check"])
		out = opt.get("ok" if ok else "fail", {})
	else:
		out = opt.get("result", {})
	var res := _apply(out, rng)
	res["ok"] = ok
	return res


func _apply(out: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var lines: Array = []
	var res := {"ok": true, "lines": lines, "combat": [], "combat_title": "", "duel": false}
	var t := str(out.get("text", ""))
	if t != "":
		lines.append(t)
	if out.has("money"):
		var m = out["money"]
		var amount := 0
		if m is Array and m.size() == 2:
			amount = rng.randi_range(int(m[0]), int(m[1]))
		else:
			amount = int(m)
		if amount > 0:
			PlayerState.add_money(amount)
			lines.append("Ricevi $%d." % amount)
		elif amount < 0:
			var loss := mini(-amount, CrimeSystem.money())
			if loss > 0:
				PlayerState.spend_money(loss)
				lines.append("Perdi $%d." % loss)
	if out.has("health"):
		var h := int(out["health"])
		if h < 0:
			PlayerState.damage(-h)
			lines.append("Perdi %d salute." % -h)
		elif h > 0:
			PlayerState.heal(h)
	if out.has("rep") and out["rep"] is Dictionary:
		for g in out["rep"]:
			ReputationSystem.add(str(g), float(out["rep"][g]))
	if out.has("heat"):
		CrimeSystem.add_heat(float(out["heat"]), {"witnesses": 1})
	if str(out.get("item", "")) == "weapon":
		var wid := WeaponDB.random_id(rng)
		if wid != "" and PlayerState.add_item(wid, 1) == 0:
			lines.append("Ottieni: %s." % WeaponDB.name_of(wid))
	if out.has("combat") and out["combat"] is Dictionary:
		var c: Dictionary = out["combat"]
		var cnt = c.get("count", [1, 1])
		var ids: Array = []
		for i in rng.randi_range(int(cnt[0]), int(cnt[1])):
			ids.append(str(c.get("enemy", "bandito")))
		res["combat"] = ids
		res["combat_title"] = str(c.get("title", "Scontro"))
	res["duel"] = bool(out.get("duel", false))
	return res


func _on_action(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	var run: Callable = _actions[index].get("run", Callable())
	if not run.is_valid():
		return
	var res: Dictionary = run.call()
	_pending_ids = res.get("combat", [])
	_pending_title = str(res.get("combat_title", ""))
	_pending_duel = bool(res.get("duel", false))
	_panel.show_result("Com'è andata", res.get("lines", []), bool(res.get("ok", true)))


func _on_closed() -> void:
	_pause(false)
	if _pending_duel and _duels != null:
		_pending_duel = false
		_duels.call_deferred("challenge_stranger")
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
