class_name JobManager
extends Node
## Apre il pannello dei lavori con **L** (pausa mentre è aperto) e lancia gli scontri
## che un turno può provocare (cacciatore: predatori, mercenario: imboscate).
## Creato da world.gd come gli altri manager: setup(avatar, origin, combat_manager).

signal message(text: String)

var _avatar: Node2D
var _origin: Vector2 = Vector2.ZERO
var _combat: Node
var _layer: CanvasLayer
var _panel: JobPanel
var _open: bool = false


func setup(avatar: Node2D, origin: Vector2, combat: Node = null) -> void:
	_avatar = avatar
	_origin = origin
	_combat = combat
	JobState.reset()
	JobSites.reset()


## Registra i luoghi di lavoro: ingressi degli edifici e la miniera fuori città (posizione dal seed).
## Da chiamare dopo BuildingManager.spawn: world.gd passa gli edifici, i limiti dell'area di gioco
## e i rettangoli da evitare (strada e lotti: la città è lunga fino a 2600 px).
func set_world(buildings: Array, bounds: Rect2, avoid: Array[Rect2] = []) -> void:
	JobSites.reset()
	for b in buildings:
		JobSites.set_point("building", str(b.get("id", "")), b["entrance"])
	var cfg: Dictionary = JobDB.data().get("site", {})
	var dist: Array = cfg.get("distance", [720, 1000])
	var rng := WorldSeed.rng_for("job_site")
	var area := bounds.grow(-120.0)
	var pt := _origin + Vector2(0.0, float(dist[0]))   # ripiego: sotto la città
	for i in 120:
		var a := rng.randf_range(0.0, TAU)
		var cand := _origin + Vector2(cos(a), sin(a)) * rng.randf_range(float(dist[0]), float(dist[1]))
		if not area.has_point(cand):
			continue
		var bad := false
		for r in avoid:
			if r.grow(150.0).has_point(cand):
				bad = true
				break
		if not bad:
			pt = cand
			break
	JobSites.set_point("site", str(cfg.get("id", "miniera")), pt)
	var m := JobSiteMarker.new()
	m.position = pt
	add_child(m)


func is_open() -> bool:
	return _open


func _exit_tree() -> void:
	if _open and is_inside_tree():
		get_tree().paused = false
	_open = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_L:
		if not _open and not get_tree().paused:
			_open_panel()
			get_viewport().set_input_as_handled()


func _open_panel() -> void:
	_open = true
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 55
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_panel = JobPanel.new()
	_panel.setup(_avatar, _origin)
	_panel.closed.connect(_on_closed)
	_panel.message.connect(func(t: String): message.emit(t))
	_layer.add_child(_panel)


func _on_closed(pending_combat: Dictionary) -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_panel = null
	_open = false
	get_tree().paused = false
	if not pending_combat.is_empty():
		_start_combat.call_deferred(pending_combat)


func _start_combat(info: Dictionary) -> void:
	if _combat == null or not is_instance_valid(_combat) or not _combat.has_method("start_encounter"):
		return
	_combat.start_encounter(info.get("enemies", []), str(info.get("title", "Scontro")), false)
