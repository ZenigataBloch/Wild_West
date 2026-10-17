class_name NPCRoutine
extends Node
## Routine di un singolo cittadino (componente figlio di NPCAvatar).
## Attività: work (resta al suo posto), wander (passeggia), gather (chiacchiera
## davanti al saloon), saloon (entra e resta dentro), errand (commissione in un
## edificio, poi torna al posto), home (va a casa ed entra).
## Cammina lungo la "corsia" della strada per non attraversare i lotti.
## Mantiene aggiornati nel dizionario dell'NPC: position, post, home, slot,
## activity, inside ("" oppure id dell'edificio / "home").

enum State { IDLE, WALKING, INSIDE }

var state: State = State.IDLE
var avatar: NPCAvatar
var npc: Dictionary
var ctx: Dictionary   # buildings, street_y, x_min, x_max

var _rng: RandomNumberGenerator
var _lane_y := 0.0
var _speed := 55.0
var _pos := Vector2.ZERO
var _post := Vector2.ZERO
var _home := Vector2.ZERO
var _path: Array[Vector2] = []
var _enter_id := ""
var _dwell := 0.0
var _return_to_post := false
var _idle_t := 0.0
var _idle_next := 3.0


func setup(a: NPCAvatar, data: Dictionary, context: Dictionary) -> void:
	avatar = a
	npc = data
	ctx = context
	_rng = WorldSeed.rng_for("routine_%s" % npc["id"])
	var sp: Array = NPCRoutineDB.data().get("walk_speed", [45, 70])
	_speed = _rng.randf_range(float(sp[0]), float(sp[1]))
	_lane_y = float(ctx["street_y"]) + _rng.randf_range(-14.0, 14.0)
	_post = npc["position"]
	_pos = _post
	var side := -1.0 if _rng.randf() < 0.5 else 1.0
	_home = Vector2(_rng.randf_range(float(ctx["x_min"]), float(ctx["x_max"])), _lane_y + side * _rng.randf_range(30.0, 50.0))
	npc["post"] = _post
	npc["home"] = _home
	npc["inside"] = ""
	npc["activity"] = "work"
	_idle_next = _next_idle_delay()


## Chiamato dallo scheduler a ogni cambio di fascia oraria.
## snap = true: l'NPC compare subito nella destinazione (avvio partita, salto di tempo).
func set_slot(slot_id: String, snap: bool) -> void:
	npc["slot"] = slot_id
	var activity := NPCRoutineDB.pick_activity(slot_id, String(npc["job"]), _rng)
	_apply(activity, snap)


func _apply(activity: String, snap: bool) -> void:
	var target := _post
	var enter := ""
	var dwell := 0.0
	var back := false

	match activity:
		"wander":
			target = Vector2(_rng.randf_range(float(ctx["x_min"]), float(ctx["x_max"])), _lane_y)
		"gather":
			var b := _building("saloon")
			if b.is_empty():
				activity = "work"
			else:
				var side := -1.0 if _rng.randf() < 0.5 else 1.0
				var e: Vector2 = b["entrance"]
				target = e + Vector2(side * _rng.randf_range(60.0, 160.0), 40.0 if b.get("door_on_bottom", true) else -40.0)
		"saloon":
			var b := _building("saloon")
			if b.is_empty():
				activity = "work"
			else:
				target = b["entrance"]
				enter = "saloon"
		"errand":
			var id := _pick_errand_building()
			if id == "" or snap:
				activity = "work"
			else:
				target = _building(id)["entrance"]
				enter = id
				var dr: Array = NPCRoutineDB.data().get("errand_dwell", [4, 9])
				dwell = _rng.randf_range(float(dr[0]), float(dr[1]))
				back = true
		"home":
			target = _home
			enter = "home"
		_:
			activity = "work"

	npc["activity"] = activity
	if state == State.INSIDE:
		_exit_building()
	_enter_id = enter
	_dwell = dwell
	_return_to_post = back
	_idle_t = 0.0
	_idle_next = _next_idle_delay()

	if snap:
		_pos = target
		_sync()
		_arrive()
	else:
		_start_walk(target)


