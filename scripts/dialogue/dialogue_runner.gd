class_name DialogueRunner
extends RefCounted
## Esegue una conversazione tra il giocatore e un NPC (nessuna UI qui dentro).
## Uso:
##   var r := DialogueRunner.new()
##   r.start(npc)               # npc = dizionario dal NPCRegistry
##   var cur := r.current()     # {text, choices:[{index, text, enabled}]}
##   r.choose(cur.choices[0].index)
##   r.finished / r.messages    # fine conversazione, esiti dell'ultima scelta
##
## Condizioni ("if"): min_rel, max_rel, min_money, slot, info, no_info,
##   stat {stat, min}, rep {group, min}, quest_available, quest_ready ("deliver"/"report"/true),
##   debt (true/false: hai debiti con la banca), overdue (true/false: debito scaduto)
## Effetti: relationship, reputation, info, money, quest_offer, quest_accept, quest_decline, quest_complete
## Segnaposto nei testi: {name}, {player}, {job}, {workplace}

var npc: Dictionary = {}
var dialogue_id := "generic"
var node_id := "start"
var finished := false
var messages: Array[String] = []


func start(npc_dict: Dictionary) -> void:
	npc = npc_dict
	dialogue_id = DialogueDB.dialogue_for_job(String(npc.get("job", "")))
	node_id = "start"
	finished = false
	messages.clear()
	if not npc.get("met", false):
		npc["met"] = true
		var bonus := int(NPCDB.data().get("relationship", {}).get("first_greeting_bonus", 0))
		if bonus != 0:
			NPCRegistry.change_relationship(String(npc["id"]), bonus)
		messages.append("Vi siete presentati (relazione %+d)." % bonus)


func current() -> Dictionary:
	var node := DialogueDB.node(dialogue_id, node_id)
	var text := String(node.get("text", "..."))
	for v in node.get("variants", []):
		if _check(v.get("if", {})):
			text = String(v.get("text", text))
			break

	var choices: Array[Dictionary] = []
	var list: Array = node.get("choices", [])
	for i in list.size():
		var c: Dictionary = list[i]
		if c.get("once", false) and _flags().has(_choice_key(i)):
			continue
		var ok := _check(c.get("if", {}))
		if not ok and not c.get("show_locked", false):
			continue
		choices.append({"index": i, "text": _fmt(String(c.get("text", "..."))), "enabled": ok})
	return {"text": _fmt(text), "choices": choices}


func choose(index: int) -> void:
	var list: Array = DialogueDB.node(dialogue_id, node_id).get("choices", [])
	if index < 0 or index >= list.size():
		return
	var c: Dictionary = list[index]
	if not _check(c.get("if", {})):
		return
	messages.clear()
	if c.get("once", false):
		_flags()[_choice_key(index)] = true
	for e in c.get("effects", []):
		_apply(e)
	var nxt := String(c.get("next", "end"))
	if nxt == "" or nxt == "end":
		finished = true
	else:
		node_id = nxt


# --- interno ---

func _flags() -> Dictionary:
	if not npc.has("dialog_flags"):
		npc["dialog_flags"] = {}
	return npc["dialog_flags"]


func _choice_key(index: int) -> String:
	return "%s:%s:%d" % [dialogue_id, node_id, index]


func _fmt(text: String) -> String:
	var first := String(npc.get("name", "")).split(" ")[0]
	var wp := String(BuildingDB.get_type(String(npc.get("workplace", ""))).get("name", "la città"))
	var q := _quest_ctx()
	return text.replace("{name}", first) \
		.replace("{player}", _player_name()) \
		.replace("{job}", String(npc.get("job_label", "")).to_lower()) \
		.replace("{workplace}", wp) \
		.replace("{debt}", str(BankSystem.debt_total())) \
		.replace("{quest_title}", String(q.get("title", ""))) \
		.replace("{quest_text}", String(q.get("text", ""))) \
		.replace("{quest_hint}", String(q.get("hint", ""))) \
		.replace("{quest_giver}", String(q.get("giver_name", "")).split(" ")[0]) \
		.replace("{quest_reward}", QuestState.reward_text(q))


func _player_name() -> String:
	var n = PlayerState.get("player_name")
	if n == null:
		n = PlayerState.get("name")
	if n != null and String(n) != "":
		return String(n)
	return "forestiero"


