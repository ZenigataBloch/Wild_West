class_name JobSystem
extends RefCounted
## Logica pura dei lavori: requisiti, ranghi, turno con eventi, paga ed effetti.
## Flusso: can_work() -> run_shift() (risultato, nessun effetto) -> apply_result().


# ------------------------------------------------------------------ ranghi

static func rank_index(job_id: String) -> int:
	var n := JobState.shifts_of(job_id)
	var idx := 0
	var ranks: Array = JobDB.ranks()
	for i in ranks.size():
		if n >= int(ranks[i].get("shifts", 0)):
			idx = i
	return idx


static func rank_name(job_id: String) -> String:
	var ranks: Array = JobDB.ranks()
	if ranks.is_empty():
		return ""
	return str(ranks[rank_index(job_id)].get("name", ""))


static func rank_mult(job_id: String) -> float:
	var ranks: Array = JobDB.ranks()
	if ranks.is_empty():
		return 1.0
	return float(ranks[rank_index(job_id)].get("pay_mult", 1.0))


## Testo sul prossimo rango ("Esperto tra 3 turni") o vuoto se già al massimo.
static func next_rank_text(job_id: String) -> String:
	var ranks: Array = JobDB.ranks()
	var i := rank_index(job_id) + 1
	if i >= ranks.size():
		return "Rango massimo"
	var left := int(ranks[i].get("shifts", 0)) - JobState.shifts_of(job_id)
	return "%s tra %d turni" % [str(ranks[i].get("name", "")), maxi(left, 0)]


# ------------------------------------------------------------- statistiche

static func stat_value(stat_name: String) -> int:
	if PlayerState.has_method("get_stat"):
		return int(PlayerState.get_stat(stat_name))
	return 5


static func pay_per_shift(job_id: String) -> int:
	var j := JobDB.job(job_id)
	var base := float(j.get("base_pay", 0))
	var st := stat_value(str(j.get("stat", "forza")))
	var factor := 1.0 + float(st - 5) * float(JobDB.value("stat_pay_per_point", 0.05))
	return int(roundf(base * rank_mult(job_id) * maxf(factor, 0.5)))


static func has_ranged_weapon() -> bool:
	var w = PlayerState.get_weapon()
	var id := ""
	if w is String:
		id = w
	elif w is Dictionary:
		id = str(w.get("id", ""))
	if id == "":
		return false
	var d = WeaponDB.weapon(id)
	if not (d is Dictionary) or d.is_empty():
		return false
	return not (str(d.get("type", "")) in JobDB.value("melee_types", []))


# -------------------------------------------------------------- requisiti

## {"ok": bool, "reason": String}
static func can_work(job_id: String, pos: Vector2, origin: Vector2) -> Dictionary:
	var j := JobDB.job(job_id)
	if j.is_empty():
		return {"ok": false, "reason": ""}
	if JobState.current != job_id:
		return {"ok": false, "reason": JobDB.text("no_job")}
	if float(PlayerState.health) < float(JobDB.value("min_health_to_work", 15)):
		return {"ok": false, "reason": JobDB.text("low_health")}
	var w: Array = j.get("window", [0, 24])
	if "hour" in GameTime:
		var h := float(GameTime.hour)
		if h < float(w[0]) or h >= float(w[1]):
			return {"ok": false, "reason": JobDB.text("wrong_hour", {"a": int(w[0]), "b": int(w[1])})}
	var inside := pos.distance_to(origin) <= float(JobDB.value("town_radius", 600))
	var area := str(j.get("area", "any"))
	if area == "town" and not inside:
		return {"ok": false, "reason": JobDB.text("need_town")}
	if area == "wilds" and inside:
		return {"ok": false, "reason": JobDB.text("need_wilds")}
	var place: Dictionary = j.get("place", {})
	if not place.is_empty() and not JobSites.is_near(place, pos):
		return {"ok": false, "reason": JobDB.text("need_place", {"place": str(place.get("label", "il luogo di lavoro"))})}
	if bool(j.get("needs_weapon", false)) and not has_ranged_weapon():
		return {"ok": false, "reason": JobDB.text("need_weapon")}
	var need := int(j.get("min_money", 0))
	if need > 0 and int(PlayerState.money) < need:
		return {"ok": false, "reason": JobDB.text("need_money", {"n": need})}
	return {"ok": true, "reason": ""}


# ------------------------------------------------------------------- turno

static func _check(stat_name: String, diff: int, rng: RandomNumberGenerator) -> bool:
	var p := clampf(0.5 + 0.08 * float(stat_value(stat_name) - diff), 0.1, 0.95)
	return rng.randf() < p


static func _add_rep(dst: Dictionary, src: Dictionary) -> void:
	for g in src:
		dst[g] = int(dst.get(g, 0)) + int(src[g])


