class_name JobDB
extends RefCounted
## Accesso ai dati dei lavori (data/jobs.json).

const PATH := "res://data/jobs.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
		if _data.is_empty():
			push_warning("JobDB: impossibile leggere %s" % PATH)
	return _data


static func value(key: String, default = null):
	return data().get(key, default)


static func order() -> Array:
	return data().get("order", [])


static func job(id: String) -> Dictionary:
	var j = data().get("jobs", {}).get(id, {})
	return j if j is Dictionary else {}


static func ranks() -> Array:
	return data().get("ranks", [])


static func text(key: String, vars: Dictionary = {}) -> String:
	return str(data().get("text", {}).get(key, "")).format(vars)
