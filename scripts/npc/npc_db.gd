class_name NPCDB
extends RefCounted
## Accesso alla configurazione degli NPC (data/npcs.json).

const PATH := "res://data/npcs.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"count": 0, "jobs": {}, "stat_names": []}
	return _data


static func jobs() -> Dictionary:
	return data().get("jobs", {})


static func stat_label(stat: String) -> String:
	return String(data().get("stat_labels", {}).get(stat, stat.capitalize()))
