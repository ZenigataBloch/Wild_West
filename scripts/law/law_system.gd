class_name LawSystem
extends RefCounted
## Sistema legge (Feature 21): logica senza UI. Legge la notorietà di CrimeSystem
## (heat, wanted_level, bounty) e gestisce taglia, arresto, corruzione, fuga e resistenza.

static var arrests: int = 0
static var bounties_paid: int = 0


static func reset() -> void:
	arrests = 0
	bounties_paid = 0


static func cfg() -> Dictionary:
	return CrimeDB.section("law")


static func _text(key: String, vars: Dictionary = {}) -> String:
	return CrimeDB.fmt(str(cfg().get("texts", {}).get(key, "")), vars)


static func _blank() -> Dictionary:
	return {"kind": "law", "ok": false, "lines": [], "loot": 0, "combat": [], "combat_title": "", "teleport": false}


static func _rng() -> RandomNumberGenerator:
	CrimeSystem._attempts += 1
	return CrimeSystem._rng("law_%d_%d" % [CrimeSystem.current_day(), CrimeSystem._attempts])


static func jail_days() -> int:
	return clampi(CrimeSystem.wanted_level(), 1, 3)


## Soldi richiesti per pagare la taglia (0 se non c'è).
static func pay_cost() -> int:
	return CrimeSystem.bounty()


static func bribe_cost() -> int:
	var b: Dictionary = cfg().get("bribe", {})
	return maxi(int(round(float(CrimeSystem.bounty()) * float(b.get("cost_mult", 0.6)))), int(b.get("cost_min", 20)))


static func chance_bribe() -> float:
	var b: Dictionary = cfg().get("bribe", {})
	return CrimeSystem._clamp_chance(float(b.get("base", 0.35)) + CrimeSystem._stat("carisma") * float(b.get("carisma", 0.05)))


static func chance_flee() -> float:
	var f: Dictionary = cfg().get("flee", {})
	var p := float(f.get("base", 0.35)) + CrimeSystem._stat("agilita") * float(f.get("agilita", 0.05))
	p -= float(CrimeSystem.wanted_level()) * float(f.get("level_pen", 0.05))
	return CrimeSystem._clamp_chance(p)


static func _rep(rep) -> void:
	if rep is Dictionary:
		for g in rep:
			ReputationSystem.add(str(g), float(rep[g]))


static func pay_bounty() -> Dictionary:
	var res := _blank()
	var cost := pay_cost()
	if cost <= 0:
		res["lines"].append(_text("pay_none"))
		return res
	if CrimeSystem.money() < cost:
		res["lines"].append(_text("pay_no"))
		return res
	PlayerState.spend_money(cost)
	CrimeSystem.heat = 0.0
	bounties_paid += 1
	_rep(cfg().get("pay", {}).get("rep", {}))
	res["ok"] = true
	res["lines"].append(_text("pay_ok", {"cost": cost}))
	CrimeSystem._log("legge", "Taglia pagata: $%d" % cost, 0)
	return res


## Arresto: multa, giorni di cella (il tempo passa), notorietà ridotta, risveglio in città.
static func arrest(res: Dictionary, extra_days: int = 0) -> Dictionary:
	var c := cfg()
	var days := jail_days() + extra_days
	var fine := mini(CrimeSystem.money(), int(round(float(CrimeSystem.bounty()) * float(c.get("fine_mult", 0.5)))) + int(c.get("fine_base", 10)))
	if fine > 0:
		PlayerState.spend_money(fine)
	_serve(days)
	CrimeSystem.heat *= float(c.get("arrest_heat_mult", 0.25))
	_rep(c.get("arrest_rep", {}))
	arrests += 1
	res["teleport"] = true
	res["lines"].append(_text("arrest", {"days": days, "fine": fine}))
	CrimeSystem._log("legge", "Arrestato: %d giorni, multa $%d" % [days, fine], 0)
	return res


static func _serve(days: int) -> void:
	if not GameTime.has_method("skip_to_hour"):
		return
	var wake := int(cfg().get("jail_wake_hour", 8))
	GameTime.call("skip_to_hour", wake)
	for i in maxi(days - 1, 0):
		GameTime.call("skip_to_hour", wake - 1)
		GameTime.call("skip_to_hour", wake)


static func do_arrest() -> Dictionary:
	return arrest(_blank())


static func do_bribe() -> Dictionary:
	var res := _blank()
	var b: Dictionary = cfg().get("bribe", {})
	var cost := bribe_cost()
	if CrimeSystem.money() < cost:
		res["lines"].append(_text("pay_no"))
		return res
	PlayerState.spend_money(cost)
	if _rng().randf() < chance_bribe():
		CrimeSystem.heat *= float(b.get("heat_mult", 0.4))
		_rep(b.get("rep_ok", {}))
		res["ok"] = true
		res["lines"].append(_text("bribe_ok"))
		CrimeSystem._log("legge", "Corrotto un vice: $%d" % cost, 0)
	else:
		res["lines"].append(_text("bribe_fail", {"cost": cost}))
		arrest(res, int(b.get("fail_extra_days", 1)))
	return res


static func do_flee() -> Dictionary:
	var res := _blank()
	var f: Dictionary = cfg().get("flee", {})
	if _rng().randf() < chance_flee():
		CrimeSystem.add_heat(float(f.get("heat_ok", 3)), {})
		res["ok"] = true
		res["lines"].append(_text("flee_ok"))
	else:
		res["lines"].append(_text("flee_fail"))
		arrest(res, int(f.get("fail_extra_days", 1)))
	return res


static func do_resist(deputies: int) -> Dictionary:
	var res := _blank()
	var r: Dictionary = cfg().get("resist", {})
	CrimeSystem.add_heat(float(r.get("heat", 15)), {})
	_rep(r.get("rep", {}))
	var ids: Array = []
	for i in maxi(deputies, 2):
		ids.append(str(r.get("enemy", "bandito")))
	res["combat"] = ids
	res["combat_title"] = str(r.get("title", "Resistenza all'arresto"))
	res["lines"].append(_text("resist"))
	CrimeSystem._log("legge", "Resistenza all'arresto", 0)
	return res
