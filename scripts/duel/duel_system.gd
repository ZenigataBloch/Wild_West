class_name DuelSystem
extends RefCounted
## Logica pura del duello western (nessuna UI).
## Flusso: setup() -> (il pannello attende il segnale) -> resolve(reazione_ms, scorretto)
## -> events (da mostrare in sequenza) + result -> apply_results().

var opponent: Dictionary = {}   # npc_id, name, job, fame, agilita, mira, resistenza
var stake: int = 0
var audience: int = 0
var sheriff_present: bool = false
var rng: RandomNumberGenerator
var cue_delay: float = 2.0
var foul: bool = false
var player_first: bool = false
var player_ms: float = 0.0
var opp_ms: float = 0.0
var events: Array = []          # {text, who: "player"|"opp"|"narr", kind: "hit"|"miss"|"info"|"down", php, ohp}
var result: Dictionary = {}
var player_max: int = 1
var opp_max: int = 1

var _wound_hits: Array = []
var _applied: bool = false


# ---------------------------------------------------------------- avversari

static func from_npc(npc: Dictionary) -> Dictionary:
	var job := str(npc.get("job", "")).to_lower()
	var jobs: Dictionary = DuelDB.section("jobs")
	var jd: Dictionary = jobs.get(job, jobs.get("default", {}))
	if not bool(jd.get("can_duel", true)):
		return {}
	var st = npc.get("stats", npc.get("statistiche", {}))
	if not (st is Dictionary):
		st = {}
	return {
		"npc_id": str(npc.get("id", "")),
		"name": str(npc.get("name", "Sconosciuto")),
		"job": job,
		"fame": int(jd.get("fame", 2)),
		"agilita": int(st.get("agilita", 5)),
		"mira": int(st.get("mira", 5)),
		"resistenza": int(st.get("resistenza", 5)),
	}


static func make_stranger(r: RandomNumberGenerator) -> Dictionary:
	var cfg: Dictionary = DuelDB.section("strangers")
	var names: Array = cfg.get("names", ["Jack"])
	var surnames: Array = cfg.get("surnames", ["Dunn"])
	var nicks: Array = cfg.get("nicknames", ["Mano Rapida"])
	var fame := r.randi_range(int(cfg.get("fame_min", 4)), int(cfg.get("fame_max", 9)))
	var base := int(cfg.get("stat_base", 4))
	var full := "%s '%s' %s" % [
		names[r.randi_range(0, names.size() - 1)],
		nicks[r.randi_range(0, nicks.size() - 1)],
		surnames[r.randi_range(0, surnames.size() - 1)],
	]
	return {
		"npc_id": "",
		"name": full,
		"job": "pistolero",
		"fame": fame,
		"agilita": clampi(base + r.randi_range(0, 3) + fame / 3, 1, 10),
		"mira": clampi(base + r.randi_range(0, 3) + fame / 3, 1, 10),
		"resistenza": clampi(base + r.randi_range(0, 3), 1, 10),
	}


## Posta consigliata in base alla fama e ai soldi del giocatore (0 = nessuna posta).
static func suggest_stake(fame: int, money: int) -> int:
	var c: Dictionary = DuelDB.section("stakes")
	if money < int(c.get("min_money_to_bet", 20)):
		return 0
	var s := int(c.get("min", 10)) + fame * int(c.get("per_fame", 4))
	s = mini(s, int(c.get("max", 60)))
	s = mini(s, int(float(money) * float(c.get("money_cap_ratio", 0.5))))
	return maxi(s, 0)


# ------------------------------------------------------------ giocatore/arma

func _pstat(stat_name: String) -> int:
	if PlayerState.has_method("get_stat"):
		return int(PlayerState.get_stat(stat_name))
	return 5


func weapon_id() -> String:
	var w = PlayerState.get_weapon()
	if w is String:
		return w
	if w is Dictionary:
		return str(w.get("id", ""))
	return ""


func weapon_data() -> Dictionary:
	var id := weapon_id()
	if id == "":
		return {}
	var d = WeaponDB.weapon(id)
	return d if d is Dictionary else {}


## True se in mano c'è un'arma da fuoco (le armi bianche non servono in un duello).
func has_ranged_weapon() -> bool:
	var d := weapon_data()
	if d.is_empty():
		return false
	var melee: Array = DuelDB.value("melee_types", [])
	return not (str(d.get("type", "")) in melee)


func weapon_name() -> String:
	var d := weapon_data()
	return str(d.get("name", "la tua arma"))


func _weapon_accuracy() -> float:
	var a := float(weapon_data().get("accuracy", 0.0))
	return a / 100.0 if absf(a) > 1.0 else a


func _weapon_damage() -> int:
	var dm = weapon_data().get("damage", null)
	var fb: Array = DuelDB.section("damage").get("fallback", [6, 12])
	var lo := int(fb[0])
	var hi := int(fb[1])
	if dm is Array and dm.size() >= 2:
		lo = int(dm[0])
		hi = int(dm[1])
	elif dm is float or dm is int:
		lo = int(dm)
		hi = int(dm)
	return rng.randi_range(lo, maxi(lo, hi))


