class_name BuildingEntrance
extends Area2D
## Zona davanti alla porta. Quando il giocatore è dentro mostra "[E] Entra"
## ed emette `interacted` alla pressione di E (azione "interact" se esiste).
## Stesso contratto di interactable.gd (suggerimento + segnale interacted):
## se vuoi usare direttamente quel componente, basta sostituire questo nodo.

signal interacted(building_id: String)

@export var player_group: StringName = &"player"

var building_id := ""
var def: Dictionary = {}
var _inside := false
var _label: Label


func setup(id: String, building_def: Dictionary, door_on_bottom: bool) -> void:
	building_id = id
	def = building_def
	collision_layer = 0
	collision_mask = 0xFFFFFFFF
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(96, 72)
	shape.shape = rect
	add_child(shape)

	_label = Label.new()
	WesternTheme.apply(_label)
	_label.add_theme_stylebox_override("normal", WesternTheme.box(WesternTheme.color("wood_dark"), WesternTheme.color("gold_dark"), 2, 4, 6))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.custom_minimum_size = Vector2(190, 0)
	_label.position = Vector2(-95, 44 if door_on_bottom else -80)
	_label.z_index = 10
	_label.visible = false
	add_child(_label)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _is_player(body: Node) -> bool:
	return body.is_in_group(player_group) or body.name.to_lower().contains("player")


func _on_body_entered(body: Node) -> void:
	if not _is_player(body):
		return
	_inside = true
	_refresh_label()
	_label.visible = true


func _on_body_exited(body: Node) -> void:
	if not _is_player(body):
		return
	_inside = false
	_label.visible = false


func _refresh_label() -> void:
	var name_text := String(def.get("name", building_id))
	if BuildingActions.is_open(def):
		_label.text = "[E] Entra — %s" % name_text
	else:
		_label.text = "%s — Chiuso (apre alle %s)" % [name_text, BuildingActions.opening_text(def)]


func _unhandled_input(event: InputEvent) -> void:
	if not _inside:
		return
	var pressed := false
	if InputMap.has_action("interact"):
		pressed = event.is_action_pressed("interact")
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo and event.keycode == KEY_E
	if pressed:
		get_viewport().set_input_as_handled()
		interacted.emit(building_id)
