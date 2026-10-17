class_name CrimeManager
extends Node
## Criminalità (Feature 20). Tasto C: pannello "Malaffare" con le azioni possibili
## nel punto in cui si trova il giocatore (furto, rapina, ricatto, contrabbando).
## Si crea come gli altri manager: add_child + message.connect + setup(avatar, origin, combat).

signal message(text: String)

var _avatar: Node2D
var _origin: Vector2 = Vector2.ZERO
var _combat: CombatManager
var _bm: BuildingManager

var _layer: CanvasLayer
var _panel: CrimePanel
var _heat_label: Label
var _actions: Array = []
var _timer: float = 0.0
var _paused_by_me: bool = false
var _pending_ids: Array = []
var _pending_title: String = ""
var _last_level: int = 0


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(avatar: Node2D, origin: Vector2, combat: CombatManager) -> void:
	_avatar = avatar
	_origin = origin
	_combat = combat
	CrimeSystem.reset()
	_last_level = 0


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 40
	add_child(_layer)

	_heat_label = Label.new()
	_heat_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_heat_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	_heat_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_heat_label.add_theme_constant_override("shadow_offset_x", 1)
	_heat_label.add_theme_constant_override("shadow_offset_y", 1)
	_heat_label.visible = false
	_layer.add_child(_heat_label)
	_heat_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_heat_label.position = Vector2(14, -34)

	_panel = CrimePanel.new()
	_layer.add_child(_panel)
	WesternTheme.apply(_panel)
	_panel.action_chosen.connect(_on_action)
	_panel.closed.connect(_on_closed)

	if _avatar == null:
		_avatar = get_tree().get_first_node_in_group("player") as Node2D


func _process(delta: float) -> void:
	_timer += delta
	if _timer < 0.5:
		return
	_timer = 0.0
	var day := CrimeSystem.current_day()
	if day != CrimeSystem.last_day:
		CrimeSystem.advance_to(day)
	var txt := CrimeSystem.hud_text()
	_heat_label.visible = txt != ""
	_heat_label.text = txt
	var lvl := CrimeSystem.wanted_level()
	if lvl > _last_level:
		var ui := CrimeDB.section("ui")
		message.emit(CrimeDB.fmt(str(ui.get("wanted_up", "")), {"name": CrimeSystem.wanted_name(), "bounty": CrimeSystem.bounty()}))
	_last_level = lvl


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_C:
		if _panel.visible or get_tree().paused:
			return
		_open_panel()


# ---------------------------------------------------------------- pannello

func _open_panel() -> void:
	if _avatar == null:
		_avatar = get_tree().get_first_node_in_group("player") as Node2D
		if _avatar == null:
			return
	_actions = _build_actions()
	_pause(true)
	_panel.open_menu(_status_text(), _history_text(), _actions)


func _status_text() -> String:
	var t := CrimeSystem.hud_text()
	if t == "":
		return str(CrimeDB.section("ui").get("clean", ""))
	return t


func _history_text() -> String:
	if CrimeSystem.history.is_empty():
		return str(CrimeDB.section("ui").get("history_empty", ""))
	var lines: Array = []
	for h in CrimeSystem.history:
		lines.append("Giorno %d - %s" % [int(h.get("day", 0)), str(h.get("text", ""))])
	return "\n".join(lines)


func _on_action(index: int) -> void:
	if index < 0 or index >= _actions.size():
		return
	var run: Callable = _actions[index].get("run", Callable())
	if not run.is_valid():
		return
	var res: Dictionary = run.call()
	_pending_ids = res.get("combat", [])
	_pending_title = str(res.get("combat_title", ""))
	var title := "Colpo riuscito" if bool(res.get("ok", false)) else "Colpo andato male"
	_panel.show_result(title, res.get("lines", []), bool(res.get("ok", false)))


func _on_closed() -> void:
	_pause(false)
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


# ---------------------------------------------------------------- azioni

func _disabled(group: String, reason: String) -> Dictionary:
	return {"group": group, "label": reason, "tip": reason, "enabled": false, "run": Callable()}