# -------------------------------------------------------------------- setup

func setup(opp: Dictionary, stake_amount: int, spectators: int, sheriff: bool, r: RandomNumberGenerator) -> void:
	opponent = opp
	stake = stake_amount
	audience = spectators
	sheriff_present = sheriff
	rng = r
	var t: Dictionary = DuelDB.section("timing")
	cue_delay = rng.randf_range(float(t.get("cue_min", 1.6)), float(t.get("cue_max", 4.4)))
	var p: Dictionary = DuelDB.section("pools")
	opp_max = maxi(1, int(p.get("opponent_base", 14)) + int(opp.get("resistenza", 5)) * int(p.get("opponent_per_resistenza", 2)))
	var cap := int(p.get("player_base", 22)) + _pstat("resistenza") * int(p.get("player_per_resistenza", 2))
	var room := int(PlayerState.health) - int(p.get("player_health_floor", 5))
	player_max = maxi(1, mini(cap, room))


func opponent_name() -> String:
	return str(opponent.get("name", "lo sfidante"))


# ------------------------------------------------------------------ risoluzione

func _opp_draw_ms() -> float:
	var c: Dictionary = DuelDB.section("opponent_draw")
	var ms := float(c.get("base_ms", 380))
	ms += float(opponent.get("agilita", 5)) * float(c.get("agility_ms", -14))
	ms += float(opponent.get("mira", 5)) * float(c.get("aim_ms", -6))
	ms += float(opponent.get("fame", 2)) * float(c.get("fame_ms", -8))
	var n := float(c.get("noise_ms", 70))
	ms += rng.randf_range(-n, n)
	return maxf(ms, float(c.get("min_ms", 170)))


func _vars() -> Dictionary:
	return {"opp": opponent_name(), "weapon": weapon_name(), "street": DuelDB.value("street", "strada")}


func _push(text: String, who: String, kind: String, php: int, ohp: int) -> void:
	events.append({"text": text, "who": who, "kind": kind, "php": php, "ohp": ohp})


func resolve(reaction_ms: float, was_foul: bool) -> void:
	foul = was_foul
	events.clear()
	_wound_hits.clear()
	var tc: Dictionary = DuelDB.section("timing")
	var hc: Dictionary = DuelDB.section("hit")
	var ag := _pstat("agilita")
	var aim := _pstat("mira")

	player_ms = reaction_ms - float(ag) * float(tc.get("agility_ms_bonus", 10)) - float(aim) * float(tc.get("aim_ms_bonus", 4))
	if foul:
		player_ms = 0.0
	opp_ms = _opp_draw_ms()
	player_first = foul or player_ms <= opp_ms

	var php := player_max
	var ohp := opp_max
	var vars := _vars()

	# Introduzione: chi estrae per primo.
	if foul:
		_push(DuelDB.text("foul", vars), "narr", "info", php, ohp)
	elif reaction_ms >= float(tc.get("react_window_ms", 1400)):
		_push(DuelDB.text("slow", vars), "narr", "info", php, ohp)
	_push(DuelDB.text("reaction", {"p": int(maxf(player_ms, 0.0)), "o": int(opp_ms), "opp": opponent_name()}), "narr", "info", php, ohp)
	if foul:
		_push(DuelDB.text("foul_first", vars), "narr", "info", php, ohp)
	elif player_first:
		_push(DuelDB.text("player_first", vars), "narr", "info", php, ohp)
	else:
		_push(DuelDB.text("opp_first", vars), "narr", "info", php, ohp)

	var order: Array = ["p", "o"] if player_first else ["o", "p"]
	var shots := int(DuelDB.value("shots_each", 4))
	var first_shot := true
	var winner := ""
	var dmg_cfg: Dictionary = DuelDB.section("damage")
	var opp_dmg: Array = dmg_cfg.get("opponent", [6, 11])

	for round_i in shots:
		for who in order:
			if winner != "":
				break
			if who == "p":
				var chance := float(hc.get("base", 0.32)) + float(aim) * float(hc.get("per_aim", 0.05)) \
					+ _weapon_accuracy() - float(opponent.get("agilita", 5)) * float(hc.get("per_opp_agility", 0.02))
				if first_shot and not foul:
					chance += float(hc.get("first_shot_bonus", 0.15))
				if foul and round_i == 0:
					chance -= float(hc.get("foul_penalty", 0.2))
				chance = clampf(chance, float(hc.get("min", 0.1)), float(hc.get("max", 0.92)))
				if rng.randf() < chance:
					ohp = maxi(0, ohp - _weapon_damage())
					_push(DuelDB.text("player_hit", vars, rng), "player", "hit", php, ohp)
					if ohp <= 0:
						winner = "p"
				else:
					_push(DuelDB.text("player_miss", vars, rng), "player", "miss", php, ohp)
			else:
				var chance_o := float(hc.get("base", 0.32)) + float(opponent.get("mira", 5)) * float(hc.get("per_aim", 0.05)) \
					- float(ag) * float(hc.get("per_opp_agility", 0.02))
				if first_shot:
					chance_o += float(hc.get("first_shot_bonus", 0.15))
				chance_o = clampf(chance_o, float(hc.get("min", 0.1)), float(hc.get("max", 0.92)))
				if rng.randf() < chance_o:
					var d := rng.randi_range(int(opp_dmg[0]), int(opp_dmg[1])) \
						+ int(float(opponent.get("fame", 2)) * float(dmg_cfg.get("opponent_per_fame", 0.5)))
					php = maxi(0, php - d)
					_wound_hits.append(d)
					_push(DuelDB.text("opp_hit", vars, rng), "opp", "hit", php, ohp)
					if php <= 0:
						winner = "o"
				else:
					_push(DuelDB.text("opp_miss", vars, rng), "opp", "miss", php, ohp)
			first_shot = false
		if winner != "":
			break

	var outcome := "draw"
	if winner == "p":
		outcome = "win"
		_push(DuelDB.text("opp_down", vars), "opp", "down", php, ohp)
	elif winner == "o":
		outcome = "lose"
		_push(DuelDB.text("player_down", vars), "player", "down", php, ohp)
	else:
		_push(DuelDB.text("draw_end", vars), "narr", "info", php, ohp)

	_build_result(outcome, player_max - php)


