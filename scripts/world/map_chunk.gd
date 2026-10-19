class_name MapChunk
extends Node2D
## Un riquadro della mappa: disegna i suoi prop ordinati per y. Più riquadri invece di un solo nodo
## permettono a Godot di saltare quelli fuori dallo schermo.

var props: Array = []


func setup(items: Array) -> void:
	props = items
	props.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["y"]) < float(b["y"]))
	queue_redraw()


func _draw() -> void:
	for p in props:
		PropPainter.draw(self, p)