func _building(id: String) -> Dictionary:
	for b in ctx["buildings"]:
		if b.get("id", "") == id:
			return b
	return {}


func _pick_errand_building() -> String:
	var targets: Array = NPCRoutineDB.data().get("errand_targets", [])
	var valid: Array[String] = []
	for t in targets:
		if not _building(String(t)).is_empty() and String(t) != String(npc["workplace"]):
			valid.append(String(t))
	if valid.is_empty():
		return ""
	return valid[_rng.randi_range(0, valid.size() - 1)]


func _start_walk(target: Vector2) -> void:
	var pts: Array[Vector2] = []
	if absf(_pos.y - _lane_y) > 12.0:
		pts.append(Vector2(_pos.x, _lane_y))
	if absf(target.y - _lane_y) > 12.0:
		pts.append(Vector2(target.x, _lane_y))
	pts.append(target)
	_path = pts
	state = State.WALKING
	avatar.set_walking(true)


func _process(delta: float) -> void:
	match state:
		State.WALKING:
			if _path.is_empty():
				_arrive()
				return
			var to := _path[0] - _pos
			var step := _speed * delta
			if to.length() <= step:
				_pos = _path[0]
				_path.remove_at(0)
			else:
				_pos += to.normalized() * step
				avatar.set_facing(to.x)
			_sync()
			if _path.is_empty():
				_arrive()
		State.IDLE:
			_idle_tick(delta)
		State.INSIDE:
			if _dwell > 0.0:
				_dwell -= delta
				if _dwell <= 0.0:
					_finish_errand()


func _sync() -> void:
	avatar.position = _pos
	npc["position"] = _pos


func _arrive() -> void:
	avatar.set_walking(false)
	if _enter_id != "":
		state = State.INSIDE
		avatar.set_indoors(true)
		npc["inside"] = _enter_id
	else:
		state = State.IDLE


func _exit_building() -> void:
	state = State.IDLE
	avatar.set_indoors(false)
	npc["inside"] = ""


func _finish_errand() -> void:
	_exit_building()
	_enter_id = ""
	_dwell = 0.0
	if _return_to_post:
		_return_to_post = false
		npc["activity"] = "work"
		_start_walk(_post)


# ---------------------------------------------------------- movimenti da fermo
# Mentre lavora o chiacchiera, l'NPC non resta una statua: ogni tanto fa pochi passi
# lungo la strada intorno al suo posto (parametri in npc_routines.json -> "idle_stroll").

func _idle_cfg() -> Dictionary:
	return NPCRoutineDB.data().get("idle_stroll", {})


func _next_idle_delay() -> float:
	var iv: Array = _idle_cfg().get("interval", [4.0, 10.0])
	return _rng.randf_range(float(iv[0]), float(iv[1]))


func _idle_tick(delta: float) -> void:
	if not bool(_idle_cfg().get("enabled", true)):
		return
	var act := String(npc.get("activity", "work"))
	if act != "work" and act != "gather":
		return
	_idle_t += delta
	if _idle_t < _idle_next:
		return
	_idle_t = 0.0
	_idle_next = _next_idle_delay()
	var rr: Array = _idle_cfg().get("radius", [20.0, 60.0])
	var base: Vector2 = _post if act == "work" else _pos
	var dx := _rng.randf_range(float(rr[0]), float(rr[1])) * (-1.0 if _rng.randf() < 0.5 else 1.0)
	var tx := clampf(base.x + dx, float(ctx["x_min"]), float(ctx["x_max"]))
	var pts: Array[Vector2] = [Vector2(tx, _post.y if act == "work" else _pos.y)]
	_path = pts
	state = State.WALKING
	avatar.set_walking(true)
