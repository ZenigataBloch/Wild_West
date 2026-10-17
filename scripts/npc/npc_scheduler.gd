class_name NPCScheduler
extends Node
## Controlla l'ora di gioco (GameTime.hour) e, al cambio di fascia
## (notte / mattina / pomeriggio / sera), dice a ogni NPCRoutine cosa fare.
## Se il tempo salta in avanti (es. dormire), gli NPC compaiono subito
## nella nuova posizione invece di camminare.
## Se GameTime non espone `hour`, usa un'ora fissa (8:00).

signal slot_changed(slot_id: String)

var routines: Array[NPCRoutine] = []

var _slot_idx := -1
var _last_hour := -1.0
var _timer := 0.0


func register(r: NPCRoutine) -> void:
	routines.append(r)


func current_hour() -> float:
	var h = GameTime.get("hour")
	return float(h) if h != null else 8.0


func force_check() -> void:
	_check(true)


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= float(NPCRoutineDB.data().get("poll_interval", 0.5)):
		_timer = 0.0
		_check(false)


func _check(force: bool) -> void:
	var h := fposmod(current_hour(), 24.0)
	var idx := NPCRoutineDB.slot_index(h)
	var jumped := false
	if _last_hour >= 0.0:
		jumped = fposmod(h - _last_hour, 24.0) > float(NPCRoutineDB.data().get("skip_hours", 2.0))
	_last_hour = h
	if idx == _slot_idx and not force:
		return
	var snap := force or _slot_idx < 0 or jumped
	_slot_idx = idx
	var id := NPCRoutineDB.slot_id(idx)
	for r in routines:
		r.set_slot(id, snap)
	slot_changed.emit(id)
