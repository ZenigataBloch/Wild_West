class_name GangSystem
extends RefCounted
## Sistema gang (Feature 19), logica senza UI, stato in memoria.
## Ogni gang: id, name, color, boss, members, hideout, extra_radius, wealth,
## goal, enemies, rep (reputazione del giocatore presso la banda), flag di conoscenza.

static var gangs: Array = []
static var news: Array = []      # [{day, text}]
static var version: int = 0      # cambia quando cambia la struttura (per rifare la grafica)
static var last_day: int = -1

static var _rng: RandomNumberGenerator = null
static var _next_id: int = 1
static var _respawns: Array = []
static var _origin: Vector2 = Vector2.ZERO
static var _bounds: Rect2 = Rect2()
static var _avoid: Array = []


# ---------------------------------------------------------------- generazione

static func reset() -> void:
	gangs = []
	news = []
	last_day = -1
	_rng = null
	_next_id = 1
	_respawns = []
	version += 1


static func generate(origin: Vector2, bounds: Rect2, avoid: Array, start_day: int) -> void:
	reset()
	_origin = origin
	if bounds.size.x > 0.0 and bounds.size.y > 0.0:
		_bounds = bounds
	else:
		_bounds = Rect2(origin - Vector2(3500, 3500), Vector2(7000, 7000))
	_avoid = avoid
	var r: Variant = WorldSeed.rng_for("gangs")
	_rng = r
	last_day = start_day
	var count: int = int(GangDB.data().get("count", 3))
	for i in count:
		var g: Dictionary = _make_gang(i, count)
		if not g.is_empty():
			gangs.append(g)
	for g in gangs:
		_link_nearest(g)
	for g in gangs:
		g["goal"] = _pick_goal(g)
	version += 1


static func _pick_unused(list: Array, key: String) -> String:
	var pool: Array = []
	for item in list:
		var taken: bool = false
		for g in gangs:
			if str(g[key]) == str(item):
				taken = true
		if not taken:
			pool.append(item)
	if pool.is_empty():
		pool = list
	if pool.is_empty():
		return ""
	return str(pool[_rng.randi() % pool.size()])


static func _make_gang(index: int, count: int) -> Dictionary:
	var data: Dictionary = GangDB.data()
	var gname: String = _pick_unused(data.get("names", []), "name")
	if gname == "":
		gname = "Banda %d" % _next_id
	var boss: String = _pick_unused(data.get("bosses", []), "boss")
	if boss == "":
		boss = "Il Capo"
	var color: String = _pick_unused(data.get("colors", ["#8b2e2e"]), "color")
	var mem: Dictionary = GangDB.section("members")
	var n: int = _rng.randi_range(int(mem.get("min", 7)), int(mem.get("max", 13)))
	var eco: Dictionary = GangDB.section("economy")
	var rr: int = int(GangDB.section("reputation").get("start_range", 8))
	var g: Dictionary = {
		"id": "gang_%d" % _next_id,
		"name": gname,
		"color": color,
		"boss": boss,
		"members": _make_members(n, boss),
		"hideout": _find_hideout(index, count),
		"extra_radius": 0.0,
		"wealth": float(_rng.randi_range(int(eco.get("start_wealth_min", 60)), int(eco.get("start_wealth_max", 220)))),
		"goal": {},
		"enemies": [],
		"rep": float(_rng.randi_range(-rr, rr)),
		"discovered": false,
		"rumored": false,
		"rumor_told": false,
		"known_goal": false,
		"encounters_today": 0,
		"safe_day": -1,
		"rested_day": -1,
	}
	_next_id += 1
	return g


static func _make_members(count: int, boss: String) -> Array:
	var members: Array = [{"name": boss, "role": "capo"}]
	var lieutenants: int = 1
	if count >= 10:
		lieutenants = 2
	for k in range(1, count):
		var role: String = "pistolero"
		if k <= lieutenants:
			role = "luogotenente"
		members.append({"name": _member_name(), "role": role})
	return members


static func _member_name() -> String:
	var firsts: Array = GangDB.data().get("first_names", ["Jed"])
	var nicks: Array = GangDB.data().get("nicknames", ["Dente"])
	return "%s '%s'" % [firsts[_rng.randi() % firsts.size()], nicks[_rng.randi() % nicks.size()]]


