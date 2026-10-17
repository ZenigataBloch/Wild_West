class_name DialogueState
extends RefCounted
## Cosa ha imparato il giocatore parlando (informazioni) e la reputazione per gruppo.
## Il sistema di reputazione completo (Feature 9) leggerà e userà questi dati.
## Per ora vive solo in memoria (il salvataggio arriverà più avanti).

static var known_info: Array[String] = []
static var reputation: Dictionary = {}   # gruppo -> valore


## Nuova partita: dimentica informazioni e reputazione.
static func reset() -> void:
	known_info.clear()
	reputation.clear()


static func knows(info_id: String) -> bool:
	return known_info.has(info_id)


## Ritorna true se l'informazione è nuova.
static func learn(info_id: String) -> bool:
	if known_info.has(info_id):
		return false
	known_info.append(info_id)
	return true


static func get_reputation(group: String) -> int:
	return int(reputation.get(group, 0))
