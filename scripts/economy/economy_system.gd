class_name EconomySystem
extends RefCounted
## Economia dinamica (Feature 16): prezzi, domanda, offerta e mercato locale. Dati in data/economy.json.
## Ogni bene ha un livello locale (dal seed: ogni città ha prezzi suoi), un'offerta e una domanda che
## tornano piano piano all'equilibrio; ogni giorno c'è un po' di rumore e ogni tanto un evento di mercato.
## indice prezzo = locale * (domanda / offerta) ^ elasticità, limitato tra min_index e max_index.
## Gli acquisti alzano la domanda; i turni di lavoro (minatore, cacciatore, commerciante) aumentano l'offerta.
## Il prezzo finale per il giocatore = indice di mercato, poi reputazione presso i commercianti.

const PATH := "res://data/economy.json"

static var _data: Dictionary = {}
static var goods: Dictionary = {}       # bene -> {local, supply, demand, prev}
static var active_event: Dictionary = {}   # {def, left}
static var last_day: int = 1


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"goods": {}}
	return _data


static func num(key: String, fallback: float) -> float:
	return float(data().get(key, fallback))


static func text(key: String, vars: Dictionary = {}) -> String:
	return str(data().get("text", {}).get(key, "")).format(vars)


## Nuova partita: livelli locali dal seed, offerta e domanda in equilibrio, nessun evento.
static func reset() -> void:
	goods.clear()
	active_event = {}
	last_day = int(GameTime.day) if "day" in GameTime else 1
	var rng := WorldSeed.rng_for("economy")
	var spread := num("local_spread", 0.12)
	for g in good_ids():
		goods[g] = {"local": 1.0 + rng.randf_range(-spread, spread), "supply": 1.0, "demand": 1.0, "prev": 1.0}
	for g in goods:
		goods[g]["prev"] = index(g)


static func good_ids() -> Array:
	return data().get("goods", {}).keys()


static func good_label(good: String) -> String:
	return str(data().get("goods", {}).get(good, {}).get("label", good.capitalize()))


static func good_desc(good: String) -> String:
	return str(data().get("goods", {}).get(good, {}).get("desc", ""))


## "buy" = cose che compri (meglio se costano poco), "sell" = cose che il tuo lavoro vende (meglio se valgono molto).
static func good_kind(good: String) -> String:
	return str(data().get("goods", {}).get(good, {}).get("kind", "buy"))


static func _event_mod(good: String, field: String) -> float:
	if active_event.is_empty():
		return 1.0
	return float(active_event["def"].get("effects", {}).get(good, {}).get(field, 1.0))


## Indice prezzo del bene (1.0 = normale). Beni sconosciuti o "" = 1.0.
static func index(good: String) -> float:
	if good == "" or not goods.has(good):
		return 1.0
	var s: Dictionary = goods[good]
	var d := float(s["demand"]) * _event_mod(good, "demand")
	var sp := maxf(float(s["supply"]) * _event_mod(good, "supply"), 0.05)
	var idx := float(s["local"]) * pow(d / sp, num("elasticity", 0.8))
	return clampf(idx, num("min_index", 0.6), num("max_index", 1.8))


## Prezzo finale di un acquisto: mercato + reputazione presso i commercianti.
static func price(good: String, base: int) -> int:
	if base <= 0:
		return maxi(base, 0)
	return ReputationSystem.price(maxi(1, roundi(float(base) * index(good))))


## Chi compra fa salire la domanda.
static func on_purchase(good: String, qty: int = 1) -> void:
	if goods.has(good):
		goods[good]["demand"] = float(goods[good]["demand"]) + num("purchase_impact", 0.02) * float(qty)


## Chi porta merce sul mercato fa salire l'offerta.
static func on_supply(good: String, amount: float) -> void:
	if goods.has(good) and amount > 0.0:
		goods[good]["supply"] = float(goods[good]["supply"]) + amount


## 1 = prezzo salito dall'ultimo giorno, -1 = sceso, 0 = stabile.
static func trend(good: String) -> int:
	if not goods.has(good):
		return 0
	var diff := index(good) - float(goods[good]["prev"])
	if absf(diff) < 0.01:
		return 0
	return 1 if diff > 0.0 else -1


## Testo breve sull'indice, per la paga dei lavori e il pannello: "+12%".
static func pct_text(good: String) -> String:
	var p := roundi((index(good) - 1.0) * 100.0)
	return "nella norma" if p == 0 else "%+d%%" % p


## Porta avanti i giorni di mercato fino a `day`. Ritorna i messaggi (eventi iniziati/finiti).
static func advance_to(day: int) -> Array[String]:
	var msgs: Array[String] = []
	if day < last_day:
		last_day = day
		return msgs
	var steps := mini(day - last_day, int(num("max_catchup_days", 10)))
	for i in steps:
		last_day += 1
		msgs.append_array(_tick_day(last_day))
	last_day = day
	return msgs


static func _tick_day(day: int) -> Array[String]:
	var msgs: Array[String] = []
	var rng := WorldSeed.rng_for("economy_day_%d" % day)
	var rev := num("reversion", 0.18)
	var noise := num("daily_noise", 0.04)
	for g in goods:
		var s: Dictionary = goods[g]
		s["prev"] = index(g)
		s["supply"] = float(s["supply"]) + (1.0 - float(s["supply"])) * rev + rng.randf_range(-noise, noise) * 0.5
		s["demand"] = float(s["demand"]) + (1.0 - float(s["demand"])) * rev + rng.randf_range(-noise, noise)
	# eventi di mercato
	if not active_event.is_empty():
		active_event["left"] = int(active_event["left"]) - 1
		if int(active_event["left"]) <= 0:
			msgs.append(text("event_end", {"title": str(active_event["def"].get("title", ""))}))
			active_event = {}
	if active_event.is_empty() and rng.randf() < num("event_chance", 0.12):
		var def := _pick_event(rng)
		if not def.is_empty():
			var dr: Array = def.get("days", [3, 5])
			active_event = {"def": def, "left": rng.randi_range(int(dr[0]), int(dr[1]))}
			msgs.append(text("event_start", {"title": str(def.get("title", "")), "text": str(def.get("text", ""))}))
	return msgs


static func _pick_event(rng: RandomNumberGenerator) -> Dictionary:
	var list: Array = data().get("events", [])
	var total := 0.0
	for e in list:
		total += float(e.get("weight", 1))
	if total <= 0.0:
		return {}
	var roll := rng.randf() * total
	for e in list:
		roll -= float(e.get("weight", 1))
		if roll <= 0.0:
			return e
	return list[0]


## Notizia attuale del mercato (vuota se non c'è un evento).
static func news() -> String:
	if active_event.is_empty():
		return ""
	var d: Dictionary = active_event["def"]
	return "%s: %s (ancora %d giorni)" % [str(d.get("title", "")), str(d.get("text", "")), int(active_event["left"])]
