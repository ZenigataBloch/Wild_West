class_name BuildingDB
extends RefCounted
## Accesso ai dati degli edifici (data/buildings.json).

const PATH := "res://data/buildings.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"layout": [], "types": {}}
	return _data


static func layout() -> Array:
	return data().get("layout", [])


static func types() -> Dictionary:
	return data().get("types", {})


static func get_type(id: String) -> Dictionary:
	return types().get(id, {})
