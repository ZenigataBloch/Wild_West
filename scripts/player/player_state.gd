extends Node
## Stato del giocatore: nome, salute, soldi, statistiche, inventario.
## Tutta la logica è qui; la UI si limita ad ascoltare i segnali.

signal name_changed(new_name: String)
signal health_changed(current: int, maximum: int)
signal money_changed(amount: int)
signal stats_changed
signal inventory_changed
signal item_used(item_id: String)
signal player_died

const CONFIG_PATH := "res://data/player_config.json"

var player_name: String = ""
var health: int = 100
var max_health: int = 100
var money: int = 0
var stat_max: int = 10
var stats: Dictionary = {}       # id -> valore
var inventory: Array = []        # [{ "id": String, "qty": int }]

var _cfg: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		push_error("player_config.json non trovato")
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_cfg = data

## Crea un nuovo personaggio. Nome e statistiche dipendono dal seed del mondo.
func new_character(forced_name: String = "") -> void:
	var rng := WorldSeed.rng_for("player")
	var names: Array = _cfg.get("names", ["Straniero"])
	player_name = forced_name if forced_name != "" else names[rng.randi() % names.size()]
	max_health = int(_cfg.get("max_health", 100))
	health = max_health
	money = int(_cfg.get("start_money", 0))
	stat_max = int(_cfg.get("stat_max", 10))
	_roll_stats(rng)
	inventory.clear()
	for entry in _cfg.get("start_items", []):
		add_item(String(entry["id"]), int(entry["qty"]))
	name_changed.emit(player_name)
	health_changed.emit(health, max_health)
	money_changed.emit(money)
	stats_changed.emit()
	inventory_changed.emit()

func _roll_stats(rng: RandomNumberGenerator) -> void:
	stats.clear()
	var defs: Dictionary = _cfg.get("stats", {})
	for key in defs:
		stats[key] = int(defs[key]["base"])
	var keys := defs.keys()
	var points := int(_cfg.get("stat_random_points", 5))
	var guard := 0
	while points > 0 and guard < 1000 and keys.size() > 0:
		guard += 1
		var k = keys[rng.randi() % keys.size()]
		if stats[k] < stat_max:
			stats[k] += 1
			points -= 1

func get_stat(id: String) -> int:
	return int(stats.get(id, 0))

func get_stat_label(id: String) -> String:
	return String(_cfg.get("stats", {}).get(id, {}).get("label", id))

func get_movement() -> Dictionary:
	return _cfg.get("movement", {})

func get_slot_limit() -> int:
	return int(_cfg.get("inventory_slots", 12))

# --- Salute ---

func damage(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = maxi(0, health - amount)
	health_changed.emit(health, max_health)
	if health == 0:
		player_died.emit()

func heal(amount: int) -> void:
	if amount <= 0 or health <= 0:
		return
	health = mini(max_health, health + amount)
	health_changed.emit(health, max_health)

# --- Soldi ---

func add_money(amount: int) -> void:
	if amount <= 0:
		return
	money += amount
	money_changed.emit(money)

func spend_money(amount: int) -> bool:
	if amount <= 0 or money < amount:
		return false
	money -= amount
	money_changed.emit(money)
	return true

# --- Inventario ---

## Aggiunge oggetti. Restituisce la quantità che non è entrata (zaino pieno).
func add_item(id: String, qty: int = 1) -> int:
	var def := ItemDB.get_item(id)
	if def.is_empty() or qty <= 0:
		return qty
	var max_stack := int(def.get("max_stack", 1)) if def.get("stackable", false) else 1
	for slot in inventory:
		if qty <= 0:
			break
		if slot["id"] == id and slot["qty"] < max_stack:
			var room: int = max_stack - int(slot["qty"])
			var put: int = mini(qty, room)
			slot["qty"] += put
			qty -= put
	while qty > 0 and inventory.size() < get_slot_limit():
		var put2: int = mini(qty, max_stack)
		inventory.append({ "id": id, "qty": put2 })
		qty -= put2
	inventory_changed.emit()
	return qty

func count_item(id: String) -> int:
	var total := 0
	for slot in inventory:
		if slot["id"] == id:
			total += int(slot["qty"])
	return total

func has_item(id: String, qty: int = 1) -> bool:
	return count_item(id) >= qty

func remove_item(id: String, qty: int = 1) -> bool:
	if qty <= 0 or count_item(id) < qty:
		return false
	var i := inventory.size() - 1
	while i >= 0 and qty > 0:
		if inventory[i]["id"] == id:
			var take: int = mini(qty, int(inventory[i]["qty"]))
			inventory[i]["qty"] -= take
			qty -= take
			if inventory[i]["qty"] <= 0:
				inventory.remove_at(i)
		i -= 1
	inventory_changed.emit()
	return true

## Usa un oggetto curativo. Non lo consuma se la salute è già piena.
func use_item(id: String) -> bool:
	var def := ItemDB.get_item(id)
	if def.is_empty() or not def.has("heal") or count_item(id) <= 0:
		return false
	if health >= max_health or health <= 0:
		return false
	remove_item(id, 1)
	heal(int(def["heal"]))
	item_used.emit(id)
	return true

## Per i futuri salvataggi.
func to_dict() -> Dictionary:
	return {
		"name": player_name,
		"health": health,
		"max_health": max_health,
		"money": money,
		"stats": stats.duplicate(),
		"inventory": inventory.duplicate(true)
	}
