class_name SaveSystem
extends RefCounted
## Salvataggio e caricamento (Feature 23). Logica senza UI.
## Il mondo (città, NPC, bande, lotti) si rigenera dal seed; qui si salva solo lo stato che cambia
## giocando. Formato: var_to_str (testo leggibile che conserva int/float, Vector2 e chiavi intere).
## Due file in user://: salvataggio manuale (F5) e autosalvataggio a ogni nuovo giorno.

const FORMAT := 1
const MANUAL_PATH := "user://savegame.sav"
const AUTO_PATH := "user://autosave.sav"
const NPC_KEYS := ["relationship", "met", "dialog_flags"]


# ------------------------------------------------------------------ raccolta dello stato

static func capture(avatar: Node2D, game_version: String = "") -> Dictionary:
	var npcs: Dictionary = {}
	for n in NPCRegistry.npcs:
		var entry: Dictionary = {}
		for k in NPC_KEYS:
			if n.has(k):
				entry[k] = n[k]
		npcs[String(n["id"])] = entry
	return {
		"format": FORMAT,
		"game_version": game_version,
		"saved_unix": Time.get_unix_time_from_system(),
		"seed": int(WorldSeed.world_seed),
		"time": {"day": int(GameTime.day), "hour_float": float(GameTime.hour_float), "time_scale": float(GameTime.time_scale)},
		"player": {
			"name": PlayerState.player_name, "health": PlayerState.health, "max_health": PlayerState.max_health,
			"money": PlayerState.money, "stat_max": PlayerState.stat_max, "stats": PlayerState.stats.duplicate(true),
			"inventory": PlayerState.inventory.duplicate(true), "weapon": PlayerState.equipped_weapon,
			"pos": avatar.global_position if avatar != null else Vector2.ZERO,
		},
		"wounds": {"list": WoundSystem.wounds.duplicate(true), "next_id": WoundSystem._next_id},
		"dialogue": {"known_info": DialogueState.known_info.duplicate(), "reputation": DialogueState.reputation.duplicate(true)},
		"npcs": npcs,
		"quests": {
			"active": QuestState.active.duplicate(true), "offers": QuestState.offers.duplicate(true),
			"completed": QuestState.completed.duplicate(), "last_done": QuestState.last_done.duplicate(true),
			"counter": QuestState.counter,
		},
		"jobs": {
			"current": JobState.current, "shifts": JobState.shifts.duplicate(true),
			"earned_total": JobState.earned_total, "earned_today": JobState.earned_today, "today": JobState._today,
		},
		"economy": {
			"goods": EconomySystem.goods.duplicate(true), "active_event": EconomySystem.active_event.duplicate(true),
			"last_day": EconomySystem.last_day,
		},
		"bank": {
			"balance": BankSystem.balance, "interest_frac": BankSystem.interest_frac,
			"interest_earned": BankSystem.interest_earned, "loans": BankSystem.loans.duplicate(true),
			"next_id": BankSystem.next_id, "blacklist_until": BankSystem.blacklist_until, "last_day": BankSystem.last_day,
		},
		"property": {"owned": PropertySystem.owned.duplicate(true), "last_day": PropertySystem.last_day},
		"gangs": {
			"gangs": GangSystem.gangs.duplicate(true), "news": GangSystem.news.duplicate(true),
			"last_day": GangSystem.last_day, "respawns": GangSystem._respawns.duplicate(true),
			"next_id": GangSystem._next_id,
		},
		"crime": {
			"heat": CrimeSystem.heat, "history": CrimeSystem.history.duplicate(true),
			"cooldowns": CrimeSystem.cooldowns.duplicate(true), "counts": CrimeSystem.counts.duplicate(true),
			"total_loot": CrimeSystem.total_loot, "last_day": CrimeSystem.last_day,
			"last_smuggle_day": CrimeSystem.last_smuggle_day, "attempts": CrimeSystem._attempts, "salt": CrimeSystem._salt,
		},
		"law": {"arrests": LawSystem.arrests, "bounties_paid": LawSystem.bounties_paid},
	}


# ------------------------------------------------------------------ ripristino dello stato

