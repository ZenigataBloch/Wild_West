class_name NPCRegistry
extends RefCounted
## Archivio dei cittadini della partita corrente.
## Le routine (F7), i dialoghi (F8), la reputazione (F9) e le missioni (F10)
## leggono e modificano gli NPC da qui.

static var npcs: Array[Dictionary] = []


static func set_all(list: Array[Dictionary]) -> void:
	npcs = list


static func get_npc(id: String) -> Dictionary:
	for n in npcs:
		if n["id"] == id:
			return n
	return {}


static func by_job(job: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for n in npcs:
		if n["job"] == job:
			out.append(n)
	return out


static func change_relationship(id: String, delta: int) -> int:
	var n := get_npc(id)
	if n.is_empty():
		return 0
	var r: Dictionary = NPCDB.data().get("relationship", {})
	n["relationship"] = clampi(int(n["relationship"]) + delta, int(r.get("min", -100)), int(r.get("max", 100)))
	return int(n["relationship"])


static func relationship_label(value: int) -> String:
	var levels: Array = NPCDB.data().get("relationship", {}).get("levels", [])
	for l in levels:
		if value <= int(l["max"]):
			return String(l["label"])
	return "Neutrale"
