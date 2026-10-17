class_name GangDB
extends RefCounted
## Accesso ai dati delle gang (data/gangs.json).

const PATH := "res://data/gangs.json"

static var _data: Dictionary = {}
static var _loaded: bool = false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f == null:
			push_warning("GangDB: impossibile aprire %s" % PATH)
		else:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				_data = parsed
			else:
				push_warning("GangDB: JSON non valido in %s" % PATH)
	return _data


static func section(key: String) -> Dictionary:
	var v: Variant = data().get(key, {})
	if v is Dictionary:
		return v
	return {}


static func num(sec: String, key: String, default_value: float = 0.0) -> float:
	return float(section(sec).get(key, default_value))


static func text(key: String, default_value: String = "") -> String:
	return str(section("texts").get(key, default_value))


## Testo con segnaposto {chiave}.
static func fmt(key: String, vars: Dictionary) -> String:
	return text(key, key).format(vars)
