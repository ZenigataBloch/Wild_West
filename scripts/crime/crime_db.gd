class_name CrimeDB
extends RefCounted
## Accesso ai dati di data/crime.json (Feature 20).

const PATH := "res://data/crime.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var parsed = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
		else:
			push_warning("CrimeDB: manca " + PATH)
	return _data


static func section(key: String) -> Dictionary:
	var v = data().get(key, {})
	if v is Dictionary:
		return v
	return {}


static func value(key: String, default = null):
	return data().get(key, default)


static func pick(list, rng: RandomNumberGenerator, default: String = "") -> String:
	if not (list is Array) or list.is_empty():
		return default
	return str(list[rng.randi_range(0, list.size() - 1)])


static func fmt(text: String, vars: Dictionary) -> String:
	var out := text
	for k in vars:
		out = out.replace("{%s}" % str(k), str(vars[k]))
	return out