## Da chiamare dopo che il mondo è stato rigenerato con lo stesso seed (World.load_game).
static func apply(data: Dictionary, avatar: Node2D) -> void:
	var t: Dictionary = data.get("time", {})
	GameTime.day = int(t.get("day", 1))
	GameTime.hour_float = float(t.get("hour_float", 7.0))
	GameTime.time_scale = float(t.get("time_scale", 1.0))
	GameTime._last_minute = -1
	GameTime._last_hour = -1
	GameTime.phase = GameTime._compute_phase()

	var p: Dictionary = data.get("player", {})
	PlayerState.player_name = str(p.get("name", PlayerState.player_name))
	PlayerState.max_health = int(p.get("max_health", PlayerState.max_health))
	PlayerState.health = int(p.get("health", PlayerState.max_health))
	PlayerState.money = int(p.get("money", 0))
	PlayerState.stat_max = int(p.get("stat_max", PlayerState.stat_max))
	PlayerState.stats = (p.get("stats", PlayerState.stats) as Dictionary).duplicate(true)
	PlayerState.inventory = (p.get("inventory", []) as Array).duplicate(true)
	PlayerState.equipped_weapon = str(p.get("weapon", ""))
	if avatar != null and p.has("pos"):
		avatar.global_position = p["pos"]

	var w: Dictionary = data.get("wounds", {})
	WoundSystem.wounds.assign((w.get("list", []) as Array).duplicate(true))
	WoundSystem._next_id = int(w.get("next_id", 1))

	var d: Dictionary = data.get("dialogue", {})
	DialogueState.known_info.assign(d.get("known_info", []))
	DialogueState.reputation = (d.get("reputation", {}) as Dictionary).duplicate(true)

	var saved_npcs: Dictionary = data.get("npcs", {})
	for n in NPCRegistry.npcs:
		var entry: Dictionary = saved_npcs.get(String(n["id"]), {})
		for k in entry:
			n[k] = entry[k]

	var q: Dictionary = data.get("quests", {})
	QuestState.active.assign((q.get("active", []) as Array).duplicate(true))
	QuestState.offers = (q.get("offers", {}) as Dictionary).duplicate(true)
	QuestState.completed.assign(q.get("completed", []))
	QuestState.last_done = (q.get("last_done", {}) as Dictionary).duplicate(true)
	QuestState.counter = int(q.get("counter", 0))
	QuestState.version += 1

	var j: Dictionary = data.get("jobs", {})
	JobState.current = str(j.get("current", ""))
	JobState.shifts = (j.get("shifts", {}) as Dictionary).duplicate(true)
	JobState.earned_total = int(j.get("earned_total", 0))
	JobState.earned_today = int(j.get("earned_today", 0))
	JobState._today = int(j.get("today", -1))

	var e: Dictionary = data.get("economy", {})
	if e.has("goods"):
		EconomySystem.goods = (e["goods"] as Dictionary).duplicate(true)
		EconomySystem.active_event = (e.get("active_event", {}) as Dictionary).duplicate(true)
		EconomySystem.last_day = int(e.get("last_day", GameTime.day))

	var b: Dictionary = data.get("bank", {})
	BankSystem.balance = int(b.get("balance", 0))
	BankSystem.interest_frac = float(b.get("interest_frac", 0.0))
	BankSystem.interest_earned = int(b.get("interest_earned", 0))
	BankSystem.loans.assign((b.get("loans", []) as Array).duplicate(true))
	BankSystem.next_id = int(b.get("next_id", 1))
	BankSystem.blacklist_until = int(b.get("blacklist_until", 0))
	BankSystem.last_day = int(b.get("last_day", GameTime.day))

	var pr: Dictionary = data.get("property", {})
	PropertySystem.owned = (pr.get("owned", {}) as Dictionary).duplicate(true)
	PropertySystem.last_day = int(pr.get("last_day", GameTime.day))
	PropertySystem.version += 1

	var g: Dictionary = data.get("gangs", {})
	if g.has("gangs"):
		GangSystem.gangs = (g["gangs"] as Array).duplicate(true)
		GangSystem.news = (g.get("news", []) as Array).duplicate(true)
		GangSystem.last_day = int(g.get("last_day", GameTime.day))
		GangSystem._respawns = (g.get("respawns", []) as Array).duplicate(true)
		GangSystem._next_id = int(g.get("next_id", 1))
		GangSystem._rng = WorldSeed.rng_for("gangs_resume_%d" % int(GameTime.day))
		GangSystem.version += 1

	var c: Dictionary = data.get("crime", {})
	CrimeSystem.heat = float(c.get("heat", 0.0))
	CrimeSystem.history = (c.get("history", []) as Array).duplicate(true)
	CrimeSystem.cooldowns = (c.get("cooldowns", {}) as Dictionary).duplicate(true)
	CrimeSystem.counts = (c.get("counts", {}) as Dictionary).duplicate(true)
	CrimeSystem.total_loot = int(c.get("total_loot", 0))
	CrimeSystem.last_day = int(c.get("last_day", GameTime.day))
	CrimeSystem.last_smuggle_day = int(c.get("last_smuggle_day", -1))
	CrimeSystem._attempts = int(c.get("attempts", 0))
	CrimeSystem._salt = int(c.get("salt", CrimeSystem._salt))

	var l: Dictionary = data.get("law", {})
	LawSystem.arrests = int(l.get("arrests", 0))
	LawSystem.bounties_paid = int(l.get("bounties_paid", 0))

	PlayerState.name_changed.emit(PlayerState.player_name)
	PlayerState.health_changed.emit(PlayerState.health, PlayerState.max_health)
	PlayerState.money_changed.emit(PlayerState.money)
	PlayerState.stats_changed.emit()
	PlayerState.inventory_changed.emit()
	PlayerState.equipment_changed.emit()
	PlayerState.wounds_changed.emit()


# ------------------------------------------------------------------ file

static func write(path: String, data: Dictionary) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(var_to_str(data))
	f.close()
	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists(path.get_file()):
		dir.remove(path.get_file())
	return dir.rename(tmp.get_file(), path.get_file()) == OK


## Dizionario vuoto se il file manca, è rovinato o di un altro formato.
static func read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var v = str_to_var(FileAccess.get_file_as_string(path))
	if v is Dictionary and int(v.get("format", 0)) == FORMAT and v.has("seed") and v.has("player"):
		return v
	return {}


## Il salvataggio più recente tra manuale e automatico (vuoto se non ce ne sono).
static func newest() -> Dictionary:
	var a := read(MANUAL_PATH)
	var b := read(AUTO_PATH)
	if a.is_empty():
		return b
	if b.is_empty():
		return a
	return a if float(a.get("saved_unix", 0.0)) >= float(b.get("saved_unix", 0.0)) else b


static func describe(data: Dictionary) -> String:
	var t: Dictionary = data.get("time", {})
	var p: Dictionary = data.get("player", {})
	var h := float(t.get("hour_float", 0.0))
	return "%s, giorno %d %02d:%02d, $%d" % [str(p.get("name", "?")), int(t.get("day", 1)), int(h), int((h - int(h)) * 60.0), int(p.get("money", 0))]
