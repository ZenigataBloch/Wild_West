class_name BuildingManager
extends Node2D
## Piazza gli edifici sui lotti della città.
## Uso:   $BuildingManager.street_y = <y della strada principale>
##        $BuildingManager.spawn(lotti)
## `lotti` è un Array di Rect2 oppure di Dictionary con "rect", oppure con
## x/y/w/h, oppure con position/size (Vector2, array o dizionario x/y).
## L'assegnazione tipo->lotto dipende dal seed (canale "buildings").

signal building_entered(building_id: String)

@export var street_y: float = 0.0
@export var pause_game_while_open: bool = true

## Dati finali: {id, name, rect, entrance(Vector2), door_on_bottom}
var buildings: Array[Dictionary] = []

var _layer: CanvasLayer
var _panel: BuildingPanel


func spawn(lots: Array) -> void:
	_clear()
	var rects: Array[Rect2] = []
	for l in lots:
		var r := _to_rect(l)
		if r.size.x > 0.0 and r.size.y > 0.0:
			rects.append(r)

	var rng: RandomNumberGenerator = WorldSeed.rng_for("buildings")
	for i in range(rects.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := rects[i]
		rects[i] = rects[j]
		rects[j] = tmp

	var layout := BuildingDB.layout()
	for i in mini(layout.size(), rects.size()):
		_create(String(layout[i]), rects[i])
	_setup_ui()


func _create(id: String, rect: Rect2) -> void:
	var def := BuildingDB.get_type(id)
	if def.is_empty():
		return
	var door_on_bottom := rect.get_center().y < street_y

	var facade := BuildingFacade.new()
	add_child(facade)
	facade.setup(rect, def, door_on_bottom)

	var edge_y := rect.end.y if door_on_bottom else rect.position.y
	var entrance := BuildingEntrance.new()
	entrance.position = Vector2(rect.get_center().x, edge_y + (22.0 if door_on_bottom else -22.0))
	add_child(entrance)
	entrance.setup(id, def, door_on_bottom)
	entrance.interacted.connect(_on_interacted)

	buildings.append({
		"id": id,
		"name": String(def.get("name", id)),
		"rect": rect,
		"entrance": entrance.position,
		"door_on_bottom": door_on_bottom,
	})


func _setup_ui() -> void:
	if _layer:
		return
	_layer = CanvasLayer.new()
	_layer.layer = 20
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	_panel = BuildingPanel.new()
	_panel.title = " "   # riserva lo spazio del banner; il nome vero arriva da setup()
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	_layer.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.exit_requested.connect(func(): _panel.close())
	_panel.closed.connect(_on_panel_closed)


func _on_interacted(id: String) -> void:
	if _panel == null or _panel.visible:
		return
	_panel.setup(id, BuildingDB.get_type(id))
	_panel.open()
	if pause_game_while_open:
		get_tree().paused = true
	building_entered.emit(id)


func _on_panel_closed() -> void:
	if pause_game_while_open:
		get_tree().paused = false


func _clear() -> void:
	for c in get_children():
		c.queue_free()
	buildings.clear()
	_layer = null
	_panel = null


func _to_rect(l) -> Rect2:
	if l is Rect2:
		return l
	if l is Dictionary:
		if l.has("rect") and l["rect"] is Rect2:
			return l["rect"]
		if l.has("position") and l.has("size"):
			return Rect2(_to_v2(l["position"]), _to_v2(l["size"]))
		if l.has("x") and l.has("y") and l.has("w") and l.has("h"):
			return Rect2(float(l["x"]), float(l["y"]), float(l["w"]), float(l["h"]))
	return Rect2()


func _to_v2(v) -> Vector2:
	if v is Vector2:
		return v
	if v is Array and v.size() >= 2:
		return Vector2(float(v[0]), float(v[1]))
	if v is Dictionary:
		return Vector2(float(v.get("x", 0)), float(v.get("y", 0)))
	return Vector2.ZERO
