class_name NPCGenerator
extends RefCounted
## Genera i cittadini a partire da data/npcs.json e dagli edifici già piazzati.
## Usa il canale seed "npcs": stessa partita = stessi cittadini.
## Ogni NPC è un Dictionary:
##   id, name, age, job, job_label, role, workplace, position (Vector2),
##   stats {forza, mira, agilita, carisma, resistenza}, relationship, met,
##   badge, skin, shirt, hat


static func generate(buildings: Array, street_y: float) -> Array[Dictionary]:
	var cfg := NPCDB.data()
	var rng: RandomNumberGenerator = WorldSeed.rng_for("npcs")
	var jobs: Dictionary = cfg.get("jobs", {})
	var count := int(cfg.get("count", 10))

	# Lavori garantiti, poi riempimento a peso
	var job_ids: Array = []
	for id in jobs:
		for i in int(jobs[id].get("guaranteed", 0)):
			job_ids.append(id)
	var pool: Array = []
	for id in jobs:
		for i in int(jobs[id].get("weight", 0)):
			pool.append(id)
	while job_ids.size() < count and not pool.is_empty():
		job_ids.append(pool[rng.randi_range(0, pool.size() - 1)])

	var used_names := {}
	var taken: Array[Vector2] = []
	var out: Array[Dictionary] = []
	for i in job_ids.size():
		var jid: String = job_ids[i]
		out.append(_make(i, jid, jobs[jid], cfg, rng, buildings, street_y, used_names, taken))
	return out


static func _make(idx: int, jid: String, job: Dictionary, cfg: Dictionary, rng: RandomNumberGenerator,
		buildings: Array, street_y: float, used_names: Dictionary, taken: Array[Vector2]) -> Dictionary:
	var stats := {}
	var base: Array = cfg.get("stat_base", [3, 6])
	var bias: Dictionary = job.get("bias", {})
	for s in cfg.get("stat_names", []):
		stats[s] = clampi(rng.randi_range(int(base[0]), int(base[1])) + int(bias.get(s, 0)), 1, 10)

	var age_range: Array = job.get("age", [20, 60])
	var wp := String(job.get("workplace", ""))
	var wb := _find_building(buildings, wp) if wp != "" else {}
	if wb.is_empty():
		wp = ""

	var pos := _pick_position(rng, wb, buildings, street_y, taken)
	taken.append(pos)

	return {
		"id": "npc_%02d" % idx,
		"name": _unique_name(cfg, rng, used_names),
		"age": rng.randi_range(int(age_range[0]), int(age_range[1])),
		"job": jid,
		"job_label": String(job.get("label", jid.capitalize())),
		"role": String(job.get("role", "Cittadino")),
		"workplace": wp,
		"position": pos,
		"stats": stats,
		"relationship": int(cfg.get("relationship", {}).get("start", 0)),
		"met": false,
		"badge": bool(job.get("badge", false)),
		"skin": _pick(cfg.get("skins", ["#e0b48a"]), rng),
		"shirt": _pick(cfg.get("shirts", ["#6b5a2e"]), rng),
		"hat": _pick(cfg.get("hats", ["#4a2f1a"]), rng),
	}


static func _pick(list: Array, rng: RandomNumberGenerator) -> String:
	return String(list[rng.randi_range(0, list.size() - 1)])


static func _unique_name(cfg: Dictionary, rng: RandomNumberGenerator, used: Dictionary) -> String:
	var firsts: Array = cfg.get("first_names", ["Joe"])
	var lasts: Array = cfg.get("last_names", ["Doe"])
	var nicks: Array = cfg.get("nicknames", [])
	var full := ""
	for attempt in 30:
		full = "%s %s" % [_pick(firsts, rng), _pick(lasts, rng)]
		if not used.has(full):
			break
	used[full] = true
	if not nicks.is_empty() and rng.randf() < float(cfg.get("nickname_chance", 0.0)):
		full += " \"%s\"" % _pick(nicks, rng)
	return full


static func _find_building(buildings: Array, id: String) -> Dictionary:
	for b in buildings:
		if b.get("id", "") == id:
			return b
	return {}


static func _pick_position(rng: RandomNumberGenerator, wb: Dictionary, buildings: Array,
		street_y: float, taken: Array[Vector2]) -> Vector2:
	var pos := Vector2.ZERO
	for attempt in 8:
		if not wb.is_empty():
			var e: Vector2 = wb["entrance"]
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var dy := 40.0 if wb.get("door_on_bottom", true) else -40.0
			pos = Vector2(e.x + side * rng.randf_range(70.0, 130.0), e.y + dy)
		else:
			var x_min := -300.0
			var x_max := 300.0
			if not buildings.is_empty():
				x_min = INF
				x_max = -INF
				for b in buildings:
					var r: Rect2 = b["rect"]
					x_min = minf(x_min, r.position.x)
					x_max = maxf(x_max, r.end.x)
			pos = Vector2(rng.randf_range(x_min, x_max), street_y + rng.randf_range(-20.0, 20.0))
		var ok := true
		for t in taken:
			if t.distance_to(pos) < 60.0:
				ok = false
				break
		if ok:
			break
	return pos
