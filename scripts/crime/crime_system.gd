class_name CrimeSystem
extends RefCounted
## Criminalità (Feature 20): logica senza UI, stato in memoria.
## Quattro crimini: furto (borseggio), rapina (di giorno a mano armata, di notte scasso),
## ricatto e contrabbando. Ogni crimine alza la notorietà ("heat"); la Feature 21 (legge)
## leggerà heat, wanted_level() e bounty() per taglie, arresti e inseguimenti.

static var heat: float = 0.0
static var history: Array = []
static var cooldowns: Dictionary = {}
static var counts: Dictionary = {}
static var total_loot: int = 0
static var last_day: int = 0
static var last_smuggle_day: int = -1
static var _attempts: int = 0
static var _salt: int = 0


# ---------------------------------------------------------------- stato

static func reset() -> void:
	heat = 0.0
	history = []
	cooldowns = {}
	counts = {}
	total_loot = 0
	_attempts = 0
	last_smuggle_day = -1
	_salt = WorldSeed.rng_for("crime_salt").randi()
	last_day = current_day()


static func current_day() -> int:
	var v = GameTime.get("day")
	if v == null and GameTime.has_method("day"):
		v = GameTime.call("day")
	return int(v) if v != null else 0


static func current_hour() -> float:
	var v = GameTime.get("hour")
	if v == null and GameTime.has_method("hour"):
		v = GameTime.call("hour")
	return float(v) if v != null else 12.0


static func is_night() -> bool:
	var h := current_hour()
	return h >= float(CrimeDB.value("night_from", 21)) or h < float(CrimeDB.value("night_to", 5))


static func advance_to(day: int) -> void:
	var elapsed := mini(day - last_day, 10)
	if elapsed > 0:
		var decay := float(CrimeDB.section("heat").get("decay_per_day", 5))
		heat = maxf(0.0, heat - decay * float(elapsed))
	last_day = day


# ---------------------------------------------------------------- notorietà (per la Feature 21)

static func wanted_level() -> int:
	var stars = CrimeDB.section("heat").get("stars", [10, 25, 45, 65, 85])
	var n := 0
	for s in stars:
		if heat >= float(s):
			n += 1
	return n


static func wanted_name() -> String:
	var lvl := wanted_level()
	if lvl <= 0:
		return ""
	var names = CrimeDB.section("heat").get("star_names", [])
	if names is Array and lvl - 1 < names.size():
		return str(names[lvl - 1])
	return "Ricercato"


static func bounty() -> int:
	var h := CrimeDB.section("heat")
	if heat < float(h.get("bounty_min_heat", 10)):
		return 0
	return int(round(heat * float(h.get("bounty_per_heat", 5)) / 5.0)) * 5


static func hud_text() -> String:
	var b := bounty()
	if b <= 0:
		return ""
	return "%s - taglia $%d" % [wanted_name(), b]


static func add_heat(base: float, ctx: Dictionary) -> float:
	var h := CrimeDB.section("heat")
	var mult := 1.0 + minf(float(ctx.get("witnesses", 0)), 4.0) * float(h.get("witness_mult", 0.25))
	if bool(ctx.get("sheriff", false)):
		mult += float(h.get("sheriff_mult", 1.0))
	var amount := base * mult
	heat = clampf(heat + amount, 0.0, float(h.get("max", 100)))
	return amount


# ---------------------------------------------------------------- utilità