func _build_actions() -> Array:
	var acts: Array = []
	var ui := CrimeDB.section("ui")
	var radius := float(CrimeDB.value("interact_radius", 130))
	var near := _nearby(radius)

	# Furto e ricatto: persone a portata di mano.
	if near.is_empty():
		acts.append(_disabled("pickpocket", str(ui.get("nobody", ""))))
	for e in near:
		var npc = e["npc"]
		var id := str(CrimeSystem.npc_get(npc, "id", ""))
		var ctx := _context(id)
		var p := CrimeSystem.chance_pickpocket(npc, ctx)
		var nm := str(CrimeSystem.npc_get(npc, "name", "?"))
		var job := str(CrimeSystem.npc_get(npc, "job", ""))
		var lab := "Borseggia %s (%s) - %d%%" % [nm, job, int(round(p * 100.0))]
		if CrimeSystem.on_cooldown("pp_" + id):
			acts.append({"group": "pickpocket", "label": lab, "tip": str(ui.get("victim_recently", "")), "enabled": false, "run": Callable()})
		else:
			acts.append({"group": "pickpocket", "label": lab, "tip": "Prova di Agilità contro la sua. Testimoni e luce del giorno pesano.", "enabled": true, "run": func(): return CrimeSystem.do_pickpocket(npc, ctx)})

	# Rapina: edifici vicini.
	var bnear := _buildings_near(float(CrimeDB.value("building_radius", 200)))
	var firearm := _has_firearm()
	var ctx_b := _context("")
	if bnear.is_empty():
		acts.append(_disabled("robbery", str(ui.get("no_building", ""))))
	for e in bnear:
		var target: Dictionary = e["target"]
		var place := str(e["name"])
		var key := str(e["key"])
		var night := bool(ctx_b.get("night", false))
		var mode_txt := str(ui.get("mode_night" if night else "mode_day", ""))
		var pr := CrimeSystem.chance_robbery(target, ctx_b)
		var lab_r := "Rapina: %s (%s) - %d%%" % [place, mode_txt, int(round(pr * 100.0))]
		if CrimeSystem.on_cooldown("rob_" + key):
			acts.append({"group": "robbery", "label": lab_r, "tip": str(ui.get("robbed_recently", "")), "enabled": false, "run": Callable()})
		elif not night and not firearm:
			acts.append({"group": "robbery", "label": lab_r, "tip": str(ui.get("need_firearm", "")), "enabled": false, "run": Callable()})
		else:
			acts.append({"group": "robbery", "label": lab_r, "tip": "Se fallisci, le guardie ti sparano addosso.", "enabled": true, "run": func(): return CrimeSystem.do_robbery(target, place, key, ctx_b)})

	# Ricatto.
	if near.is_empty():
		acts.append(_disabled("blackmail", str(ui.get("nobody", ""))))
	for e in near:
		var npc2 = e["npc"]
		var id2 := str(CrimeSystem.npc_get(npc2, "id", ""))
		var ctx2 := _context(id2)
		var p2 := CrimeSystem.chance_blackmail_display(npc2, ctx2)
		var nm2 := str(CrimeSystem.npc_get(npc2, "name", "?"))
		var lab2 := "Ricatta %s - circa %d%%" % [nm2, int(round(p2 * 100.0))]
		if CrimeSystem.on_cooldown("bm_" + id2):
			acts.append({"group": "blackmail", "label": lab2, "tip": str(ui.get("victim_recently", "")), "enabled": false, "run": Callable()})
		else:
			acts.append({"group": "blackmail", "label": lab2, "tip": "Prova di Carisma. Se non ha segreti, il tuo è un bluff.", "enabled": true, "run": func(): return CrimeSystem.do_blackmail(npc2, ctx2)})

	# Contrabbando.
	var ctx_s := _context("")
	ctx_s["distance"] = _avatar.global_position.distance_to(_origin)
	var s := CrimeDB.section("smuggling")
	for cargo in s.get("loads", []):
		var c: Dictionary = cargo
		var pct := CrimeSystem.expected_profit_pct(c)
		var sgn := "+" if pct >= 0 else ""
		var lab_s := "%s ($%d) - guadagno atteso %s%d%%" % [str(c.get("label", "Carico")), int(c.get("cost", 0)), sgn, pct]
		var reason := CrimeSystem.smuggle_block_reason(ctx_s, c)
		if reason != "":
			acts.append({"group": "smuggling", "label": lab_s, "tip": reason, "enabled": false, "run": Callable()})
		else:
			acts.append({"group": "smuggling", "label": lab_s, "tip": "Il viaggio richiede qualche ora. Possibili pattuglie.", "enabled": true, "run": func(): return CrimeSystem.do_smuggle(c, ctx_s)})

	# Legge: pagare la taglia all'Ufficio dello Sceriffo.
	var bounty := CrimeSystem.bounty()
	if bounty > 0:
		var lab_l := "Paga la taglia ($%d)" % bounty
		if not _sheriff_office_near():
			acts.append({"group": "law", "label": lab_l, "tip": "Devi trovarti davanti all'Ufficio dello Sceriffo.", "enabled": false, "run": Callable()})
		elif CrimeSystem.money() < bounty:
			acts.append({"group": "law", "label": lab_l, "tip": "Non hai abbastanza soldi.", "enabled": false, "run": Callable()})
		else:
			acts.append({"group": "law", "label": lab_l, "tip": "Cancella la taglia e azzera la notorietà.", "enabled": true, "run": func(): return LawSystem.pay_bounty()})
	return acts


