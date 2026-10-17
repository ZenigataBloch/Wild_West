class_name QuestGenerator
extends RefCounted
## Crea una missione per un NPC (dipende dal seed, canale "quest_<npc>_<n>").
## Tipi: delivery (consegna), retrieval (recupero), protection (protezione), hunt (caccia).


static func generate(giver: Dictionary) -> Dictionary:
	QuestState.counter += 1
	var rng: RandomNumberGenerator = WorldSeed.rng_for("quest_%s_%d" % [giver["id"], QuestState.counter])
	var type := _pick_type(rng, String(giver.get("job", "")))
	var target := {}
	if type == "delivery" or type == "protection":
		target = _pick_target(rng, giver)
		if target.is_empty():
			type = "retrieval"
	var def := QuestDB.type_def(type)

	var q := {
		"id": "q%d" % QuestState.counter,
		"type": type,
		"giver": String(giver["id"]),
		"giver_name": String(giver.get("name", "")),
		"target": "",
		"target_name": "",
		"item": "",
		"animal": "",
		"goal": 1,
		"progress": 0,
		"state": "active",
		"turn_in": String(giver["id"]),
		"role": "report",
		"pos": [],
		"reward": {},
	}
	var ctx := {"giver": String(giver.get("name", "")).split(" ")[0]}

	match type:
		"delivery":
			q["target"] = String(target["id"])
			q["target_name"] = String(target["name"])
			q["state"] = "ready"            # il pacco è già in mano: si consegna al destinatario
			q["turn_in"] = String(target["id"])
			q["role"] = "deliver"
		"protection":
			q["target"] = String(target["id"])
			q["target_name"] = String(target["name"])
			var s: Array = def.get("seconds", [40, 60])
			q["goal"] = rng.randi_range(int(s[0]), int(s[1]))
		"retrieval":
			q["item"] = String(_pick(rng, def.get("items", ["un oggetto"])))
		"hunt":
			q["animal"] = String(_pick(rng, def.get("animals", ["coyote"])))
			var c: Array = def.get("count", [2, 3])
			q["goal"] = rng.randi_range(int(c[0]), int(c[1]))

	ctx["target"] = String(q["target_name"]).split(" ")[0]
	ctx["target_job"] = String(target.get("job_label", "")).to_lower()
	ctx["item"] = q["item"]
	ctx["animal"] = q["animal"]
	ctx["count"] = str(q["goal"])
	ctx["seconds"] = str(q["goal"])

	q["title"] = _fill(String(_pick(rng, def.get("titles", ["Missione"]))), ctx)
	q["text"] = _fill(String(_pick(rng, def.get("texts", [""]))), ctx)
	q["hint"] = _fill(String(def.get("hint", "")), ctx)

	var rw: Dictionary = def.get("reward", {})
	q["reward"] = {
		"money": _range(rng, rw.get("money", [5, 10])),
		"rel": _range(rng, rw.get("rel", [2, 4])),
		"rep": _range(rng, rw.get("rep", [1, 1])),
		"rep_group": ReputationSystem.group_for_job(String(giver.get("job", ""))),
	}
	return q


static func _pick_type(rng: RandomNumberGenerator, job: String) -> String:
	var w: Dictionary = QuestDB.data().get("job_weights", {})
	var table: Dictionary = w.get(job, w.get("default", {"retrieval": 1}))
	var total := 0
	for k in table:
		total += int(table[k])
	var roll := rng.randi_range(1, maxi(1, total))
	for k in table:
		roll -= int(table[k])
		if roll <= 0:
			return String(k)
	return "retrieval"


static func _pick_target(rng: RandomNumberGenerator, giver: Dictionary) -> Dictionary:
	var others: Array[Dictionary] = []
	for n in NPCRegistry.npcs:
		if n["id"] != giver["id"]:
			others.append(n)
	if others.is_empty():
		return {}
	return others[rng.randi_range(0, others.size() - 1)]


static func _pick(rng: RandomNumberGenerator, list: Array):
	if list.is_empty():
		return ""
	return list[rng.randi_range(0, list.size() - 1)]


static func _range(rng: RandomNumberGenerator, r: Array) -> int:
	return rng.randi_range(int(r[0]), int(r[1]))


static func _fill(text: String, ctx: Dictionary) -> String:
	for k in ctx:
		text = text.replace("{%s}" % k, String(ctx[k]))
	return text