static func _find_hideout(index: int, count: int) -> Vector2:
	var p: Dictionary = GangDB.section("placement")
	var margin: float = float(p.get("margin", 300))
	var area: Rect2 = _bounds.grow(-margin)
	if area.size.x <= 0.0 or area.size.y <= 0.0:
		area = _bounds
	var min_town: float = float(p.get("min_town_distance", 1100))
	var min_gang: float = float(p.get("min_gang_distance", 1500))
	var avoid_margin: float = float(p.get("avoid_margin", 200))
	for _a in int(p.get("attempts", 200)):
		var pos := Vector2(
			area.position.x + _rng.randf() * area.size.x,
			area.position.y + _rng.randf() * area.size.y)
		if _valid_hideout(pos, min_town, min_gang, avoid_margin):
			return pos
	# ripiego: anello attorno alla città
	var ang: float = TAU * float(index) / float(maxi(count, 1)) + _rng.randf() * 0.5
	return _origin + Vector2.from_angle(ang) * float(p.get("ring_distance", 1600))


static func _valid_hideout(pos: Vector2, min_town: float, min_gang: float, avoid_margin: float) -> bool:
	if pos.distance_to(_origin) < min_town:
		return false
	for g in gangs:
		if pos.distance_to(g["hideout"]) < min_gang:
			return false
	for r in _avoid:
		if r is Rect2 and (r as Rect2).grow(avoid_margin).has_point(pos):
			return false
	return true


static func _link_nearest(g: Dictionary) -> void:
	var best: Dictionary = {}
	var best_d: float = INF
	for o in gangs:
		if str(o["id"]) == str(g["id"]):
			continue
		var d: float = (g["hideout"] as Vector2).distance_to(o["hideout"])
		if d < best_d:
			best_d = d
			best = o
	if best.is_empty():
		return
	if not (g["enemies"] as Array).has(best["id"]):
		(g["enemies"] as Array).append(best["id"])
	if not (best["enemies"] as Array).has(g["id"]):
		(best["enemies"] as Array).append(g["id"])


# ------------------------------------------------------------------ interrogazioni

static func by_id(id: String) -> Dictionary:
	for g in gangs:
		if str(g["id"]) == id:
			return g
	return {}


static func radius_of(g: Dictionary) -> float:
	var t: Dictionary = GangDB.section("territory")
	var r: float = float(t.get("base_radius", 340)) + float(t.get("per_member", 14)) * float((g["members"] as Array).size()) + float(g.get("extra_radius", 0.0))
	return clampf(r, float(t.get("min_radius", 160)), float(t.get("max_radius", 650)))


static func strength(g: Dictionary) -> float:
	var per: float = maxf(1.0, GangDB.num("members", "wealth_per_strength", 80.0))
	return float((g["members"] as Array).size()) + float(g["wealth"]) / per


