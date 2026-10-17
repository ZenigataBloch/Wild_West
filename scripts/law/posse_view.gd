class_name PosseView
extends Node2D
## Vice dello sceriffo (Feature 21): inseguono il giocatore e segnalano quando lo raggiungono.

signal caught

var _target: Node2D
var _deputies: Array = []
var _speed: float = 200.0
var _radius: float = 36.0
var _done: bool = false


func setup(target: Node2D, count: int, start: Vector2, speed: float, catch_radius: float) -> void:
	_target = target
	_speed = speed
	_radius = catch_radius
	for i in count:
		_deputies.append(start + Vector2(float(i) * 22.0 - float(count) * 11.0, float(i % 2) * 16.0))
	queue_redraw()


func nearest_distance() -> float:
	if _target == null or _deputies.is_empty():
		return INF
	var best := INF
	for d in _deputies:
		best = minf(best, (d as Vector2).distance_to(_target.global_position))
	return best


func count() -> int:
	return _deputies.size()


func _process(delta: float) -> void:
	if _target == null or _done:
		return
	var tp := _target.global_position
	for i in _deputies.size():
		var p: Vector2 = _deputies[i]
		var dir := (tp - p)
		if dir.length() > 1.0:
			p += dir.normalized() * _speed * delta
		_deputies[i] = p
		if p.distance_to(tp) <= _radius:
			_done = true
			caught.emit()
			break
	queue_redraw()


func _draw() -> void:
	for d in _deputies:
		var p: Vector2 = d
		draw_circle(p + Vector2(0, 6), 11.0, Color(0, 0, 0, 0.25))
		draw_circle(p, 10.0, Color(0.15, 0.2, 0.45))
		draw_arc(p, 10.0, 0.0, TAU, 20, Color(0.05, 0.07, 0.2), 2.0)
		var star := PackedVector2Array()
		for k in 10:
			var r := 6.0 if k % 2 == 0 else 2.6
			var a := -PI / 2.0 + float(k) * PI / 5.0
			star.append(p + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(star, Color(0.95, 0.8, 0.2))
