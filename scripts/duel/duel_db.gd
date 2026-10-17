class_name DuelDB
extends RefCounted
## Accesso ai dati dei duelli (data/duels.json).

const PATH := "res://data/duels.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
		if _data.is_empty():
			push_warning("DuelDB: impossibile leggere %s" % PATH)
	return _data


static func section(key: String) -> Dictionary:
	var v = data().get(key, {})
	return v if v is Dictionary else {}


static func value(key: String, default = null):
	return data().get(key, default)


## Testo dal blocco "text": stringa, oppure una scelta casuale se è una lista.
static func text(key: String, vars: Dictionary = {}, rng: RandomNumberGenerator = null) -> String:
	var t = section("text").get(key, "")
	if t is Array:
		if t.is_empty():
			return ""
		var i := 0
		if rng != null:
			i = rng.randi_range(0, t.size() - 1)
		t = t[i]
	return str(t).format(vars)
