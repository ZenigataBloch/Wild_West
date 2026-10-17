class_name QuestState
extends RefCounted
## Stato delle missioni della partita (solo in memoria; il salvataggio arriverà più avanti).
## active: missioni accettate, state "active" (da svolgere) o "ready" (da consegnare).
## offers: proposta in corso per ogni NPC (id -> missione).

static var active: Array[Dictionary] = []
static var offers: Dictionary = {}
static var completed: Array[String] = []
static var last_done: Dictionary = {}
static var counter := 0
static var version := 0   # cambia a ogni modifica: il QuestManager si aggiorna


static func reset() -> void:
	active.clear()
	offers.clear()
	completed.clear()
	last_done = {}
	counter = 0
	version += 1


static func by_giver(npc_id: String) -> Dictionary:
	for q in active:
		if q["giver"] == npc_id:
			return q
	return {}


static func can_offer(npc_id: String) -> bool:
	return by_giver(npc_id).is_empty() and active.size() < QuestDB.max_active()


static func offer_for(npc: Dictionary) -> Dictionary:
	var id := String(npc.get("id", ""))
	if not offers.has(id):
		offers[id] = QuestGenerator.generate(npc)
	return offers[id]


static func accept(npc_id: String) -> Dictionary:
	if not offers.has(npc_id) or not can_offer(npc_id):
		return {}
	var q: Dictionary = offers[npc_id]
	offers.erase(npc_id)
	active.append(q)
	version += 1
	return q


static func decline(npc_id: String) -> void:
	offers.erase(npc_id)


static func ready_for(npc_id: String, role: String = "") -> Dictionary:
	for q in active:
		if q["state"] == "ready" and q["turn_in"] == npc_id and (role == "" or q["role"] == role):
			return q
	return {}


static func set_ready(q: Dictionary) -> void:
	q["state"] = "ready"
	version += 1


## Consegna la missione pronta presso questo NPC e assegna le ricompense. Ritorna i messaggi.
static func complete(npc_id: String, role: String = "") -> Array[String]:
	var msgs: Array[String] = []
	var q := ready_for(npc_id, role)
	if q.is_empty():
		return msgs
	active.erase(q)
	completed.append(String(q["id"]))
	last_done = q
	version += 1

	var r: Dictionary = q["reward"]
	var money := int(r.get("money", 0))
	if money > 0:
		PlayerState.add_money(money)
		msgs.append("Missione completata: %s" % String(q["title"]))
		msgs.append("Ricevi $%d" % money)
	var rel := int(r.get("rel", 0))
	if rel != 0:
		NPCRegistry.change_relationship(String(q["giver"]), rel)
		msgs.append("Relazione con %s: %+d" % [String(q["giver_name"]).split(" ")[0], rel])
	var rep := int(r.get("rep", 0))
	if rep != 0:
		var g := String(r.get("rep_group", "cittadini"))
		var res := ReputationSystem.add(g, rep)
		msgs.append("Reputazione (%s): %+d" % [ReputationSystem.group_label(g), rep])
		if res.get("changed", false):
			msgs.append("Ora per i %s sei: %s" % [ReputationSystem.group_label(g).to_lower(), String(res["label"])])
	return msgs


static func reward_text(q: Dictionary) -> String:
	return "$%d" % int(q.get("reward", {}).get("money", 0))


## Dove si trova ora un NPC (per i suggerimenti delle missioni): dentro un edificio, a casa,
## davanti a un edificio o semplicemente in strada. Legge i dati aggiornati dalle routine (Feature 7).
static func whereabouts(npc_id: String) -> String:
	var n := NPCRegistry.get_npc(npc_id)
	if n.is_empty():
		return ""
	var inside := str(n.get("inside", ""))
	if inside == "home":
		return "a casa, di solito esce al mattino"
	if inside != "":
		return "dentro: %s" % str(BuildingDB.get_type(inside).get("name", inside))
	var pos = n.get("position", null)
	if pos is Vector2:
		for key in JobSites.points:
			if not str(key).begins_with("building:"):
				continue
			var bid := str(key).substr(9)
			if bid == "house":
				continue
			if (pos as Vector2).distance_to(JobSites.points[key]) <= 140.0:
				return "in strada, davanti a: %s" % str(BuildingDB.get_type(bid).get("name", bid))
	return "in strada"


static func _where_suffix(npc_id: String) -> String:
	var w := whereabouts(npc_id)
	return "" if w == "" else " (%s)" % w


static func progress_text(q: Dictionary) -> String:
	match String(q["type"]):
		"hunt":
			return "%d/%d %s" % [int(q["progress"]), int(q["goal"]), String(q["animal"])]
		"protection":
			return "%d/%d s accanto a %s" % [int(q["progress"]), int(q["goal"]), String(q["target_name"]).split(" ")[0]] + _where_suffix(String(q["target"]))
		"retrieval":
			return "Recupera %s" % String(q["item"])
		"delivery":
			return "Consegna a %s" % String(q["target_name"]).split(" ")[0] + _where_suffix(String(q["target"]))
	return ""


## Testo per una missione pronta: dove portare il pacco / da chi tornare, con posizione attuale dell'NPC.
static func ready_text(q: Dictionary, panel: bool = false) -> String:
	if q["role"] == "deliver":
		return "Consegna a %s" % String(q["target_name"]).split(" ")[0] + _where_suffix(String(q["target"]))
	var who := String(q["giver_name"]).split(" ")[0]
	return ("Pronta: torna da %s" if panel else "Torna da %s") % who + _where_suffix(String(q["giver"]))
