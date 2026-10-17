class_name WoundSystem
extends RefCounted
## Ferite del giocatore (data/wounds.json): sanguinamento, penalità, recupero. Logica senza UI.
## Stato solo in memoria (come QuestState): `wounds` = [{id, severity, part, bleeding, bandaged, hours_left}].
## - Le penalità arrivano alle statistiche tramite PlayerState.get_stat() (quindi anche a combattimento,
##   movimento e caccia) con stat_penalty().
## - Il tempo scorre con WoundManager, che chiama tick_hour() a ogni ora di gioco.
## - Segnali: PlayerState.wounds_changed (stato cambiato), PlayerState.wound_message(text) (avvisi).

const PATH := "res://data/wounds.json"

static var _data: Dictionary = {}
static var wounds: Array[Dictionary] = []
static var _next_id := 1


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"severities": {}, "parts": {}}
	return _data


static func num(key: String, default: float) -> float:
	return float(data().get(key, default))


static func severity_def(id: String) -> Dictionary:
	return data().get("severities", {}).get(id, {})


static func part_def(id: String) -> Dictionary:
	return data().get("parts", {}).get(id, {})


static func reset() -> void:
	wounds.clear()
	_next_id = 1
	_notify()


static func _notify() -> void:
	PlayerState.wounds_changed.emit()


# --- descrizioni ---

## "Ferita grave alla gamba".
static func wound_name(w: Dictionary) -> String:
	var s := String(severity_def(String(w.get("severity", ""))).get("label", "Ferita"))
	var p := String(part_def(String(w.get("part", ""))).get("on", ""))
	return ("%s %s" % [s, p]).strip_edges()


static func penalty_of(w: Dictionary) -> int:
	return int(severity_def(String(w.get("severity", ""))).get("penalty", 0))


## "-1 Mira" (vuoto se la ferita non ha penalità).
static func penalty_text(w: Dictionary) -> String:
	var p := penalty_of(w)
	if p <= 0:
		return ""
	var stat := String(part_def(String(w.get("part", ""))).get("stat", ""))
	return "-%d %s" % [p, PlayerState.get_stat_label(stat)]


static func status_text(w: Dictionary) -> String:
	if bool(w.get("bleeding", false)):
		var b := int(severity_def(String(w["severity"])).get("bleed", 0))
		return "sanguina (-%d salute/ora)" % b
	var step := num("bandaged_heal_mult", 2.0) if bool(w.get("bandaged", false)) else 1.0
	var hrs := ceili(float(w.get("hours_left", 0.0)) / maxf(0.1, step))
	return ("fasciata, guarisce tra ~%d h" if bool(w.get("bandaged", false)) else "guarisce tra ~%d h") % hrs


# --- stato ---

## Punti tolti a una statistica dalle ferite attive (limitati da max_penalty).
static func stat_penalty(stat: String) -> int:
	var total := 0
	for w in wounds:
		if String(part_def(String(w["part"])).get("stat", "")) == stat:
			total += penalty_of(w)
	return mini(total, int(num("max_penalty", 4.0)))


static func is_bleeding() -> bool:
	for w in wounds:
		if bool(w["bleeding"]):
			return true
	return false


static func bleed_per_hour() -> int:
	var total := 0
	for w in wounds:
		if bool(w["bleeding"]):
			total += int(severity_def(String(w["severity"])).get("bleed", 0))
	return total


# --- creazione ---

static func add_wound(severity: String, part: String) -> Dictionary:
	var sd := severity_def(severity)
	if sd.is_empty() or part_def(part).is_empty():
		return {}
	if wounds.size() >= int(num("max_wounds", 6.0)):
		return {}
	var w := {
		"id": _next_id,
		"severity": severity,
		"part": part,
		"bleeding": int(sd.get("bleed", 0)) > 0,
		"bandaged": false,
		"hours_left": float(sd.get("heal_hours", 24)),
	}
	_next_id += 1
	wounds.append(w)
	_notify()
	return w


## Gravità in base al danno subito ("" = nessuna ferita possibile).
static func severity_for_damage(dmg: int) -> String:
	var best := ""
	var best_min := -1
	var sevs: Dictionary = data().get("severities", {})
	for id in sevs:
		var m := int(sevs[id].get("min_dmg", 1))
		if dmg >= m and m > best_min:
			best = String(id)
			best_min = m
	return best


static func pick_part(rng: RandomNumberGenerator) -> String:
	var parts: Dictionary = data().get("parts", {})
	if parts.is_empty():
		return ""
	var total := 0.0
	for id in parts:
		total += float(parts[id].get("weight", 1))
	var roll := rng.randf() * total
	for id in parts:
		roll -= float(parts[id].get("weight", 1))
		if roll <= 0.0:
			return String(id)
	return String(parts.keys()[0])


## Un colpo subito può causare una ferita. Ritorna la ferita aggiunta o {}.
static func try_wound(dmg: int, rng: RandomNumberGenerator) -> Dictionary:
	var sev := severity_for_damage(dmg)
	if sev == "":
		return {}
	if rng.randf() >= float(severity_def(sev).get("chance", 0.3)):
		return {}
	return add_wound(sev, pick_part(rng))


## Ferita casuale (debug).
static func random_wound(rng: RandomNumberGenerator) -> Dictionary:
	var sevs: Array = data().get("severities", {}).keys()
	if sevs.is_empty():
		return {}
	return add_wound(String(sevs[rng.randi() % sevs.size()]), pick_part(rng))


# --- cure ---

## Una benda ferma il sanguinamento della ferita che perde più sangue (poi guarisce più in fretta).
## Ritorna la ferita curata o {}.
static func bandage(silent: bool = false) -> Dictionary:
	var best: Dictionary = {}
	var best_bleed := -1
	for w in wounds:
		if bool(w["bleeding"]):
			var b := int(severity_def(String(w["severity"])).get("bleed", 0))
			if b > best_bleed:
				best = w
				best_bleed = b
	if best.is_empty():
		return {}
	best["bleeding"] = false
	best["bandaged"] = true
	_notify()
	if not silent:
		PlayerState.wound_message.emit("Fasci %s: il sanguinamento si ferma." % wound_name(best).to_lower())
	return best


## Ferma ogni sanguinamento (fasciatura di fortuna, qualcuno ti soccorre). Ritorna quante ferite.
static func bandage_all(silent: bool = true) -> int:
	var n := 0
	while not bandage(silent).is_empty():
		n += 1
	return n


# --- tempo ---

## Passa un'ora di gioco: sanguinamento (la salute non scende sotto 1) e guarigione.
## Ritorna {"msgs": Array, "bleed": int (salute persa), "fainted": bool}.
static func tick_hour() -> Dictionary:
	var msgs: Array = []
	var lost := 0
	var fainted := false
	var bleed := bleed_per_hour()
	if bleed > 0:
		var cur := int(PlayerState.health)
		if cur <= 1:
			fainted = true
		else:
			lost = mini(bleed, cur - 1)
			PlayerState.damage(lost)
			if int(PlayerState.health) <= 1:
				fainted = true

	var changed := false
	var step_b := num("bandaged_heal_mult", 2.0)
	for w in wounds.duplicate():
		if bool(w["bleeding"]):
			continue
		var step := step_b if bool(w["bandaged"]) else 1.0
		w["hours_left"] = float(w["hours_left"]) - step
		changed = true
		if float(w["hours_left"]) <= 0.0:
			wounds.erase(w)
			msgs.append("%s è guarita." % wound_name(w))
	if changed:
		_notify()
	return {"msgs": msgs, "bleed": lost, "fainted": fainted}
