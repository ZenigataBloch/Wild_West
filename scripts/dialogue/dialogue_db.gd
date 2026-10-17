class_name DialogueDB
extends RefCounted
## Accesso ai dati dei dialoghi (data/dialogues.json).

const PATH := "res://data/dialogues.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"dialogues": {}, "info": {}, "reputation_groups": {}}
	return _data


## Dialogo da usare per un lavoro (cade su "generic" se non esiste).
static func dialogue_for_job(job: String) -> String:
	var d: Dictionary = data().get("dialogues", {})
	return job if d.has(job) else "generic"


static func node(dialogue_id: String, node_id: String) -> Dictionary:
	var d: Dictionary = data().get("dialogues", {})
	var n: Dictionary = d.get(dialogue_id, {}).get("nodes", {}).get(node_id, {})
	if n.is_empty() and node_id.begins_with("q_"):   # nodi missione condivisi
		n = d.get("generic", {}).get("nodes", {}).get(node_id, {})
	return n


static func info(info_id: String) -> Dictionary:
	return data().get("info", {}).get(info_id, {})