static func _rng(channel: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%d_%s" % [_salt, channel])
	return r


static func _clamp_chance(p: float) -> float:
	return clampf(p, float(CrimeDB.value("chance_min", 0.05)), float(CrimeDB.value("chance_max", 0.92)))


static func _stat(stat: String) -> float:
	return float(PlayerState.get_stat(stat))


static func money() -> int:
	var v = PlayerState.get("money")
	return int(v) if v != null else 0


static func _rep(group: String, amount: float) -> void:
	if amount != 0.0:
		ReputationSystem.add(group, amount)


static func _apply_rep(rep, ctx: Dictionary) -> void:
	if not (rep is Dictionary):
		return
	var seen: bool = int(ctx.get("witnesses", 0)) > 0 or bool(ctx.get("sheriff", false))
	var k := 1.0 if seen else float(CrimeDB.value("unseen_rep_mult", 0.25))
	for g in rep:
		_rep(str(g), float(rep[g]) * k)


static func _blank(kind: String) -> Dictionary:
	return {"kind": kind, "ok": false, "lines": [], "loot": 0, "combat": [], "combat_title": ""}


static func _log(kind: String, text: String, loot: int) -> void:
	history.push_front({"day": current_day(), "kind": kind, "text": text, "loot": loot})
	while history.size() > 10:
		history.pop_back()
	counts[kind] = int(counts.get(kind, 0)) + 1
	total_loot += maxi(loot, 0)


static func on_cooldown(key: String) -> bool:
	return int(cooldowns.get(key, -999)) > current_day()


static func set_cooldown(key: String, days: int) -> void:
	cooldowns[key] = current_day() + days


static func _skip_hours(hours: int) -> void:
	if GameTime.has_method("skip_to_hour"):
		var target := int(fposmod(current_hour() + float(hours), 24.0))
		GameTime.call("skip_to_hour", target)


# ---------------------------------------------------------------- accesso ai dati degli NPC (dizionari o oggetti)

static func npc_get(n, key: String, default = null):
	if n is Dictionary:
		return n.get(key, default)
	if n is Object:
		var v = n.get(key)
		return default if v == null else v
	return default


## "inside" può essere un booleano oppure l'id/nome dell'edificio in cui si trova l'NPC.
static func npc_inside(n) -> bool:
	var v = npc_get(n, "inside", false)
	if v == null:
		return false
	if v is bool:
		return v
	if v is String or v is StringName:
		return str(v) != "" and str(v).to_lower() != "false"
	if v is int or v is float:
		return v != 0
	if v is Dictionary or v is Array:
		return not v.is_empty()
	return true


static func npc_job(n) -> String:
	return str(npc_get(n, "job", "")).to_lower()


static func npc_stat(n, stat: String) -> float:
	var s = npc_get(n, "stats", null)
	if s is Dictionary and s.has(stat):
		return float(s[stat])
	var v = npc_get(n, stat, null)
	return float(v) if v != null else 4.0


static func is_protected(n) -> bool:
	var job := npc_job(n)
	for p in CrimeDB.value("protected_jobs", []):
		if job.find(str(p)) >= 0:
			return true
	return false


static func wealth_range(job: String) -> Array:
	var w := CrimeDB.section("wealth")
	for k in w:
		if str(k) != "default" and job.find(str(k)) >= 0:
			return w[k]
	return w.get("default", [3, 10])


static func _is_trade(job: String) -> bool:
	for t in CrimeDB.value("trade_jobs", []):
		if job.find(str(t)) >= 0:
			return true
	return false


# ---------------------------------------------------------------- furto

static func chance_pickpocket(npc, ctx: Dictionary) -> float:
	var c := CrimeDB.section("pickpocket")
	var p := float(c.get("base", 0.45))
	p += (_stat("agilita") - npc_stat(npc, "agilita")) * float(c.get("per_stat", 0.04))
	p -= float(ctx.get("witnesses", 0)) * float(c.get("witness_penalty", 0.04))
	if bool(ctx.get("night", false)):
		p += float(c.get("night_bonus", 0.1))
	return _clamp_chance(p)


static func do_pickpocket(npc, ctx: Dictionary) -> Dictionary:
	_attempts += 1
	var c := CrimeDB.section("pickpocket")
	var rng := _rng("pp_%d_%d" % [current_day(), _attempts])
	var res := _blank("pickpocket")
	var id := str(npc_get(npc, "id", ""))
	var victim := str(npc_get(npc, "name", "il passante"))
	var vars := {"name": victim}
	set_cooldown("pp_" + id, int(c.get("victim_cooldown_days", 2)))
	if rng.randf() < chance_pickpocket(npc, ctx):
		var r := wealth_range(npc_job(npc))
		var loot := rng.randi_range(int(r[0]), int(r[1]))
		PlayerState.add_money(loot)
		vars["loot"] = loot
		res["ok"] = true
		res["loot"] = loot
		res["lines"].append(CrimeDB.fmt(CrimeDB.pick(c.get("text_ok", []), rng, "Intaschi ${loot}."), vars))
		add_heat(float(c.get("heat_ok", 3)), ctx)
		_apply_rep(c.get("rep_ok", {}), ctx)
		_log("furto", "Borseggiato %s: $%d" % [victim, loot], loot)
	else:
		res["lines"].append(CrimeDB.fmt(CrimeDB.pick(c.get("text_fail", []), rng, "{name} ti scopre."), vars))
		add_heat(float(c.get("heat_fail", 9)), ctx)
		_apply_rep(c.get("rep_fail", {}), {"witnesses": 1})
		if id != "":
			NPCRegistry.change_relationship(id, int(c.get("relation_fail", -20)))
		if rng.randf() < float(c.get("punch_chance", 0.3)):
			var dr = c.get("punch_damage", [2, 6])
			var dmg := rng.randi_range(int(dr[0]), int(dr[1]))
			PlayerState.damage(dmg)
			vars["dmg"] = dmg
			res["lines"].append(CrimeDB.fmt(str(c.get("text_punch", "")), vars))
		_log("furto", "Sorpreso a derubare %s" % victim, 0)
	return res


# ---------------------------------------------------------------- rapina

static func chance_robbery(target: Dictionary, ctx: Dictionary) -> float:
	var r := CrimeDB.section("robbery")
	var mode := "night" if bool(ctx.get("night", false)) else "day"
	var m: Dictionary = r.get(mode, {})
	var t: Dictionary = target.get(mode, {})
	var p := float(m.get("base", 0.5)) - float(t.get("difficulty", 0.25))
	p += _stat("mira") * float(m.get("mira", 0.0))
	p += _stat("carisma") * float(m.get("carisma", 0.0))
	p += _stat("agilita") * float(m.get("agilita", 0.0))
	p -= float(ctx.get("witnesses", 0)) * float(m.get("witness_penalty", 0.0))
	return _clamp_chance(p)


static func do_robbery(target: Dictionary, place: String, key: String, ctx: Dictionary) -> Dictionary:
	_attempts += 1
	var r := CrimeDB.section("robbery")
	var night := bool(ctx.get("night", false))
	var mode := "night" if night else "day"
	var t: Dictionary = target.get(mode, {})
	var rng := _rng("rob_%d_%d" % [current_day(), _attempts])
	var res := _blank("robbery")
	var vars := {"place": place}
	set_cooldown("rob_" + key, int(r.get("cooldown_days", 3)))
	if rng.randf() < chance_robbery(target, ctx):
		var lr = t.get("loot", [30, 80])
		var loot := rng.randi_range(int(lr[0]), int(lr[1]))
		PlayerState.add_money(loot)
		vars["loot"] = loot
		res["ok"] = true
		res["loot"] = loot
		res["lines"].append(CrimeDB.fmt(CrimeDB.pick(r.get("text_ok_" + mode, []), rng, "Rapina riuscita: ${loot}."), vars))
		add_heat(float(t.get("heat", 14)), ctx)
		_apply_rep(t.get("rep", {}), ctx)
		_log("rapina", "%s: $%d" % [place, loot], loot)
	else:
		res["lines"].append(CrimeDB.fmt(CrimeDB.pick(r.get("text_fail_" + mode, []), rng, "Ti scoprono!"), vars))
		add_heat(float(t.get("heat", 14)) * float(r.get("heat_fail_mult", 1.3)), ctx)
		_apply_rep(t.get("rep", {}), ctx)
		var ids: Array = []
		for i in int(t.get("guards", 1)):
			ids.append(str(r.get("guard_enemy", "bandito")))
		res["combat"] = ids
		res["combat_title"] = "Rapina fallita: %s" % place
		_log("rapina", "Rapina fallita: %s" % place, 0)
	return res


# ---------------------------------------------------------------- ricatto

static func _secret_rng(npc) -> RandomNumberGenerator:
	return _rng("secret_" + str(npc_get(npc, "id", "")))


static func has_secret(npc) -> bool:
	var chance := float(CrimeDB.section("blackmail").get("secret_chance", 0.55))
	return _secret_rng(npc).randf() < chance


static func secret_text(npc) -> String:
	var rng := _rng("secret_text_" + str(npc_get(npc, "id", "")))
	return CrimeDB.pick(CrimeDB.section("blackmail").get("secrets", []), rng, "nasconde qualcosa")


## Probabilità mostrata in UI (non rivela se l'NPC ha davvero un segreto).
static func chance_blackmail_display(npc, ctx: Dictionary) -> float:
	var c := CrimeDB.section("blackmail")
	var sc := float(c.get("secret_chance", 0.55))
	var p := _blackmail_base(npc, ctx)
	p += sc * float(c.get("secret_bonus", 0.2)) - (1.0 - sc) * float(c.get("bluff_penalty", 0.3))
	return _clamp_chance(p)


static func _blackmail_base(npc, ctx: Dictionary) -> float:
	var c := CrimeDB.section("blackmail")
	var p := float(c.get("base", 0.5))
	p += (_stat("carisma") - npc_stat(npc, "carisma")) * float(c.get("per_stat", 0.05))
	p -= float(ctx.get("witnesses", 0)) * float(c.get("witness_penalty", 0.05))
	return p


static func do_blackmail(npc, ctx: Dictionary) -> Dictionary:
	_attempts += 1
	var c := CrimeDB.section("blackmail")
	var rng := _rng("bm_%d_%d" % [current_day(), _attempts])
	var res := _blank("blackmail")
	var id := str(npc_get(npc, "id", ""))
	var victim := str(npc_get(npc, "name", "il cittadino"))
	var job := npc_job(npc)
	var secret := has_secret(npc)
	var p := _blackmail_base(npc, ctx)
	if secret:
		p += float(c.get("secret_bonus", 0.2))
	else:
		p -= float(c.get("bluff_penalty", 0.3))
	var vars := {"name": victim, "secret": secret_text(npc)}
	set_cooldown("bm_" + id, int(c.get("cooldown_days", 3)))
	if rng.randf() < _clamp_chance(p):
		var wr := wealth_range(job)
		var pm = c.get("pay_mult", [1.5, 3.0])
		var loot := int(round(float(rng.randi_range(int(wr[0]), int(wr[1]))) * rng.randf_range(float(pm[0]), float(pm[1]))))
		if not secret:
			loot = int(round(float(loot) * float(c.get("bluff_pay_mult", 0.6))))
		loot = maxi(loot, 1)
		PlayerState.add_money(loot)
		vars["loot"] = loot
		res["ok"] = true
		res["loot"] = loot
		var key := "text_ok_secret" if secret else "text_ok_bluff"
		res["lines"].append(CrimeDB.fmt(CrimeDB.pick(c.get(key, []), rng, "{name} paga ${loot}."), vars))
		add_heat(float(c.get("heat_ok", 4)), ctx)
		_apply_rep(c.get("rep_ok", {}), ctx)
		if id != "":
			NPCRegistry.change_relationship(id, int(c.get("relation_ok", -25)))
		_log("ricatto", "Ricattato %s: $%d" % [victim, loot], loot)
	else:
		var fkey := "text_fail_secret" if secret else "text_fail_bluff"
		res["lines"].append(CrimeDB.fmt(CrimeDB.pick(c.get(fkey, []), rng, "{name} rifiuta."), vars))
		add_heat(float(c.get("heat_fail", 10)), ctx)
		_apply_rep(c.get("rep_fail", {}), {"witnesses": 1})
		if _is_trade(job):
			_apply_rep(c.get("rep_trade_fail", {}), {"witnesses": 1})
		if id != "":
			NPCRegistry.change_relationship(id, int(c.get("relation_fail", -30)))
		_log("ricatto", "Ricatto fallito con %s" % victim, 0)
	return res


# ---------------------------------------------------------------- contrabbando

static func _market(good: String) -> float:
	return float(EconomySystem.index(good))


## Guadagno atteso in percentuale (margine medio x indice di mercato del bene).
static func expected_profit_pct(cargo: Dictionary) -> int:
	var m = cargo.get("margin", [1.3, 1.7])
	var avg := (float(m[0]) + float(m[1])) * 0.5
	return int(round((avg * _market(str(cargo.get("good", ""))) - 1.0) * 100.0))


static func smuggle_block_reason(ctx: Dictionary, cargo: Dictionary) -> String:
	var s := CrimeDB.section("smuggling")
	if float(ctx.get("distance", 0.0)) < float(s.get("min_distance", 650)):
		return "Il contatto non si fa vedere vicino al paese: allontanati nel deserto."
	if last_smuggle_day >= current_day():
		return "Hai già fatto una consegna oggi."
	if ReputationSystem.value("gang") < float(s.get("min_gang_rep", -19)):
		return "Le bande non vogliono trattare con te."
	if money() < int(cargo.get("cost", 0)):
		return "Non hai abbastanza soldi per il carico."
	return ""


static func do_smuggle(cargo: Dictionary, ctx: Dictionary) -> Dictionary:
	_attempts += 1
	var s := CrimeDB.section("smuggling")
	var rng := _rng("sm_%d_%d" % [current_day(), _attempts])
	var res := _blank("smuggling")
	var cost := int(cargo.get("cost", 0))
	var vars := {"cost": cost}
	PlayerState.spend_money(cost)
	last_smuggle_day = current_day()
	var patrol := float(s.get("patrol_chance", 0.35)) + heat * float(s.get("patrol_heat_mult", 0.004))
	if bool(ctx.get("night", false)):
		patrol *= float(s.get("patrol_night_mult", 0.7))
	var delivered := true
	if rng.randf() < clampf(patrol, 0.0, 0.9):
		var e = s.get("escape", {})
		var esc := float(e.get("base", 0.45)) + _stat("agilita") * float(e.get("agilita", 0.04))
		esc += _stat("carisma") * float(e.get("carisma", 0.02)) - heat * float(e.get("heat_pen", 0.003))
		if rng.randf() < _clamp_chance(esc):
			res["lines"].append(str(s.get("text_patrol_escaped", "")))
		else:
			delivered = false
			res["lines"].append(CrimeDB.fmt(str(s.get("text_patrol_caught", "")), vars))
			add_heat(float(s.get("heat_fail", 14)), ctx)
			_apply_rep(s.get("rep_fail", {}), {"witnesses": 1})
			if rng.randf() < float(s.get("combat_chance", 0.4)):
				var cr = s.get("combat_count", [1, 2])
				var ids: Array = []
				for i in rng.randi_range(int(cr[0]), int(cr[1])):
					ids.append(str(s.get("combat_enemy", "bandito")))
				res["combat"] = ids
				res["combat_title"] = str(s.get("combat_title", "Pattuglia"))
				res["lines"].append(str(s.get("text_combat", "")))
			_log("contrabbando", "Carico confiscato: -$%d" % cost, 0)
	if delivered:
		var m = cargo.get("margin", [1.3, 1.7])
		var margin := rng.randf_range(float(m[0]), float(m[1])) * _market(str(cargo.get("good", "")))
		if ReputationSystem.value("gang") >= float(s.get("friend_rep", 20)):
			margin *= 1.0 + float(s.get("friend_bonus", 0.15))
		var gross := int(round(float(cost) * margin))
		var net := gross - cost
		PlayerState.add_money(gross)
		vars["gross"] = gross
		vars["net"] = net
		res["ok"] = true
		res["loot"] = net
		res["lines"].append(CrimeDB.fmt(CrimeDB.pick(s.get("text_ok", []), rng, "Ricavi ${gross}."), vars))
		add_heat(float(s.get("heat_ok", 4)), ctx)
		_apply_rep(s.get("rep_ok", {}), {"witnesses": 1})
		_log("contrabbando", "%s: netto $%d" % [str(cargo.get("label", "Carico")), net], net)
	_skip_hours(int(s.get("hours", 3)))
	return res


# ---------------------------------------------------------------- utilità condivise

static func has_firearm() -> bool:
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
