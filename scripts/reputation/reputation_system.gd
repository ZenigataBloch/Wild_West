class_name ReputationSystem
extends RefCounted
## Reputazione del giocatore per gruppo (data/reputation.json).
## I valori vivono in DialogueState.reputation (solo in memoria, il salvataggio arriva più avanti).
## Effetti attivi: prezzi dei commercianti (price), relazioni NPC -> gruppo del loro lavoro,
## collegamenti tra gruppi (legge/gang, cittadini/commercianti) e condizioni "rep" nei dialoghi.

const PATH := "res://data/reputation.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"groups": {}, "tiers": []}
	return _data


static func groups() -> Array:
	return data().get("groups", {}).keys()


static func group_label(group: String) -> String:
	return String(data().get("groups", {}).get(group, {}).get("label", group.capitalize()))


static func group_desc(group: String) -> String:
	return String(data().get("groups", {}).get(group, {}).get("desc", ""))


static func value(group: String) -> int:
	return int(DialogueState.reputation.get(group, 0))


static func tier(group: String) -> Dictionary:
	var v := value(group)
	var list: Array = data().get("tiers", [])
	for t in list:
		if v <= int(t.get("max", 100)):
			return t
	return list.back() if not list.is_empty() else {"label": "-", "price_mult": 1.0}


static func tier_label(group: String) -> String:
	return String(tier(group).get("label", "-"))


## Aggiunge reputazione (limitata a min/max) e propaga ai gruppi collegati.
## Ritorna {"value": int, "changed": bool (cambio di fascia), "label": String}.
static func add(group: String, delta: int, spill: bool = true) -> Dictionary:
	var before := tier_label(group)
	var lo := int(data().get("min", -100))
	var hi := int(data().get("max", 100))
	DialogueState.reputation[group] = clampi(value(group) + delta, lo, hi)
	if spill:
		var links: Dictionary = data().get("links", {}).get(group, {})
		for g in links:
			var d := roundi(float(delta) * float(links[g]))
			if d != 0:
				add(String(g), d, false)
	var after := tier_label(group)
	return {"value": value(group), "changed": before != after, "label": after}


## Gruppo di reputazione legato al lavoro di un NPC.
static func group_for_job(job: String) -> String:
	return String(data().get("job_groups", {}).get(job, "cittadini"))


## Una variazione di relazione con un NPC sposta un po' la reputazione del suo gruppo.
static func on_relationship(npc: Dictionary, delta: int) -> Dictionary:
	var d := roundi(float(delta) * float(data().get("relationship_factor", 0.5)))
	if d == 0:
		return {"changed": false}
	return add(group_for_job(String(npc.get("job", ""))), d)


static func price_mult() -> float:
	var g := String(data().get("price_group", "commercianti"))
	return float(tier(g).get("price_mult", 1.0))


## Prezzo finale dopo la reputazione presso i commercianti (mai 0 se il prezzo base è > 0).
static func price(base: int) -> int:
	if base <= 0:
		return base
	return maxi(1, roundi(float(base) * price_mult()))
