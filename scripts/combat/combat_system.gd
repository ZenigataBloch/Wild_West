class_name CombatSystem
extends RefCounted
## Logica del combattimento a turni (nessuna UI). Il giocatore agisce, poi agiscono i nemici.
## Ogni chiamata ritorna eventi {text, who ("player" o indice nemico), hp, kind (hit/miss/heal/down/info)}
## che la UI mostra in sequenza. Il danno al giocatore viene applicato a PlayerState solo alla fine
## (apply_results), così sconfitta e fuga non uccidono: la morte arriverà con le ferite (Feature 13).
## Le ferite (data/wounds.json, WoundSystem) si creano subito quando un colpo nemico va a segno:
## le penalità valgono già per il resto dello scontro; le Bende fermano un sanguinamento.
## Le armi vengono da data/weapons.json (WeaponDB) e dall'arma equipaggiata in PlayerState:
## arma da fuoco -> azione "Spara" (Mira), arma bianca -> azione "Colpisci" (Forza, al posto del pugno).
## state: "player" | "won" | "lost" | "fled"

var enemies: Array[Dictionary] = []
var player_hp := 0
var player_max := 1
var player_cover := false
var state := "player"
var loot := 0
var rep_gains: Dictionary = {}   # gruppo -> valore
var weapon_drops: Array[String] = []   # id armi trovate dopo la vittoria
var rng := RandomNumberGenerator.new()


func start(enemy_ids: Array, ambush: bool = false) -> Array[Dictionary]:
	rng.randomize()
	enemies.clear()
	loot = 0
	rep_gains.clear()
	weapon_drops.clear()
	player_cover = false
	state = "player"
	player_hp = int(PlayerState.health)
	player_max = maxi(1, int(PlayerState.max_health))

	var counts := {}
	for id in enemy_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	var seen := {}
	for id in enemy_ids:
		var def := CombatDB.enemy(String(id))
		if def.is_empty():
			continue
		var label := String(def.get("label", id))
		if int(counts[id]) > 1:
			seen[id] = int(seen.get(id, 0)) + 1
			label += " " + String.chr(64 + int(seen[id]))
		enemies.append({
			"i": enemies.size(),
			"def": String(id),
			"name": label,
			"hp": int(def.get("hp", 10)),
			"max_hp": int(def.get("hp", 10)),
			"stats": Dictionary(def.get("stats", {})).duplicate(),
			"attack": Dictionary(def.get("attack", {})).duplicate(),
			"loot": Array(def.get("loot", [0, 0])),
			"rep": Dictionary(def.get("rep", {})),
			"weapon_drop": Dictionary(def.get("weapon_drop", {})),
		})

	var ev: Array[Dictionary] = []
	if ambush and not enemies.is_empty():
		ev.append(_ev("Ti hanno teso un'imboscata!", "", -1, "info"))
		ev.append_array(_enemies_turn())
	return ev


func actions() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for id in ["shoot", "punch", "cover", "bandage", "flee"]:
		var d := CombatDB.action_def(id)
		var label := String(d.get("label", id))
		var hint := String(d.get("hint", ""))
		var ok := true
		match id:
			"shoot":
				var w := _weapon_for("shoot")
				if w != "":
					label = "%s (%s)" % [label, WeaponDB.name_of(w)]
					hint = WeaponDB.stats_text(w)
				else:
					ok = false
					hint = "Serve un'arma da fuoco equipaggiata (tasto I, doppio click sull'arma)"
			"punch":
				var w := _weapon_for("punch")
				if w != "":
					label = "Colpisci (%s)" % WeaponDB.name_of(w)
					hint = WeaponDB.stats_text(w)
			"cover":
				ok = not player_cover
			"bandage":
				ok = PlayerState.has_item("bende")
		out.append({"id": id, "label": label, "hint": hint, "enabled": ok})
	return out


