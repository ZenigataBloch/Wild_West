class_name UIFx
extends RefCounted
## Piccole animazioni riutilizzabili per qualunque Control.
## Esempi:
##   UIFx.pop(label_soldi)            # quando i soldi cambiano
##   UIFx.flash(barra_salute, Color.RED)  # quando subisci danno
##   UIFx.shake(pannello)             # azione non consentita


static func _center(node: Control) -> void:
	node.pivot_offset = node.size * 0.5


static func pop(node: Control, strength: float = 1.18, time: float = 0.18) -> void:
	_center(node)
	var tw := node.create_tween()
	tw.tween_property(node, "scale", Vector2.ONE * strength, time * 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", Vector2.ONE, time * 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func flash(node: CanvasItem, color: Color = Color(1.0, 0.4, 0.3), time: float = 0.3) -> void:
	var tw := node.create_tween()
	node.modulate = color
	tw.tween_property(node, "modulate", Color.WHITE, time)


static func shake(node: Control, amount: float = 6.0, time: float = 0.25) -> void:
	var origin := node.position
	var tw := node.create_tween()
	var steps := 5
	for i in steps:
		var k := 1.0 - float(i) / steps
		var dir := -1.0 if i % 2 == 0 else 1.0
		tw.tween_property(node, "position:x", origin.x + dir * amount * k, time / steps)
	tw.tween_property(node, "position", origin, time / steps)
