extends Node
## Database oggetti, caricato da data/items.json.
## Le feature future (armi, negozi, bottino) aggiungeranno qui nuovi oggetti solo via JSON.

const PATH := "res://data/items.json"

var _items: Dictionary = {}

func _ready() -> void:
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		push_error("items.json non trovato")
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Dictionary:
		_items = data

func get_item(id: String) -> Dictionary:
	if _items.has(id):
		return _items[id]
	# Le armi (data/weapons.json) sono oggetti dello zaino.
	if WeaponDB.is_weapon(id):
		return WeaponDB.item_def(id)
	return {}

func has_item(id: String) -> bool:
	return _items.has(id) or WeaponDB.is_weapon(id)
