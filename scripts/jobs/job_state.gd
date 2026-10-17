class_name JobState
extends RefCounted
## Stato dei lavori del giocatore (solo in memoria, si azzera a ogni nuova partita).

static var current: String = ""
static var shifts: Dictionary = {}     # id lavoro -> turni svolti
static var earned_total: int = 0
static var earned_today: int = 0
static var _today: int = -1


static func reset() -> void:
	current = ""
	shifts = {}
	earned_total = 0
	earned_today = 0
	_today = -1


static func shifts_of(job_id: String) -> int:
	return int(shifts.get(job_id, 0))


static func today_earned() -> int:
	if "day" in GameTime and int(GameTime.day) != _today:
		return 0
	return earned_today


static func record(job_id: String, pay: int) -> void:
	shifts[job_id] = shifts_of(job_id) + 1
	var d := int(GameTime.day) if "day" in GameTime else 0
	if d != _today:
		_today = d
		earned_today = 0
	earned_today += pay
	earned_total += pay
