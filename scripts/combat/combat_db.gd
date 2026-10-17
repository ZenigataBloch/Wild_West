class_name CombatDB
extends RefCounted
## Accesso ai dati del combattimento (data/combat.json): numeri, nemici, incontri.

const PATH := "res://data/combat.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"enemies": {}, "actions": {}}
	return _data


static func cfg(key: String, default = null):
	return data().get(key, default)


static func num(key: String, default: float) -> float:
	return float(data().get(key, default))


static func enemy(id: String) -> Dictionary:
	return data().get("enemies", {}).get(id, {})


static func action_def(id: String) -> Dictionary:
	return data().get("actions", {}).get(id, {})


static func encounters() -> Dictionary:
	return data().get("encounters", {})
