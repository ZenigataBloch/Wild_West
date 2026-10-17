extends Node
## Tempo di gioco e ciclo giorno/notte. Configurato da data/world_config.json.

signal minute_changed(hour: int, minute: int)
signal hour_changed(hour: int)
signal day_changed(day: int)
signal phase_changed(phase: String)

const CONFIG_PATH := "res://data/world_config.json"

var day: int = 1
var hour_float: float = 7.0   # 0.0 - 24.0
var time_scale: float = 1.0
var paused: bool = false
var phase: String = "giorno"

## Ora intera corrente (0-23). La usano gli orari degli edifici e le routine degli NPC.
var hour: int:
	get:
		return int(hour_float)

var _real_seconds_per_day: float = 600.0
var _start_hour: float = 7.0
var _phases: Dictionary = {}
var _keyframes: Array = []
var _key_hours: PackedFloat32Array = PackedFloat32Array()   # copie già convertite dei keyframe (luce)
var _key_colors: Array[Color] = []
var _last_minute: int = -1
var _last_hour: int = -1

func _ready() -> void:
	var cfg := _load_config()
	var t: Dictionary = cfg.get("time", {})
	_real_seconds_per_day = t.get("real_seconds_per_game_day", 600.0)
	_start_hour = t.get("start_hour", 7.0)
	_phases = t.get("phases", {})
	_keyframes = t.get("light_keyframes", [])
	_key_hours = PackedFloat32Array()
	_key_colors.clear()
	for k in _keyframes:
		_key_hours.append(float(k["hour"]))
		_key_colors.append(Color(String(k["color"])))
	reset()

func reset() -> void:
	day = 1
	hour_float = _start_hour
	_last_minute = -1
	_last_hour = -1
	phase = _compute_phase()

func _process(delta: float) -> void:
	if paused:
		return
	hour_float += delta * time_scale * 24.0 / _real_seconds_per_day
	while hour_float >= 24.0:
		hour_float -= 24.0
		day += 1
		day_changed.emit(day)
	var h := int(hour_float)
	var m := int((hour_float - h) * 60.0)
	if m != _last_minute:
		_last_minute = m
		minute_changed.emit(h, m)
	if h != _last_hour:
		_last_hour = h
		hour_changed.emit(h)
	var p := _compute_phase()
	if p != phase:
		phase = p
		phase_changed.emit(phase)

## Salta avanti fino alla prossima volta che l'orologio segna `target_hour` (dormire, svenire...).
func skip_to_hour(target_hour: int) -> void:
	var target := float(clampi(target_hour, 0, 23))
	if hour_float >= target:
		day += 1
		day_changed.emit(day)
	hour_float = target
	_last_minute = -1
	_last_hour = -1
	var p := _compute_phase()
	if p != phase:
		phase = p
		phase_changed.emit(phase)

func get_time_string() -> String:
	return "%02d:%02d" % [int(hour_float), int((hour_float - int(hour_float)) * 60.0)]


## Colore ambientale per CanvasModulate (interpolato tra i keyframe già convertiti in _ready).
func get_light_color() -> Color:
	var n := _key_colors.size()
	if n < 2:
		return Color.WHITE
	for i in range(n - 1):
		var h0 := _key_hours[i]
		var h1 := _key_hours[i + 1]
		if hour_float >= h0 and hour_float <= h1:
			var span := h1 - h0
			var k := 0.0 if span <= 0.0 else (hour_float - h0) / span
			return _key_colors[i].lerp(_key_colors[i + 1], k)
	return Color.WHITE

func _compute_phase() -> String:
	for name in _phases:
		var p: Dictionary = _phases[name]
		if hour_float >= p["from"] and hour_float < p["to"]:
			return name
	return "notte"

func _load_config() -> Dictionary:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f == null:
		push_error("world_config.json non trovato")
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}
