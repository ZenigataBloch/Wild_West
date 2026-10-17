class_name QuestProp
extends Interactable
## Oggetto interattivo di una missione nel mondo: "item" (da recuperare) o "animal" (da cacciare).

var quest_id := ""
var kind := "item"


func _draw() -> void:
	if kind == "animal":
		draw_circle(Vector2.ZERO, 9, Color("#6e5a45"))
		draw_circle(Vector2(8, -4), 5, Color("#5a4636"))
		draw_arc(Vector2.ZERO, 14, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, 0.9), 2.0)
	else:
		draw_rect(Rect2(-9, -7, 18, 14), Color("#8a5a2b"))
		draw_rect(Rect2(-9, -7, 18, 14), Color("#3b2614"), false, 2.0)
		draw_arc(Vector2.ZERO, 16, 0.0, TAU, 24, Color(1.0, 0.85, 0.3, 0.9), 2.0)
