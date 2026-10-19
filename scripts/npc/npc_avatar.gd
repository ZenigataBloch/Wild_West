class_name NPCAvatar
extends Area2D
## Cittadino nel mondo: figura vista dall'alto disegnata da codice,
## nome sopra la testa e "[E] Parla con ..." quando il giocatore è vicino.
## Si muove tramite il componente NPCRoutine (routine e piccoli passi da fermo).

signal talk_requested(npc_id: String)

@export var player_group: StringName = &"player"

const NAME_SHOW_DIST := 260.0

var npc: Dictionary = {}

var _inside := false
var _name_tag: Label
var _prompt: Label
var _indoors := false
var _walking := false
var _walk_t := 0.0
var _facing := 1.0
var _focus_tick := 0
var _cs: CharacterSprite = null
var _player: Node2D = null


func setup(data: Dictionary) -> void:
	npc = data
	position = data["position"]
	collision_layer = 0
	collision_mask = 0xFFFFFFFF

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 44.0
	shape.shape = circle
	add_child(shape)

	_name_tag = Label.new()
	WesternTheme.apply(_name_tag)
	_name_tag.text = String(data["name"])
	_name_tag.add_theme_font_size_override("font_size", 13)
	_name_tag.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_name_tag.add_theme_constant_override("outline_size", 4)
	_name_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_tag.custom_minimum_size = Vector2(160, 0)
	_name_tag.position = Vector2(-80, -42)
	_cs = CharacterSprite.new()
	if _cs.setup(CharacterSprite.colors_for(data)):
		add_child(_cs)
		_name_tag.position = Vector2(-80, -60)
	else:
		_cs.free()
		_cs = null
	_name_tag.z_index = 8
	add_child(_name_tag)

	_prompt = Label.new()
	WesternTheme.apply(_prompt)
	_prompt.add_theme_stylebox_override("normal", WesternTheme.box(WesternTheme.color("wood_dark"), WesternTheme.color("gold_dark"), 2, 4, 6))
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.text = "[E] Parla con %s" % String(data["name"]).split(" ")[0]
	_prompt.custom_minimum_size = Vector2(170, 0)
	_prompt.position = Vector2(-85, 22)
	_prompt.z_as_relative = false
	_prompt.z_index = 100
	_prompt.visible = false
	add_child(_prompt)

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	z_index = 2
	queue_redraw()


func _draw() -> void:
	if npc.is_empty() or _cs != null:
		return
	var shirt := Color(npc["shirt"])
	var skin := Color(npc["skin"])
	var hat := Color(npc["hat"])
	var edge := Color(0, 0, 0, 0.55)

	# Ombra
	draw_set_transform(Vector2(0, 5), 0.0, Vector2(1.5, 0.9))
	draw_circle(Vector2.ZERO, 13.0, Color(0, 0, 0, 0.3))
	# Spalle
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.35, 0.95))
	draw_circle(Vector2.ZERO, 11.0, edge)
	draw_circle(Vector2.ZERO, 9.5, shirt)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Distintivo
	if npc.get("badge", false):
		draw_circle(Vector2(7.0 * _facing, 3), 2.6, WesternTheme.color("gold"))

	# Testa e cappello (ondeggiano mentre cammina)
	var bob := sin(_walk_t) * 1.6 if _walking else 0.0
	draw_set_transform(Vector2(0, bob), 0.0, Vector2.ONE)
	draw_circle(Vector2(0, -2), 7.5, skin)
	draw_circle(Vector2(0, -3), 12.0, edge)
	draw_circle(Vector2(0, -3), 11.0, hat.darkened(0.15))
	draw_circle(Vector2(0, -3), 6.5, hat)
	draw_arc(Vector2(0, -3), 6.5, 0, TAU, 20, hat.lightened(0.25), 1.2)


func _is_player(body: Node) -> bool:
	return body.is_in_group(player_group) or body.name.to_lower().contains("player")


func _on_body_entered(body: Node) -> void:
	if _is_player(body):
		_inside = true
		add_to_group(&"interact_cand")
		_update_focus()


func _on_body_exited(body: Node) -> void:
	if _is_player(body):
		_inside = false
		remove_from_group(&"interact_cand")
		_prompt.visible = false


# Ogni 6 fotogrammi fisici: il nome si vede solo se il giocatore è vicino e il suggerimento
# [E] compare solo sul candidato più vicino (NPC o ingresso), così le targhe non si sovrappongono.
func _physics_process(_delta: float) -> void:
	_focus_tick += 1
	if _focus_tick % 6 != 0 or _indoors:
		return
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group) as Node2D
	if _player == null:
		return
	_name_tag.visible = global_position.distance_to(_player.global_position) < NAME_SHOW_DIST
	if _inside:
		_update_focus()


func _has_focus() -> bool:
	if _player == null or not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group(player_group) as Node2D
	if _player == null:
		return true
	var mine := global_position.distance_squared_to(_player.global_position)
	for n in get_tree().get_nodes_in_group(&"interact_cand"):
		if n == self:
			continue
		var d := (n as Node2D).global_position.distance_squared_to(_player.global_position)
		if d < mine or (is_equal_approx(d, mine) and n.get_instance_id() < get_instance_id()):
			return false
	return true


func _update_focus() -> void:
	_prompt.visible = _inside and _has_focus()


func _unhandled_input(event: InputEvent) -> void:
	if not _inside or not _prompt.visible:
		return
	var pressed := false
	if InputMap.has_action("interact"):
		pressed = event.is_action_pressed("interact")
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo and event.keycode == KEY_E
	if pressed:
		get_viewport().set_input_as_handled()
		talk_requested.emit(String(npc["id"]))


## Dentro un edificio: invisibile e non interagibile.
func set_indoors(indoors: bool) -> void:
	_indoors = indoors
	visible = not indoors
	set_deferred("monitoring", not indoors)
	set_process_unhandled_input(not indoors)
	if indoors:
		_inside = false
		remove_from_group(&"interact_cand")
		_prompt.visible = false


func set_walking(walking: bool) -> void:
	_walking = walking
	if _cs != null:
		_cs.face(Vector2(_facing, 0.0) if walking else Vector2.DOWN, walking)
	set_process(walking)
	if not walking:
		_walk_t = 0.0
		queue_redraw()


func set_facing(dir_x: float) -> void:
	if absf(dir_x) < 0.1:
		return
	var f := 1.0 if dir_x > 0.0 else -1.0
	if f != _facing:
		_facing = f
		if _cs != null and _walking:
			_cs.face(Vector2(_facing, 0.0), true)
		queue_redraw()


func _process(delta: float) -> void:
	if _walking:
		_walk_t += delta * 10.0
		queue_redraw()