func do_player(action: String, target_index: int) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	if state != "player":
		return ev
	match action:
		"shoot", "punch":
			if action == "shoot" and _weapon_for("shoot") == "":
				ev.append(_ev("Non hai un'arma da fuoco equipaggiata.", "", -1, "info"))
				return ev
			var target := _pick_target(target_index)
			if target.is_empty():
				return ev
			ev.append_array(_player_attack(action, target))
			if _alive().is_empty():
				_win(ev)
				return ev
		"cover":
			player_cover = true
			ev.append(_ev("Ti metti al riparo.", "player", -1, "info"))
		"bandage":
			if not PlayerState.remove_item("bende", 1):
				ev.append(_ev("Non hai bende.", "", -1, "info"))
				return ev
			var heal := int(CombatDB.num("bandage_heal", 25.0))
			player_hp = mini(player_max, player_hp + heal)
			ev.append(_ev("Ti fasci le ferite: +%d salute." % heal, "player", player_hp, "heal"))
			var treated := WoundSystem.bandage(true)
			if not treated.is_empty():
				ev.append(_ev("La fasciatura ferma il sanguinamento: %s." % WoundSystem.wound_name(treated).to_lower(), "player", -1, "info"))
		"flee":
			var avg := 0.0
			for e in _alive():
				avg += float(_stat(e, "agilita"))
			avg /= maxf(1.0, float(_alive().size()))
			var chance := clampf(CombatDB.num("flee_base", 0.4) + (float(PlayerState.get_stat("agilita")) - avg) * CombatDB.num("flee_per_point", 0.06), 0.15, 0.9)
			if rng.randf() <= chance:
				state = "fled"
				ev.append(_ev("Riesci a scappare!", "", -1, "info"))
				return ev
			ev.append(_ev("Non riesci a scappare!", "", -1, "info"))
		_:
			return ev
	ev.append_array(_enemies_turn())
	return ev


func result_text() -> String:
	match state:
		"won":
			var t := "Vittoria! Bottino: $%d." % loot
			for g in rep_gains:
				t += "\nReputazione (%s): %+d" % [ReputationSystem.group_label(String(g)), int(rep_gains[g])]
			for wid in weapon_drops:
				t += "\nArma trovata: %s (%s)" % [WeaponDB.name_of(wid), WeaponDB.rarity_label(wid)]
			return t
		"lost":
			return "Sei svenuto. Ti risvegli in città, più povero e dolorante."
		"fled":
			return "Sei riuscito a fuggire."
	return ""


## Applica gli esiti a PlayerState e ritorna i messaggi da mostrare.
func apply_results() -> Array[String]:
	var msgs: Array[String] = []
	var target_hp := player_hp
	if state == "lost":
		target_hp = int(CombatDB.num("lose_hp", 10.0))
	target_hp = clampi(target_hp, 1, player_max)
	var cur := int(PlayerState.health)
	if target_hp < cur:
		PlayerState.damage(cur - target_hp)
	elif target_hp > cur:
		PlayerState.heal(target_hp - cur)

	if state == "won":
		if loot > 0:
			PlayerState.add_money(loot)
			msgs.append("Ricevi $%d" % loot)
		for wid in weapon_drops:
			if PlayerState.add_item(wid, 1) == 0:
				msgs.append("Prendi: %s (%s)" % [WeaponDB.name_of(wid), WeaponDB.rarity_label(wid)])
			else:
				msgs.append("Zaino pieno: lasci %s." % WeaponDB.the_name(wid))
		for g in rep_gains:
			var res := ReputationSystem.add(String(g), int(rep_gains[g]))
			msgs.append("Reputazione (%s): %+d" % [ReputationSystem.group_label(String(g)), int(rep_gains[g])])
			if res.get("changed", false):
				msgs.append("Ora per i %s sei: %s" % [ReputationSystem.group_label(String(g)).to_lower(), String(res["label"])])
	elif state == "lost":
		var lost := int(float(BuildingActions.player_money()) * CombatDB.num("lose_money_fraction", 0.5))
		if lost > 0:
			PlayerState.spend_money(lost)
			msgs.append("Perdi $%d" % lost)
		if WoundSystem.bandage_all(true) > 0:
			msgs.append("Qualcuno ha fasciato le tue ferite.")
	return msgs


# --- interno ---

func _alive() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for e in enemies:
		if int(e["hp"]) > 0:
			out.append(e)
	return out


func _pick_target(index: int) -> Dictionary:
	if index >= 0 and index < enemies.size() and int(enemies[index]["hp"]) > 0:
		return enemies[index]
	var a := _alive()
	return a[0] if not a.is_empty() else {}


func _stat(e: Dictionary, key: String) -> int:
	return int(Dictionary(e["stats"]).get(key, 0))


## Arma da usare per un'azione di attacco: "shoot" -> arma da fuoco equipaggiata,
## "punch" -> arma bianca equipaggiata. "" = nessuna (a mani nude / non si può sparare).
func _weapon_for(action: String) -> String:
	var w := PlayerState.get_weapon()
	if w == "":
		return ""
	var k := WeaponDB.kind(w)
	if action == "shoot" and k == "ranged":
		return w
	if action == "punch" and k == "melee":
		return w
	return ""


func _chance(acc: int, agi: int, base: float, cover: bool, bonus: float = 0.0) -> float:
	var c := base + bonus + float(acc - agi) * CombatDB.num("hit_per_point", 0.04)
	if cover:
		c -= CombatDB.num("cover_penalty", 0.25)
	return clampf(c, CombatDB.num("hit_min", 0.1), CombatDB.num("hit_max", 0.95))