static func gang_at(pos: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var best_d: float = INF
	for g in gangs:
		var d: float = pos.distance_to(g["hideout"])
		if d <= radius_of(g) and d < best_d:
			best_d = d
			best = g
	return best


static func in_core(g: Dictionary, pos: Vector2) -> bool:
	return pos.distance_to(g["hideout"]) <= GangDB.num("territory", "core_radius", 150.0)


static func direction_text(pos: Vector2) -> String:
	var v: Vector2 = pos - _origin
	var ang: float = fposmod(rad_to_deg(atan2(-v.y, v.x)), 360.0)
	var names: Array = ["est", "nord-est", "nord", "nord-ovest", "ovest", "sud-ovest", "sud", "sud-est"]
	return str(names[int(round(ang / 45.0)) % 8])


static func distance_from_town(g: Dictionary) -> int:
	return int(round((g["hideout"] as Vector2).distance_to(_origin) / 10.0)) * 10


static func discover(g: Dictionary) -> void:
	if not bool(g["discovered"]):
		g["discovered"] = true
		version += 1


# ------------------------------------------------------------------ reputazione

static func effective_rep(g: Dictionary) -> float:
	var bias: float = float(GangDB.section("reputation").get("global_bias", 0.4))
	return clampf(float(g["rep"]) + bias * float(ReputationSystem.value("gang")), -100.0, 100.0)


static func stance(g: Dictionary) -> String:
	var r: float = effective_rep(g)
	var cfg: Dictionary = GangDB.section("reputation")
	if r <= float(cfg.get("hostile_max", -20)):
		return "hostile"
	if r >= float(cfg.get("friendly_min", 20)):
		return "friendly"
	return "wary"


static func stance_label(g: Dictionary) -> String:
	var st: Dictionary = GangDB.section("stances")
	var s: Variant = st.get(stance(g), {})
	if s is Dictionary:
		return str(s.get("label", stance(g)))
	return stance(g)


## Cambia la reputazione presso una banda: i suoi nemici ne risentono in senso opposto
## e anche il gruppo generale "gang" (che a sua volta sposta la legge).
static func add_rep(gang_id: String, delta: float, with_group: bool = true) -> void:
	var g: Dictionary = by_id(gang_id)
	if g.is_empty() or delta == 0.0:
		return
	var cfg: Dictionary = GangDB.section("reputation")
	g["rep"] = clampf(float(g["rep"]) + delta, -100.0, 100.0)
	var ef: float = float(cfg.get("enemy_factor", -0.5))
	for eid in g["enemies"]:
		var e: Dictionary = by_id(str(eid))
		if not e.is_empty():
			e["rep"] = clampf(float(e["rep"]) + delta * ef, -100.0, 100.0)
	if with_group:
		ReputationSystem.add("gang", delta * float(cfg.get("group_factor", 0.4)))


# ------------------------------------------------------------------ obiettivi e simulazione

static func goal_label(g: Dictionary, with_progress: bool = true) -> String:
	var goal: Dictionary = g["goal"]
	if goal.is_empty():
		return "nessuno"
	var def: Variant = GangDB.section("goals").get(str(goal["type"]), {})
	var label: String = str(goal["type"])
	if def is Dictionary:
		label = str(def.get("label", label))
	var enemy_name: String = ""
	var target: Dictionary = by_id(str(goal.get("target", "")))
	if not target.is_empty():
		enemy_name = str(target["name"])
	label = label.format({"enemy": enemy_name})
	if with_progress:
		label += " (%d/%d giorni)" % [int(goal["done"]), int(goal["need"])]
	return label


static func enemy_names(g: Dictionary) -> String:
	var names: Array = []
	for eid in g["enemies"]:
		var e: Dictionary = by_id(str(eid))
		if not e.is_empty():
			names.append("«%s»" % e["name"])
	if names.is_empty():
		return "nessuno"
	return ", ".join(PackedStringArray(names))


static func _pick_goal(g: Dictionary) -> Dictionary:
	var goals: Dictionary = GangDB.section("goals")
	var ids: Array = []
	var weights: Array = []
	var total: float = 0.0
	for id in goals.keys():
		var def: Dictionary = goals[id]
		var w: float = float(def.get("weight", 1.0))
		if str(id) == "vendetta" and (g["enemies"] as Array).is_empty():
			w = 0.0
		if str(id) == "recruit" and (g["members"] as Array).size() >= int(GangDB.num("members", "max_total", 22.0)):
			w = 0.0
		if w > 0.0:
			ids.append(str(id))
			weights.append(w)
			total += w
	if ids.is_empty():
		return {}
	var roll: float = _rng.randf() * total
	var pick: String = str(ids[ids.size() - 1])
	for i in ids.size():
		roll -= float(weights[i])
		if roll <= 0.0:
			pick = str(ids[i])
			break
	var def2: Dictionary = goals[pick]
	var days: Array = def2.get("days", [4, 8])
	var need: int = _rng.randi_range(int(days[0]), int(days[1]))
	var target: String = ""
	if pick == "vendetta":
		var en: Array = g["enemies"]
		target = str(en[_rng.randi() % en.size()])
	return {"type": pick, "need": need, "done": 0, "target": target}


static func _rr(key: String, lo: float, hi: float) -> float:
	var r: Variant = GangDB.section("goal_effects").get(key, [lo, hi])
	if r is Array and (r as Array).size() >= 2:
		return _rng.randf_range(float(r[0]), float(r[1]))
	return _rng.randf_range(lo, hi)


static func _fx(key: String, default_value: float) -> float:
	return GangDB.num("goal_effects", key, default_value)


static func _push_news(day: int, text: String) -> void:
	news.append({"day": day, "text": text})
	while news.size() > 30:
		news.remove_at(0)


## Fa avanzare la simulazione fino al giorno indicato (max 10 giorni per volta).
## Restituisce le righe di cronaca nuove.
static func advance_to(day: int) -> Array:
	var out: Array = []
	if _rng == null:
		return out
	if last_day < 0:
		last_day = day
	if day - last_day > 10:
		last_day = day - 10
	while last_day < day:
		last_day += 1
		var lines: Array = _daily(last_day)
		for l in lines:
			_push_news(last_day, str(l))
		out.append_array(lines)
	if not out.is_empty():
		version += 1
	return out


static func _daily(day: int) -> Array:
	var lines: Array = []
	var eco: Dictionary = GangDB.section("economy")
	for g in gangs.duplicate():
		g["encounters_today"] = 0
		var n: int = (g["members"] as Array).size()
		var w: float = float(g["wealth"]) + float(n) * (float(eco.get("income_per_member", 3.0)) - float(eco.get("upkeep_per_member", 2.6)))
		g["wealth"] = clampf(w, 0.0, float(eco.get("max_wealth", 600.0)))
		if float(g["wealth"]) <= 0.0 and n > 4 and _rng.randf() < float(eco.get("desert_chance", 0.12)):
			_pop_member(g)
			lines.append(GangDB.fmt("news_desert", {"gang": g["name"]}))
		var goal: Dictionary = g["goal"]
		if goal.is_empty():
			g["goal"] = _pick_goal(g)
			continue
		goal["done"] = int(goal["done"]) + 1
		if int(goal["done"]) >= int(goal["need"]):
			lines.append_array(_complete_goal(g))
			g["goal"] = _pick_goal(g)
	# nuove bande al posto di quelle sciolte
	var count: int = int(GangDB.data().get("count", 3))
	var due: Array = []
	for d in _respawns:
		if int(d) <= day:
			due.append(d)
	for d in due:
		_respawns.erase(d)
		if gangs.size() < count:
			var ng: Dictionary = _make_gang(gangs.size(), count)
			gangs.append(ng)
			_link_nearest(ng)
			ng["goal"] = _pick_goal(ng)
			lines.append(GangDB.fmt("news_new_gang", {"gang": ng["name"]}))
			version += 1
	return lines


static func _complete_goal(g: Dictionary) -> Array:
	var out: Array = []
	var goal: Dictionary = g["goal"]
	var v: Dictionary = {"gang": g["name"]}
	match str(goal["type"]):
		"expand":
			g["extra_radius"] = float(g["extra_radius"]) + _rr("expand_gain", 50.0, 100.0)
			var rival: Dictionary = {}
			for eid in g["enemies"]:
				var e: Dictionary = by_id(str(eid))
				if not e.is_empty() and (g["hideout"] as Vector2).distance_to(e["hideout"]) < radius_of(g) + radius_of(e):
					rival = e
					break
			if rival.is_empty():
				out.append(GangDB.fmt("news_expand", v))
			else:
				rival["extra_radius"] = float(rival["extra_radius"]) - _fx("expand_enemy_loss", 40.0)
				v["enemy"] = rival["name"]
				out.append(GangDB.fmt("news_expand_war", v))
		"recruit":
			var cost: float = maxf(1.0, GangDB.num("economy", "recruit_cost", 15.0))
			var room: int = int(GangDB.num("members", "max_total", 22.0)) - (g["members"] as Array).size()
			var want: int = mini(int(round(_rr("recruit_count", 2.0, 4.0))), room)
			var afford: int = int(floor(float(g["wealth"]) / cost))
			var take: int = maxi(mini(want, afford), 1)
			if room <= 0:
				take = 0
			g["wealth"] = maxf(0.0, float(g["wealth"]) - float(take) * cost)
			for i in take:
				(g["members"] as Array).append({"name": _member_name(), "role": "pistolero"})
			v["n"] = take
			out.append(GangDB.fmt("news_recruit", v))
		"vendetta":
			var enemy: Dictionary = by_id(str(goal.get("target", "")))
			if enemy.is_empty():
				out.append(GangDB.fmt("news_loot", v))
			else:
				var pa: float = strength(g) * _rng.randf_range(0.7, 1.3)
				var pb: float = strength(enemy) * _rng.randf_range(0.7, 1.3)
				var winner: Dictionary = g if pa >= pb else enemy
				var loser: Dictionary = enemy if pa >= pb else g
				var losses: int = int(round(_rr("vendetta_losses", 1.0, 3.0)))
				_lose_members(loser, losses)
				var share: float = _fx("vendetta_loot_share", 0.2)
				var spoils: float = float(loser["wealth"]) * share
				loser["wealth"] = float(loser["wealth"]) - spoils
				winner["wealth"] = minf(float(winner["wealth"]) + spoils, GangDB.num("economy", "max_wealth", 600.0))
				loser["extra_radius"] = float(loser["extra_radius"]) - _fx("vendetta_radius_loss", 30.0)
				out.append(GangDB.fmt("news_vendetta", {"winner": winner["name"], "loser": loser["name"], "n": losses}))
				var dis: String = _check_dissolve(loser)
				if dis != "":
					out.append(dis)
		"loot":
			g["wealth"] = minf(float(g["wealth"]) + _rr("loot_wealth", 60.0, 200.0), GangDB.num("economy", "max_wealth", 600.0))
			if _rng.randf() < _fx("loot_loss_chance", 0.2):
				_pop_member(g)
				out.append(GangDB.fmt("news_loot_loss", v))
			else:
				out.append(GangDB.fmt("news_loot", v))
		_:
			pass
	var rumor: String = _rumor_line(g)
	if rumor != "":
		out.append(rumor)
	var dis_self: String = _check_dissolve(g)
	if dis_self != "":
		out.append(dis_self)
	return out


static func _rumor_line(g: Dictionary) -> String:
	if bool(g["discovered"]) or bool(g["rumor_told"]) or not gangs.has(g):
		return ""
	g["rumor_told"] = true
	g["rumored"] = true
	return GangDB.fmt("rumor", {"gang": g["name"], "dir": direction_text(g["hideout"])})


# ------------------------------------------------------------------ membri

static func _pop_member(g: Dictionary) -> void:
	var members: Array = g["members"]
	if members.size() <= 1:
		return
	for role in ["pistolero", "luogotenente"]:
		for i in range(members.size() - 1, 0, -1):
			if str(members[i]["role"]) == role:
				members.remove_at(i)
				return
	members.remove_at(members.size() - 1)


static func _lose_members(g: Dictionary, n: int) -> void:
	for i in n:
		_pop_member(g)


static func _kill_boss(g: Dictionary) -> void:
	var members: Array = g["members"]
	if members.is_empty():
		return
	members.remove_at(0)
	if members.is_empty():
		return
	var idx: int = 0
	for i in members.size():
		if str(members[i]["role"]) == "luogotenente":
			idx = i
			break
	var m: Dictionary = members[idx]
	members.remove_at(idx)
	m["role"] = "capo"
	members.insert(0, m)
	g["boss"] = m["name"]


## Scioglie la banda se è rimasta troppo piccola. Restituisce la riga di cronaca o "".
static func _check_dissolve(g: Dictionary) -> String:
	if (g["members"] as Array).size() > int(GangDB.num("members", "dissolve_below", 1.0)):
		return ""
	var id: String = str(g["id"])
	var found: bool = false
	for i in gangs.size():
		if str(gangs[i]["id"]) == id:
			gangs.remove_at(i)
			found = true
			break
	if not found:
		return ""
	for o in gangs:
		(o["enemies"] as Array).erase(id)
	var rd: Array = GangDB.data().get("respawn_days", [8, 14])
	_respawns.append(last_day + _rng.randi_range(int(rd[0]), int(rd[1])))
	version += 1
	return GangDB.fmt("news_dissolve", {"gang": g["name"]})


# ------------------------------------------------------------------ incontri

static func is_safe_today(g: Dictionary) -> bool:
	return int(g["safe_day"]) == last_day


static func can_patrol(g: Dictionary) -> bool:
	var max_day: int = int(GangDB.num("patrol", "max_per_day", 2.0))
	return int(g["encounters_today"]) < max_day and not is_safe_today(g)


static func note_encounter(g: Dictionary) -> void:
	g["encounters_today"] = int(g["encounters_today"]) + 1


static func toll_cost(g: Dictionary) -> int:
	var e: Dictionary = GangDB.section("encounter")
	return roundi(float(e.get("toll_base", 12)) + float(e.get("toll_per_member", 1.5)) * float((g["members"] as Array).size()))


static func payoff_cost(g: Dictionary) -> int:
	return roundi(float(toll_cost(g)) * GangDB.num("encounter", "payoff_mult", 2.5))


static func donate_cost() -> int:
	return int(GangDB.num("encounter", "donate_amount", 30.0))


## Bersaglio di una missione al fianco della banda: la sua vendetta o il suo primo nemico.
static func help_target(g: Dictionary) -> Dictionary:
	var goal: Dictionary = g["goal"]
	if not goal.is_empty() and str(goal["type"]) == "vendetta":
		var t: Dictionary = by_id(str(goal.get("target", "")))
		if not t.is_empty():
			return t
	for eid in g["enemies"]:
		var e: Dictionary = by_id(str(eid))
		if not e.is_empty():
			return e
	return {}


static func _option_state(g: Dictionary, id: String) -> Dictionary:
	var money: int = int(PlayerState.money)
	var res: Dictionary = {"enabled": true, "reason": "", "cost": 0, "enemy": ""}
	match id:
		"toll":
			res["cost"] = toll_cost(g)
		"pay_off":
			res["cost"] = payoff_cost(g)
		"donate":
			res["cost"] = donate_cost()
		"rest":
			if int(g["rested_day"]) == last_day:
				res["enabled"] = false
				res["reason"] = "Hai già riposato qui oggi."
		"help_goal":
			var t: Dictionary = help_target(g)
			if t.is_empty():
				res["enabled"] = false
				res["reason"] = "Non hanno nemici da combattere ora."
			else:
				res["enemy"] = str(t["name"])
				if float(PlayerState.health) < GangDB.num("encounter", "help_min_health", 40.0):
					res["enabled"] = false
					res["reason"] = "Sei troppo malconcio per combattere."
		_:
			pass
	if int(res["cost"]) > 0 and money < int(res["cost"]):
		res["enabled"] = false
		res["reason"] = GangDB.text("no_money")
	return res


static func options_for(gang_id: String) -> Array:
	var out: Array = []
	var g: Dictionary = by_id(gang_id)
	if g.is_empty():
		return out
	var defs: Dictionary = GangDB.section("options")
	var stance_def: Variant = GangDB.section("stances").get(stance(g), {})
	var ids: Array = []
	if stance_def is Dictionary:
		ids = stance_def.get("options", [])
	for id in ids:
		var state: Dictionary = _option_state(g, str(id))
		var def: Variant = defs.get(str(id), {})
		var label: String = str(id)
		var tip: String = ""
		if def is Dictionary:
			label = str(def.get("label", label))
			tip = str(def.get("tip", ""))
		var v: Dictionary = {"cost": state["cost"], "gang": g["name"], "enemy": state["enemy"]}
		out.append({
			"id": str(id),
			"label": label.format(v),
			"tip": tip.format(v) if bool(state["enabled"]) else str(state["reason"]),
			"enabled": bool(state["enabled"]),
		})
	return out


static func intro_text(gang_id: String) -> String:
	var g: Dictionary = by_id(gang_id)
	if g.is_empty():
		return ""
	var stance_def: Variant = GangDB.section("stances").get(stance(g), {})
	var intro: String = ""
	if stance_def is Dictionary:
		intro = str(stance_def.get("intro", ""))
	return intro.format({"gang": g["name"], "boss": g["boss"]})


static func _check(base_key: String, per_key: String, stat: String, extra: float = 0.0) -> bool:
	var c: Dictionary = GangDB.section("checks")
	var chance: float = float(c.get(base_key, 0.4)) + float(c.get(per_key, 0.05)) * float(PlayerState.get_stat(stat)) + extra
	chance = clampf(chance, float(c.get("min", 0.1)), float(c.get("max", 0.9)))
	return _rng.randf() < chance


## Composizione del gruppo che affronta il giocatore (id nemici di combat.json).
static func fight_group(g: Dictionary) -> Array:
	var e: Dictionary = GangDB.section("encounter")
	var fg: Dictionary = e.get("fight_group", {})
	var n: int = (g["members"] as Array).size()
	var lo: int = int(fg.get("min", 2))
	var hi: int = int(fg.get("max", 4))
	var per: int = maxi(1, int(fg.get("per_members", 5)))
	var size: int = mini(clampi(lo + floori(float(n) / float(per)), lo, hi), n)
	var ids: Array = []
	if n >= int(e.get("boss_min_members", 6)) and _rng.randf() < float(e.get("boss_chance", 0.25)):
		ids.append("capobanda")
		size -= 1
	for i in maxi(size, 1):
		ids.append("bandito")
	return ids


static func _fight_info(g: Dictionary, ambush: bool, ally_id: String = "") -> Dictionary:
	return {
		"gang": str(g["id"]),
		"enemies": fight_group(g),
		"title": GangDB.fmt("combat_title", {"gang": g["name"]}),
		"ambush": ambush,
		"ally": ally_id,
	}


## Applica la scelta del giocatore. Restituisce {lines, close, combat}.
## close=false: la scelta non è andata a buon fine (es. pochi soldi) e l'incontro continua.
## combat non vuoto: dopo la chiusura va avviato lo scontro descritto.
static func resolve(gang_id: String, option_id: String) -> Dictionary:
	var res: Dictionary = {"lines": [], "close": true, "combat": {}}
	var g: Dictionary = by_id(gang_id)
	if g.is_empty():
		return res
	var d: Dictionary = GangDB.section("deltas")
	var lines: Array = res["lines"]
	var v: Dictionary = {"gang": g["name"], "boss": g["boss"]}
	var state: Dictionary = _option_state(g, option_id)
	if not bool(state["enabled"]):
		lines.append(str(state["reason"]))
		res["close"] = false
		return res
	match option_id:
		"toll":
			PlayerState.spend_money(int(state["cost"]))
			g["wealth"] = float(g["wealth"]) + float(state["cost"])
			g["safe_day"] = last_day
			add_rep(gang_id, float(d.get("toll", 2)))
			lines.append(GangDB.fmt("toll_paid", v))
		"talk":
			var extra: float = effective_rep(g) / maxf(1.0, GangDB.num("checks", "talk_rep_div", 200.0))
			if _check("talk_base", "talk_per_stat", "carisma", extra):
				g["safe_day"] = last_day
				g["known_goal"] = true
				discover(g)
				add_rep(gang_id, float(d.get("talk_ok", 6)))
				lines.append(GangDB.fmt("talk_ok", v))
			else:
				add_rep(gang_id, float(d.get("talk_fail", -4)))
				lines.append(GangDB.fmt("talk_fail", v))
		"leave":
			if _check("leave_base", "leave_per_stat", "agilita"):
				lines.append(GangDB.fmt("leave_ok", v))
			else:
				lines.append(GangDB.fmt("leave_fail", v))
				res["combat"] = _fight_info(g, true)
		"fight":
			lines.append(GangDB.fmt("fight_start", v))
			res["combat"] = _fight_info(g, false)
		"pay_off":
			PlayerState.spend_money(int(state["cost"]))
			g["wealth"] = float(g["wealth"]) + float(state["cost"])
			g["safe_day"] = last_day
			add_rep(gang_id, float(d.get("pay_off", 8)))
			lines.append(GangDB.fmt("pay_off_ok", v))
		"flee":
			if _check("flee_base", "flee_per_stat", "agilita"):
				add_rep(gang_id, float(d.get("flee", -1)))
				lines.append(GangDB.fmt("flee_ok", v))
			else:
				lines.append(GangDB.fmt("flee_fail", v))
				res["combat"] = _fight_info(g, true)
		"rest":
			PlayerState.heal(int(GangDB.num("encounter", "rest_heal", 25.0)))
			g["rested_day"] = last_day
			discover(g)
			add_rep(gang_id, float(d.get("rest", 1)))
			lines.append(GangDB.fmt("rest", v))
		"rumors":
			g["known_goal"] = true
			discover(g)
			add_rep(gang_id, float(d.get("rumors", 1)))
			lines.append(GangDB.fmt("rumors_goal", {"goal": goal_label(g)}))
			lines.append(GangDB.fmt("rumors_enemies", {"enemies": enemy_names(g)}))
			var hidden: Array = []
			for o in gangs:
				if str(o["id"]) != gang_id and not bool(o["discovered"]) and not bool(o["rumored"]):
					hidden.append(o)
			if not hidden.is_empty():
				var o2: Dictionary = hidden[_rng.randi() % hidden.size()]
				o2["rumored"] = true
				o2["rumor_told"] = true
				version += 1
				lines.append(GangDB.fmt("rumors_gang", {"gang": o2["name"], "dir": direction_text(o2["hideout"])}))
		"donate":
			PlayerState.spend_money(int(state["cost"]))
			g["wealth"] = minf(float(g["wealth"]) + float(state["cost"]), GangDB.num("economy", "max_wealth", 600.0))
			add_rep(gang_id, float(d.get("donate", 5)))
			lines.append(GangDB.fmt("donate", v))
		"help_goal":
			var t: Dictionary = help_target(g)
			if t.is_empty():
				lines.append(GangDB.fmt("rumors_none", v))
			else:
				v["enemy"] = t["name"]
				lines.append(GangDB.fmt("help_start", v))
				res["combat"] = _fight_info(t, false, gang_id)
		_:
			lines.append(GangDB.fmt("bye", v))
	version += 1
	return res


## Conseguenze di uno scontro con una banda. outcome: "won", "lost", "fled", "unknown".
## Restituisce le righe di cronaca da mostrare.
static func on_clash(gang_id: String, outcome: String, enemy_ids: Array, ally_id: String = "") -> Array:
	var lines: Array = []
	var g: Dictionary = by_id(gang_id)
	if g.is_empty():
		return lines
	var d: Dictionary = GangDB.section("deltas")
	var v: Dictionary = {"gang": g["name"], "boss": g["boss"]}
	match outcome:
		"won":
			var boss_down: bool = enemy_ids.has("capobanda")
			var killed: int = enemy_ids.size() - (1 if boss_down else 0)
			_lose_members(g, killed)
			v["killed"] = enemy_ids.size()
			lines.append(GangDB.fmt("clash_won", v))
			add_rep(gang_id, float(d.get("clash_won", -12)))
			if boss_down and (g["members"] as Array).size() > 0:
				v["boss"] = g["boss"]
				_kill_boss(g)
				add_rep(gang_id, float(d.get("boss_killed", -10)))
				ReputationSystem.add("legge", float(d.get("law_on_boss", 4)))
				lines.append(GangDB.fmt("clash_boss", v))
			ReputationSystem.add("legge", float(d.get("law_on_clash", 2)))
			ReputationSystem.add("cittadini", float(d.get("citizens_on_clash", 1)))
			if ally_id != "":
				var ally: Dictionary = by_id(ally_id)
				if not ally.is_empty():
					add_rep(ally_id, float(d.get("help_goal", 10)))
					var goal: Dictionary = ally["goal"]
					if not goal.is_empty():
						var bonus: int = int(ceil(float(goal["need"]) * GangDB.num("goal_effects", "ally_progress", 0.4)))
						goal["done"] = mini(int(goal["done"]) + bonus, int(goal["need"]))
		"lost":
			add_rep(gang_id, float(d.get("clash_lost", -2)))
			lines.append(GangDB.fmt("clash_lost", v))
		_:
			add_rep(gang_id, float(d.get("clash_other", -3)))
			lines.append(GangDB.fmt("clash_other", v))
	var dis: String = _check_dissolve(g)
	if dis != "":
		lines.append(dis)
		_push_news(maxi(last_day, 0), dis)
	version += 1
	return lines