func _sheriff_office_near() -> bool:
	if _bm == null or not is_instance_valid(_bm):
		_bm = _find_bm(get_tree().current_scene)
	if _bm == null:
		return false
	var list = _bm.get("buildings")
	if not (list is Array):
		return false
	var radius := float(CrimeDB.value("building_radius", 200))
	var tokens = CrimeDB.section("law").get("sheriff_match", [])
	var pos := _avatar.global_position
	for b in list:
		var bp = _bld_pos(b)
		if not (bp is Vector2) or pos.distance_to(bp) > radius:
			continue
		var text := ("%s %s %s" % [str(CrimeSystem.npc_get(b, "id", "")), str(CrimeSystem.npc_get(b, "name", "")), str(CrimeSystem.npc_get(b, "sign", ""))]).to_lower()
		for t in tokens:
			if text.find(str(t)) >= 0:
				return true
	return false


# ---------------------------------------------------------------- contesto del mondo

func _context(exclude_id: String) -> Dictionary:
	var pos := _avatar.global_position
	var witnesses := 0
	var sheriff := false
	var wr := float(CrimeDB.value("witness_radius", 320))
	var sr := float(CrimeDB.value("sheriff_radius", 420))
	for n in _npcs():
		if CrimeSystem.npc_inside(n):
			continue
		var np = CrimeSystem.npc_get(n, "position", null)
		if not (np is Vector2):
			continue
		var d := pos.distance_to(np)
		if CrimeSystem.is_protected(n):
			if d <= sr:
				sheriff = true
		elif str(CrimeSystem.npc_get(n, "id", "")) != exclude_id and d <= wr:
			witnesses += 1
	return {"witnesses": witnesses, "sheriff": sheriff, "night": CrimeSystem.is_night()}


func _npcs() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for job in CrimeDB.value("npc_jobs", []):
		for variant in [str(job), str(job).capitalize()]:
			var arr = NPCRegistry.by_job(variant)
			if not (arr is Array):
				continue
			for item in arr:
				var n = item
				if item is String or item is StringName:
					n = NPCRegistry.get_npc(str(item))
				if n == null:
					continue
				var id := str(CrimeSystem.npc_get(n, "id", item))
				if seen.has(id):
					continue
				seen[id] = true
				out.append(n)
	return out


func _nearby(radius: float) -> Array:
	var out: Array = []
	var pos := _avatar.global_position
	for n in _npcs():
		if CrimeSystem.is_protected(n) or CrimeSystem.npc_inside(n):
			continue
		var np = CrimeSystem.npc_get(n, "position", null)
		if not (np is Vector2):
			continue
		var d := pos.distance_to(np)
		if d <= radius:
			out.append({"npc": n, "d": d})
	out.sort_custom(func(a, b): return a["d"] < b["d"])
	return out.slice(0, 3)


func _find_bm(node: Node) -> BuildingManager:
	if node is BuildingManager:
		return node
	for c in node.get_children():
		var r := _find_bm(c)
		if r != null:
			return r
	return null


func _buildings_near(radius: float) -> Array:
	var out: Array = []
	if _bm == null or not is_instance_valid(_bm):
		_bm = _find_bm(get_tree().current_scene)
	if _bm == null:
		return out
	var list = _bm.get("buildings")
	if not (list is Array):
		return out
	var targets = CrimeDB.section("robbery").get("targets", [])
	var pos := _avatar.global_position
	for b in list:
		var bp = _bld_pos(b)
		if not (bp is Vector2) or pos.distance_to(bp) > radius:
			continue
		var text := ("%s %s %s" % [str(CrimeSystem.npc_get(b, "id", "")), str(CrimeSystem.npc_get(b, "name", "")), str(CrimeSystem.npc_get(b, "sign", ""))]).to_lower()
		for t in targets:
			var hit := false
			for m in t.get("match", []):
				if text.find(str(m)) >= 0:
					hit = true
			if hit:
				var nm := str(CrimeSystem.npc_get(b, "name", t.get("label", "Edificio")))
				var key := str(CrimeSystem.npc_get(b, "id", nm))
				out.append({"target": t, "name": nm, "key": key})
				break
	return out


func _bld_pos(b):
	for k in ["entrance", "entrance_pos", "position", "pos"]:
		var v = CrimeSystem.npc_get(b, k, null)
		if v is Vector2:
			return v
	var r = CrimeSystem.npc_get(b, "rect", null)
	if r is Rect2:
		return r.get_center()
	return null


func _has_firearm() -> bool:
	var w = PlayerState.get_weapon()
	var t := ""
	if w is Dictionary:
		if str(w.get("kind", "")) == "ranged":
			return true
		t = str(w.get("type", ""))
		if t == "" and w.has("id"):
			w = str(w["id"])
	if t == "" and (w is String or w is StringName) and str(w) != "":
		var wd = WeaponDB.weapon(str(w))
		if wd is Dictionary:
			if str(wd.get("kind", "")) == "ranged":
				return true
			t = str(wd.get("type", ""))
	return t in CrimeDB.value("ranged_types", [])
