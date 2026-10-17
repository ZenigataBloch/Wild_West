class_name WeaponDB
extends RefCounted
## Accesso ai dati delle armi (data/weapons.json): tipi, rarità e armi.
## Le armi sono anche oggetti dello zaino: ItemDB.get_item(id) ricade qui (item_def),
## quindi PlayerState.add_item / has_item funzionano senza modifiche.

const PATH := "res://data/weapons.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {"types": {}, "rarities": {}, "weapons": {}}
	return _data


static func ids() -> Array:
	return data().get("weapons", {}).keys()


static func is_weapon(id: String) -> bool:
	return data().get("weapons", {}).has(id)


static func weapon(id: String) -> Dictionary:
	return data().get("weapons", {}).get(id, {})


static func type_def(type_id: String) -> Dictionary:
	return data().get("types", {}).get(type_id, {})


static func rarity_def(rarity_id: String) -> Dictionary:
	return data().get("rarities", {}).get(rarity_id, {})


static func name_of(id: String) -> String:
	return String(weapon(id).get("name", id))


## Nome con articolo ("il Colt Navy"), per i testi di combattimento.
static func the_name(id: String) -> String:
	var w := weapon(id)
	return String(w.get("the", w.get("name", id)))


## "ranged" (arma da fuoco, usa la Mira) oppure "melee" (corpo a corpo, usa la Forza).
static func kind(id: String) -> String:
	return String(type_def(String(weapon(id).get("type", ""))).get("kind", "ranged"))


static func type_label(id: String) -> String:
	var t := String(weapon(id).get("type", ""))
	return String(type_def(t).get("label", t.capitalize()))


static func rarity_label(id: String) -> String:
	var r := String(weapon(id).get("rarity", "comune"))
	return String(rarity_def(r).get("label", r.capitalize()))


static func rarity_color(id: String) -> Color:
	var r := String(weapon(id).get("rarity", "comune"))
	return Color(String(rarity_def(r).get("color", "#b8b0a0")))


static func damage(id: String) -> Array:
	var d: Array = weapon(id).get("damage", [1, 3])
	return d if d.size() >= 2 else [1, 3]


static func accuracy(id: String) -> float:
	return float(weapon(id).get("accuracy", 0.0))


static func crit_bonus(id: String) -> float:
	return float(weapon(id).get("crit_bonus", 0.0))


static func price(id: String) -> int:
	return int(weapon(id).get("price", 0))


## Testo dell'evento di colpo a segno (es. "Fai fuoco con il Colt Navy e centri").
static func hit_text(id: String) -> String:
	var tpl := String(type_def(String(weapon(id).get("type", ""))).get("hit_text", "Colpisci con %s"))
	return tpl % the_name(id)


## Riga riassuntiva: "Pistola · Comune — danno 6-12, precisione +0%".
static func stats_text(id: String) -> String:
	var d := damage(id)
	var t := "%s · %s — danno %d-%d, precisione %+d%%" % [type_label(id), rarity_label(id), int(d[0]), int(d[1]), roundi(accuracy(id) * 100.0)]
	if crit_bonus(id) > 0.0:
		t += ", critico +%d%%" % roundi(crit_bonus(id) * 100.0)
	return t


## Definizione "oggetto" per ItemDB (non impilabile, occupa uno slot).
static func item_def(id: String) -> Dictionary:
	var w := weapon(id)
	if w.is_empty():
		return {}
	return {
		"name": String(w.get("name", id)),
		"type": "arma",
		"description": "%s\n%s" % [String(w.get("desc", "")), stats_text(id)],
		"value": int(w.get("price", 0)),
		"stackable": false,
		"max_stack": 1,
		"weapon": true,
		"rarity": String(w.get("rarity", "comune")),
	}


static func _weight(id: String) -> float:
	var r := String(weapon(id).get("rarity", "comune"))
	return maxf(0.0, float(rarity_def(r).get("weight", 10)))


## Sceglie un'arma da una lista di id, con probabilità proporzionale al peso della rarità.
static func pick_from(pool: Array, rng: RandomNumberGenerator) -> String:
	var valid: Array = []
	var total := 0.0
	for id in pool:
		var s := String(id)
		if is_weapon(s):
			valid.append(s)
			total += _weight(s)
	if valid.is_empty():
		return ""
	var roll := rng.randf() * total
	for id in valid:
		roll -= _weight(String(id))
		if roll <= 0.0:
			return String(id)
	return String(valid.back())


static func random_id(rng: RandomNumberGenerator) -> String:
	return pick_from(ids(), rng)