func _ev(text: String, who, hp: int, kind: String) -> Dictionary:
	return {"text": text, "who": who, "hp": hp, "kind": kind}


func _player_attack(kind: String, target: Dictionary) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	var idx := int(target["i"])
	var melee := kind == "punch"
	var weapon := _weapon_for(kind)   # "" = pugno
	var acc := PlayerState.get_stat("forza" if melee else "mira")
	var base := CombatDB.num("hit_base_melee" if melee else "hit_base_ranged", 0.6)
	var w_acc := WeaponDB.accuracy(weapon) if weapon != "" else 0.0
	var chance := _chance(acc, _stat(target, "agilita"), base, false, w_acc)
	if rng.randf() > chance:
		ev.append(_ev("%s: colpo mancato!" % String(target["name"]), idx, -1, "miss"))
		return ev

	var range_d: Array = WeaponDB.damage(weapon) if weapon != "" else Dictionary(CombatDB.cfg("punch", {})).get("dmg", [2, 5])
	var bonus := int(float(PlayerState.get_stat("forza")) / 2.0) if melee else int(float(PlayerState.get_stat("mira")) / 3.0)
	var dmg := rng.randi_range(int(range_d[0]), int(range_d[1])) + bonus
	var crit_p := CombatDB.num("crit_chance", 0.1) + (WeaponDB.crit_bonus(weapon) if weapon != "" else 0.0)
	var crit := rng.randf() < crit_p
	if crit:
		dmg = int(float(dmg) * CombatDB.num("crit_mult", 1.5))
	dmg = maxi(1, dmg - int(float(_stat(target, "resistenza")) / CombatDB.num("resist_divisor", 3.0)))
	target["hp"] = maxi(0, int(target["hp"]) - dmg)

	var text := (WeaponDB.hit_text(weapon) if weapon != "" else "Colpisci con un pugno") + (" (colpo critico!)" if crit else "")
	text += ": %s perde %d." % [String(target["name"]), dmg]
	ev.append(_ev(text, idx, int(target["hp"]), "hit"))
	if int(target["hp"]) <= 0:
		ev.append(_ev("%s cade a terra." % String(target["name"]), idx, 0, "down"))
	return ev


func _enemies_turn() -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	for e in enemies:
		if int(e["hp"]) <= 0:
			continue
		var atk: Dictionary = e["attack"]
		var melee := String(atk.get("kind", "ranged")) == "melee"
		var acc := _stat(e, "forza" if melee else "mira")
		var base := CombatDB.num("hit_base_melee" if melee else "hit_base_ranged", 0.6)
		var chance := _chance(acc, PlayerState.get_stat("agilita"), base, player_cover)
		var label := String(atk.get("label", "attacca"))
		if rng.randf() > chance:
			ev.append(_ev("%s %s ma ti manca." % [String(e["name"]), label], "player", -1, "miss"))
			continue
		var d: Array = atk.get("dmg", [3, 6])
		var red := int(float(PlayerState.get_stat("resistenza")) / CombatDB.num("resist_divisor", 3.0))
		var dmg := maxi(1, rng.randi_range(int(d[0]), int(d[1])) - red)
		player_hp = maxi(0, player_hp - dmg)
		ev.append(_ev("%s %s e ti colpisce: -%d." % [String(e["name"]), label, dmg], "player", player_hp, "hit"))
		var wound := WoundSystem.try_wound(dmg, rng)
		if not wound.is_empty():
			var pen := WoundSystem.penalty_text(wound)
			ev.append(_ev("%s!%s" % [WoundSystem.wound_name(wound), (" (%s)" % pen) if pen != "" else ""], "player", -1, "wound"))
		if player_hp <= 0:
			state = "lost"
			ev.append(_ev("Crolli a terra...", "", -1, "info"))
			break
	player_cover = false
	return ev


func _win(ev: Array[Dictionary]) -> void:
	state = "won"
	for e in enemies:
		var l: Array = e["loot"]
		loot += rng.randi_range(int(l[0]), int(l[1]))
		var wd: Dictionary = e["weapon_drop"]
		if not wd.is_empty() and rng.randf() < float(wd.get("chance", 0.0)):
			var wid := WeaponDB.pick_from(Array(wd.get("pool", [])), rng)
			if wid != "":
				weapon_drops.append(wid)
		var r: Dictionary = e["rep"]
		if not r.is_empty():
			var g := String(r.get("group", ""))
			rep_gains[g] = int(rep_gains.get(g, 0)) + int(r.get("value", 0))
	ev.append(_ev("Hai sconfitto tutti i nemici!", "", -1, "info"))
