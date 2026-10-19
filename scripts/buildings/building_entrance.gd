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
var _player: Node2D = null
var _door_on_bottom := false


func setup(id: String, building_def: Dictionary, door_on_bottom: bool) -> void:
	building_id = id
	_door_on_bottom = door_on_bottom
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
	_label.position = Vector2(-95, -68 if door_on_bottom else 30)  # sempre sopra il corpo dell'edificio, mai sulla strada
	_label.z_as_relative = false
	_label.z_index = 100
	_label.visible = false
	add_child(_label)
	set_physics_process(false)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _is_player(body: Node) -> bool:
	return body.is_in_group(player_group) or body.name.to_lower().contains("player")


func _on_body_entered(body: Node) -> void:
	if not _is_player(body):
		return
	_inside = true
	add_to_group(&"interact_cand")
	_refresh_label()
	set_physics_process(true)
	_update_focus()


func _on_body_exited(body: Node) -> void:
	if not _is_player(body):
		return
	_inside = false
	remove_from_group(&"interact_cand")
	set_physics_process(false)
	_label.visible = false


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() % 6 == 0:
		_update_focus()


func _update_focus() -> void:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group) as Node2D
	var focus := true
	if _player != null:
		var mine := global_position.distance_squared_to(_player.global_position)
		for n in get_tree().get_nodes_in_group(&"interact_cand"):
			if n == self:
				continue
			var d := (n as Node2D).global_position.distance_squared_to(_player.global_position)
			if d < mine or (is_equal_approx(d, mine) and n.get_instance_id() < get_instance_id()):
				focus = false
				break
	_label.visible = _inside and focus


func _refresh_label() -> void:
	var name_text := String(def.get("name", building_id))
	if BuildingActions.is_open(def):
		_label.text = "[E] Entra — %s" % name_text
	else:
		_label.text = "%s — Chiuso (apre alle %s)" % [name_text, BuildingActions.opening_text(def)]
	# La targa si allarga col testo: la ricentro sopra la porta
	_label.reset_size()
	_label.position.x = -_label.size.x * 0.5
	if _door_on_bottom:
		_label.position.y = -22.0 - 8.0 - _label.size.y


func _unhandled_input(event: InputEvent) -> void:
	if not _inside or not _label.visible:
		return
	var pressed := false
	if InputMap.has_action("interact"):
		pressed = event.is_action_pressed("interact")
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo and event.keycode == KEY_E
	if pressed:
		get_viewport().set_input_as_handled()
		interacted.emit(building_id)
