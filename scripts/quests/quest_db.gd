class_name QuestDB
extends RefCounted
## Accesso ai dati delle missioni (data/quests.json).

const PATH := "res://data/quests.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"types": {}}
	return _data


static func type_def(type: String) -> Dictionary:
	return data().get("types", {}).get(type, {})


static func type_label(type: String) -> String:
	return String(type_def(type).get("label", type.capitalize()))


static func max_active() -> int:
	return int(data().get("max_active", 3))