func _scale_rep(table: Dictionary, with_fame: bool) -> Dictionary:
	var ac: Dictionary = DuelDB.section("audience")
	var mult := 1.0 + float(audience) * float(ac.get("rep_per_spectator", 0.08))
	if with_fame:
		mult *= 1.0 + float(opponent.get("fame", 2)) * float(ac.get("fame_rep_per_point", 0.07))
	var out := {}
	for g in table:
		var v := float(table[g]) * mult
		var iv := int(roundf(v))
		if iv == 0 and v != 0.0:
			iv = 1 if v > 0.0 else -1
		out[g] = iv
	return out


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var out := a.duplicate()
	for g in b:
		out[g] = int(out.get(g, 0)) + int(b[g])
	return out


func _build_result(outcome: String, damage: int) -> void:
	var rep_cfg: Dictionary = DuelDB.section("reputation")
	var rel_cfg: Dictionary = DuelDB.section("relationship")
	var key := outcome
	if foul and (outcome == "win" or outcome == "lose"):
		key = outcome + "_foul"
	var rep := _scale_rep(rep_cfg.get(key, {}), outcome == "win")
	var lines: Array = [DuelDB.text("result_" + key, _vars())]
	if sheriff_present:
		if foul:
			rep = _merge(rep, rep_cfg.get("sheriff_foul_extra", {}))
			lines.append(DuelDB.text("sheriff_foul"))
		elif outcome == "win":
			rep = _merge(rep, rep_cfg.get("sheriff_fair_win_extra", {}))
			lines.append(DuelDB.text("sheriff_fair"))
	var money := 0
	if outcome == "win":
		money = stake
	elif outcome == "lose":
		money = -mini(stake, int(PlayerState.money))
	result = {
		"outcome": outcome,
		"foul": foul,
		"money": money,
		"rep": rep,
		"damage": maxi(damage, 0),
		"relationship": int(rel_cfg.get(outcome, 0)),
		"lines": lines,
	}


## Rifiuto della sfida: nessun duello, solo conseguenze sociali. Va seguito da apply_results().
func refuse() -> void:
	events.clear()
	var rep := _scale_rep(DuelDB.section("reputation").get("refuse", {}), false)
	result = {
		"outcome": "refuse",
		"foul": false,
		"money": 0,
		"rep": rep,
		"damage": 0,
		"relationship": int(DuelDB.section("relationship").get("refuse", 0)),
		"lines": [DuelDB.text("result_refuse", _vars())],
	}


# -------------------------------------------------------------- applicazione

func _try_wounds() -> void:
	# Ogni colpo subito può lasciare una ferita (WoundSystem, Feature 13).
	for d in _wound_hits:
		WoundSystem.try_wound(int(d), rng)


## Applica gli effetti sul mondo (una sola volta): salute, ferite, soldi, reputazione, relazione.
func apply_results() -> void:
	if _applied or result.is_empty():
		return
	_applied = true
	var dmg := int(result.get("damage", 0))
	if dmg > 0:
		PlayerState.damage(dmg)
		_try_wounds()
	var money := int(result.get("money", 0))
	if money > 0:
		PlayerState.add_money(money)
	elif money < 0:
		PlayerState.spend_money(-money)
	var rep: Dictionary = result.get("rep", {})
	for g in rep:
		ReputationSystem.add(str(g), int(rep[g]))
	var npc_id := str(opponent.get("npc_id", ""))
	var rel := int(result.get("relationship", 0))
	if npc_id != "" and rel != 0:
		NPCRegistry.change_relationship(npc_id, rel)