func _player_stat(stat: String) -> int:
	var st = PlayerState.get("stats")
	if st is Dictionary:
		return int(st.get(stat, 0))
	return -1   # statistiche non disponibili


func _check(cond: Dictionary) -> bool:
	if cond.is_empty():
		return true
	var rel := int(npc.get("relationship", 0))
	if cond.has("min_rel") and rel < int(cond["min_rel"]):
		return false
	if cond.has("max_rel") and rel > int(cond["max_rel"]):
		return false
	if cond.has("min_money") and BuildingActions.player_money() < int(cond["min_money"]):
		return false
	if cond.has("slot"):
		var slots = cond["slot"]
		var now := String(npc.get("slot", ""))
		if slots is Array:
			if not slots.has(now):
				return false
		elif String(slots) != now:
			return false
	if cond.has("info") and not DialogueState.knows(String(cond["info"])):
		return false
	if cond.has("no_info") and DialogueState.knows(String(cond["no_info"])):
		return false
	if cond.has("stat"):
		var v := _player_stat(String(cond["stat"]))
		if v >= 0 and v < int(cond.get("min", 0)):
			return false
	if cond.has("quest_available") and QuestState.can_offer(String(npc.get("id", ""))) != bool(cond["quest_available"]):
		return false
	if cond.has("quest_ready"):
		var want = cond["quest_ready"]
		var role := String(want) if want is String else ""
		var has := not QuestState.ready_for(String(npc.get("id", "")), role).is_empty()
		var need: bool = not (want is bool and not bool(want))
		if has != need:
			return false
	if cond.has("debt") and BankSystem.has_debt() != bool(cond["debt"]):
		return false
	if cond.has("overdue") and BankSystem.has_overdue() != bool(cond["overdue"]):
		return false
	if cond.has("rep"):
		var rc: Dictionary = cond["rep"]
		if DialogueState.get_reputation(String(rc.get("group", ""))) < int(rc.get("min", 0)):
			return false
	return true


func _apply(e: Dictionary) -> void:
	match String(e.get("type", "")):
		"relationship":
			var d := int(e.get("value", 0))
			NPCRegistry.change_relationship(String(npc["id"]), d)
			messages.append("Relazione con %s: %+d" % [String(npc["name"]).split(" ")[0], d])
			_tier_message(ReputationSystem.on_relationship(npc, d), ReputationSystem.group_for_job(String(npc.get("job", ""))))
		"reputation":
			var g := String(e.get("group", ""))
			var d := int(e.get("value", 0))
			var res := ReputationSystem.add(g, d)
			messages.append("Reputazione (%s): %+d" % [ReputationSystem.group_label(g), d])
			_tier_message(res, g)
		"info":
			var id := String(e.get("id", ""))
			if DialogueState.learn(id):
				messages.append("Nuova informazione: %s" % String(DialogueDB.info(id).get("title", id)))
		"quest_offer":
			QuestState.offer_for(npc)
		"quest_accept":
			var q := QuestState.accept(String(npc.get("id", "")))
			if not q.is_empty():
				messages.append("Nuova missione: %s" % String(q["title"]))
		"quest_decline":
			QuestState.decline(String(npc.get("id", "")))
		"quest_complete":
			messages.append_array(QuestState.complete(String(npc.get("id", "")), String(e.get("role", ""))))
		"money":
			var v := int(e.get("value", 0))
			if v > 0:
				PlayerState.add_money(v)
				messages.append("Ricevi $%d" % v)
			elif v < 0:
				var r = PlayerState.spend_money(-v)
				if not (r is bool and r == false):
					messages.append("Spendi $%d" % -v)


func _tier_message(res: Dictionary, group: String) -> void:
	if res.get("changed", false):
		messages.append("Ora per i %s sei: %s" % [ReputationSystem.group_label(group).to_lower(), String(res["label"])])


func _quest_ctx() -> Dictionary:
	var id := String(npc.get("id", ""))
	if QuestState.offers.has(id):
		return QuestState.offers[id]
	for q in QuestState.active:
		if q["giver"] == id or q["turn_in"] == id:
			return q
	var d := QuestState.last_done
	if not d.is_empty() and (d["giver"] == id or d["turn_in"] == id):
		return d
	return {}
