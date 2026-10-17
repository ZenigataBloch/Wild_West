class_name PropertyManager
extends Node
## Gestisce i lotti liberi della città (Feature 18): grafica (PropertyLotView), punto di interazione [E] su
## ogni lotto, pannello di acquisto / gestione (PropertyPanel, gioco in pausa mentre è aperto) e lo scorrere
## dei giorni (tasse, lavori, incassi del negozio) anche dopo salti di tempo come dormire.
## Creato da world.gd dopo BuildingManager: setup(lotti, rettangoli degli edifici, y della strada).
## Il segnale message va collegato all'HUD come per gli altri manager.

signal message(text: String)

@export var pause_game_while_open: bool = true

var _views: Dictionary = {}   # id lotto -> PropertyLotView
var _spots: Dictionary = {}   # id lotto -> Interactable
var _panel: PropertyPanel
var _seen_version := -1


## `lot_list`: i lotti di TownGenerator (dizionari con id, side, rect). `used`: rettangoli già occupati dagli
## edifici della Feature 5; tutti gli altri lotti vanno in vendita.
func setup(lot_list: Array, used: Array[Rect2], street_y: float) -> void:
	for lot in lot_list:
		var d: Dictionary = lot
		var r: Array = d["rect"]
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		if used.has(rect):
			continue
		var id := int(d["id"])
		var side := String(d["side"])
		PropertySystem.register_lot(id, side, rect)

		var view := PropertyLotView.new()
		add_child(view)
		view.setup(id, rect, rect.get_center().y < street_y)
		_views[id] = view

		var spot := Interactable.new()
		spot.position = Vector2(rect.get_center().x, rect.end.y + 30.0 if side == "nord" else rect.position.y - 30.0)
		spot.interacted.connect(_on_spot.bind(id))
		add_child(spot)
		_spots[id] = spot
	_setup_ui()
	_refresh()


func _setup_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_panel = PropertyPanel.new()
	_panel.title = " "   # riserva lo spazio del banner; il titolo vero arriva da setup()
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	layer.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.exit_requested.connect(func(): _panel.close())
	_panel.closed.connect(_on_closed)


func _exit_tree() -> void:
	if _panel != null and is_instance_valid(_panel) and _panel.visible and is_inside_tree():
		get_tree().paused = false


func _on_spot(id: int) -> void:
	if _panel == null or _panel.visible or get_tree().paused:
		return
	_panel.setup(id)
	_panel.open()
	if pause_game_while_open:
		get_tree().paused = true


func _on_closed() -> void:
	if pause_game_while_open:
		get_tree().paused = false
	_refresh()


## Dal conto in banca (BankSystem) per le tasse: ritorna quanto è stato davvero prelevato.
func _pay_from_bank(amount: int) -> int:
	var n := mini(amount, BankSystem.balance)
	if n <= 0:
		return 0
	BankSystem.balance -= n
	return n


func _process(_delta: float) -> void:
	var day := int(GameTime.day)
	if day != PropertySystem.last_day:
		var msgs := PropertySystem.advance_to(day, _pay_from_bank)
		if not msgs.is_empty():
			message.emit("\n".join(msgs))
		_refresh()
	elif PropertySystem.version != _seen_version:
		_refresh()


func _refresh() -> void:
	_seen_version = PropertySystem.version
	for id in _views.keys():
		var view: PropertyLotView = _views[id]
		view.refresh()
		_update_prompt(int(id))


func _update_prompt(id: int) -> void:
	var spot: Interactable = _spots[id]
	match PropertySystem.state_of(id):
		"free":
			spot.prompt = "Lotto %d in vendita — da $%d" % [id, PropertySystem.land_price(id)]
		"terreno":
			spot.prompt = "Il tuo terreno (lotto %d)" % id
		"building":
			spot.prompt = "Il tuo cantiere (lotto %d)" % id
		"casa":
			spot.prompt = "La tua casa (lotto %d)" % id
		"negozio":
			spot.prompt = "Il tuo negozio (lotto %d)" % id
