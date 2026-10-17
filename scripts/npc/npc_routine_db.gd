class_name NPCRoutineDB
extends RefCounted
## Dati delle routine (data/npc_routines.json): fasce orarie, attività per fascia,
## eccezioni per lavoro e testi delle attività.

const PATH := "res://data/npc_routines.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"slots": []}
	return _data


static func slots() -> Array:
	return data().get("slots", [])


static func slot_id(index: int) -> String:
	var s := slots()
	if index < 0 or index >= s.size():
		return ""
	return String(s[index]["id"])


## Indice della fascia oraria per l'ora data (gestisce le fasce che attraversano la mezzanotte).
static func slot_index(hour: float) -> int:
	var h := fposmod(hour, 24.0)
	var s := slots()
	for i in s.size():
		var a := float(s[i]["from"])
		var b := float(s[i]["to"])
		if a < b:
			if h >= a and h < b:
				return i
		elif h >= a or h < b:
			return i
	return 0


## Sceglie un'attività (pesata) per quella fascia, tenendo conto delle eccezioni del lavoro.
static func pick_activity(slot: String, job: String, rng: RandomNumberGenerator) -> String:
	var list: Array = []
	var ov: Dictionary = data().get("job_overrides", {}).get(job, {})
	if ov.has(slot):
		list = ov[slot]
	else:
		for s in slots():
			if s["id"] == slot:
				list = s.get("activities", [])
	if list.is_empty():
		return "work"
	var total := 0.0
	for a in list:
		total += float(a.get("weight", 1))
	var roll := rng.randf() * total
	for a in list:
		roll -= float(a.get("weight", 1))
		if roll <= 0.0:
			return String(a["type"])
	return String(list[0]["type"])


static func activity_text(activity: String) -> String:
	return String(data().get("activity_labels", {}).get(activity, ""))
