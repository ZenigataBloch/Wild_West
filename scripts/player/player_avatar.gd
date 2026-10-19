extends CharacterBody2D
## Il giocatore nel mondo: movimento (WASD / frecce, Shift = corsa), telecamera che lo segue
## (rotella = zoom) e interazione con i punti interattivi (E).
## La velocità dipende dalla statistica Agilità. Parametri in data/player_config.json.

signal prompt_changed(text: String)

const RADIUS := 14.0
const ZOOM_MIN := 0.6
const ZOOM_MAX := 1.6

var input_enabled: bool = true
var facing: Vector2 = Vector2.DOWN

var _bounds: Rect2 = Rect2()
var _camera: Camera2D
var _target: Interactable = null
var _target_tick: int = 0
var _cs: CharacterSprite = null

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	z_index = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = true
	_camera.position_smoothing_speed = 8.0
	add_child(_camera)
	_cs = CharacterSprite.new()
	if _cs.setup(CharacterSprite.player_colors()):
		add_child(_cs)
	else:
		_cs.free()
		_cs = null

## Posiziona il giocatore e imposta i limiti dell'area esplorabile.
func setup(bounds: Rect2, spawn: Vector2) -> void:
	_bounds = bounds
	global_position = spawn
	velocity = Vector2.ZERO
	_camera.limit_left = int(bounds.position.x)
	_camera.limit_top = int(bounds.position.y)
	_camera.limit_right = int(bounds.end.x)
	_camera.limit_bottom = int(bounds.end.y)
	_camera.reset_smoothing()
	_target = null
	prompt_changed.emit("")

func _physics_process(_delta: float) -> void:
	var dir := Vector2.ZERO
	var active := input_enabled and PlayerState.health > 0
	if active:
		dir.x = _axis(KEY_D, KEY_RIGHT) - _axis(KEY_A, KEY_LEFT)
		dir.y = _axis(KEY_S, KEY_DOWN) - _axis(KEY_W, KEY_UP)
	dir = dir.normalized()

	var mv := PlayerState.get_movement()
	var speed := float(mv.get("walk_speed", 180.0)) \
		+ PlayerState.get_stat("agilita") * float(mv.get("agility_bonus", 8.0))
	if active and dir != Vector2.ZERO and Input.is_physical_key_pressed(KEY_SHIFT):
		speed *= float(mv.get("run_multiplier", 1.7))

	velocity = dir * speed
	if dir != Vector2.ZERO and dir != facing:
		facing = dir
		queue_redraw()   # l'aspetto dipende solo dalla direzione: si ridisegna solo quando cambia
	move_and_slide()
	if _cs != null:
		_cs.face(facing, dir != Vector2.ZERO)
	if _bounds.size != Vector2.ZERO:
		global_position = global_position.clamp(
			_bounds.position + Vector2(RADIUS, RADIUS),
			_bounds.end - Vector2(RADIUS, RADIUS))
	# La ricerca del punto interattivo più vicino non serve a ogni fotogramma: ogni 3, subito se non attivo.
	_target_tick += 1
	if not active or _target_tick % 3 == 0:
		_update_target(active)

func _axis(a: Key, b: Key) -> float:
	return 1.0 if (Input.is_physical_key_pressed(a) or Input.is_physical_key_pressed(b)) else 0.0

func _update_target(active: bool) -> void:
	var best: Interactable = null
	var best_d := INF
	if active:
		for n in get_tree().get_nodes_in_group("interactable"):
			var it := n as Interactable
			if it == null:
				continue
			var d := global_position.distance_squared_to(it.global_position)
			if d <= it.radius * it.radius and d < best_d:
				best = it
				best_d = d
	if best != _target:
		_target = best
		prompt_changed.emit("" if _target == null else "[E] " + _target.prompt)

func _unhandled_key_input(e: InputEvent) -> void:
	if e.pressed and not e.echo and e.keycode == KEY_E:
		if input_enabled and is_instance_valid(_target):
			_target.interact()

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		if e.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_camera.zoom.x + 0.1)
		elif e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_camera.zoom.x - 0.1)

func _set_zoom(z: float) -> void:
	z = clampf(z, ZOOM_MIN, ZOOM_MAX)
	_camera.zoom = Vector2(z, z)

# Aspetto del giocatore (disegnato da codice, sostituibile con sprite).
func _draw() -> void:
	if _cs != null:
		return
	# ombra a terra
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 15.0, Color(0, 0, 0, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# corpo con poncho, cintura e fibbia
	draw_circle(Vector2.ZERO, RADIUS, Color("#4a6fa5"))
	draw_arc(Vector2.ZERO, RADIUS, 0.0, TAU, 24, Color("#1f2f4a"), 2.0)
	draw_arc(Vector2.ZERO, RADIUS - 5.0, 0.25, PI - 0.25, 12, Color("#5b3a1e"), 3.0)
	draw_circle(Vector2(0, RADIUS - 5.0), 2.0, Color("#d4a53a"))
	# viso rivolto nella direzione di marcia
	draw_circle(facing * (RADIUS - 4.0), 4.0, Color("#e8c9a0"))
	# cappello: tesa, calotta e fascia dorata
	draw_rect(Rect2(-14, -RADIUS - 2, 28, 5), Color("#5b3a1e"))
	draw_rect(Rect2(-7, -RADIUS - 11, 14, 10), Color("#6b4527"))
	draw_rect(Rect2(-7, -RADIUS - 4, 14, 3), Color("#d4a53a"))