## Simula un turno e restituisce il risultato (senza applicare effetti).
static func run_shift(job_id: String, rng: RandomNumberGenerator) -> Dictionary:
	var j := JobDB.job(job_id)
	var lines: Array = []
	var rep := {}
	_add_rep(rep, j.get("rep", {}))
	var pay := pay_per_shift(job_id)
	var good := str(j.get("good", ""))
	if good != "":
		pay = roundi(float(pay) * EconomySystem.index(good))   # il mercato (Feature 16) sposta la paga
	var damage := 0
	var wound_hits: Array = []
	var combat := {}
	var stock_loss := 0.0
	var floor_hp := int(JobDB.value("health_floor", 5))
	var room := maxi(int(PlayerState.health) - floor_hp, 0)

	lines.append("Turno da %s: %d ore di lavoro." % [str(j.get("name", job_id)), int(j.get("hours", 6))])
	if good != "" and absf(EconomySystem.index(good) - 1.0) >= 0.08:
		lines.append(JobDB.text("market_note", {"good": EconomySystem.good_label(good).to_lower(), "pct": EconomySystem.pct_text(good)}))

	for ev in j.get("events", []):
		if rng.randf() >= float(ev.get("chance", 0.0)):
			continue
		lines.append(str(ev.get("text", "")))
		if ev.has("combat"):
			if combat.is_empty():
				combat = ev["combat"]
			pay += int(ev.get("pay", 0))
			continue
		var ok := true
		if ev.has("stat"):
			ok = _check(str(ev["stat"]), int(ev.get("diff", 5)), rng)
		var branch: Dictionary = ev.get("ok", {}) if ok else ev.get("fail", {})
		if branch.has("text"):
			lines.append("  " + str(branch["text"]))
		pay += int(branch.get("pay", 0))
		if branch.has("damage"):
			var dr: Array = branch["damage"]
			var d := rng.randi_range(int(dr[0]), int(dr[1]))
			d = mini(d, maxi(room - damage, 0))
			if d > 0:
				damage += d
				wound_hits.append(d)
		_add_rep(rep, branch.get("rep", {}))
		stock_loss += float(branch.get("stock_loss", 0.0))

	# Commercio: capitale investito e ricarico.
	var stock := 0
	var profit := 0
	if j.has("trade"):
		var t: Dictionary = j["trade"]
		stock = mini(int(float(PlayerState.money) * float(t.get("capital_ratio", 0.4))), int(t.get("capital_cap", 150)))
		var margin := float(t.get("margin_base", 0.1)) \
			+ float(stat_value(str(j.get("stat", "carisma"))) - 5) * float(t.get("margin_per_stat", 0.015)) \
			+ float(ReputationSystem.value("commercianti")) / 100.0 * float(t.get("margin_rep", 0.05)) \
			+ (EconomySystem.index("merci") - 1.0) * float(t.get("margin_market", 0.0)) \
			+ rng.randf_range(-float(t.get("margin_noise", 0.08)), float(t.get("margin_noise", 0.08)))
		profit = int(roundf(float(stock) * (1.0 - stock_loss) * (1.0 + margin))) - stock
		if profit >= 0:
			lines.append(JobDB.text("trade_profit", {"stock": stock, "profit": profit}))
		else:
			lines.append(JobDB.text("trade_loss", {"stock": stock, "loss": -profit}))
		pay += profit

	var pay_txt := "+$%d" % pay if pay >= 0 else "-$%d" % -pay
	lines.append(JobDB.text("shift_end", {"pay": pay_txt}))

	return {
		"job": job_id,
		"good": good,
		"pay": pay,
		"hours": int(j.get("hours", 6)),
		"damage": damage,
		"wound_hits": wound_hits,
		"rep": rep,
		"combat": combat,
		"lines": lines,
		"promoted": "",
	}


## Applica il risultato: soldi, salute, ferite, reputazione, rango e tempo che passa.
static func apply_result(res: Dictionary, rng: RandomNumberGenerator) -> void:
	var job_id := str(res.get("job", ""))
	var before := rank_index(job_id)
	var pay := int(res.get("pay", 0))
	if pay > 0:
		PlayerState.add_money(pay)
	elif pay < 0:
		PlayerState.spend_money(mini(-pay, int(PlayerState.money)))
	var dmg := int(res.get("damage", 0))
	if dmg > 0:
		PlayerState.damage(dmg)
		for d in res.get("wound_hits", []):
			WoundSystem.try_wound(int(d), rng)
	var rep: Dictionary = res.get("rep", {})
	for g in rep:
		ReputationSystem.add(str(g), int(rep[g]))
	EconomySystem.on_supply(str(res.get("good", "")), float(JobDB.job(job_id).get("supply", 0.0)))   # la merce prodotta fa scendere i prezzi
	JobState.record(job_id, pay)
	if rank_index(job_id) > before:
		var msg := JobDB.text("rank_up", {"rank": rank_name(job_id), "job": str(JobDB.job(job_id).get("name", job_id))})
		res["promoted"] = msg
		(res["lines"] as Array).append(msg)
	if "hour" in GameTime and GameTime.has_method("skip_to_hour"):
		var target := (int(GameTime.hour) + int(res.get("hours", 0))) % 24
		GameTime.skip_to_hour(target)
