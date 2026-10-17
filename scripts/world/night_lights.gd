class_name NightLights
extends Node2D
## Luci notturne (Feature 27): le finestre degli edifici si accendono con il buio e il
## giocatore porta una lanterna. L'intensità segue il colore ambientale di GameTime
## (data/world_config.json), quindi non servono orari separati. Solo grafica.

const TEX_SIZE := 128

var _tex: GradientTexture2D
var _window_lights: Array[PointLight2D] = []
var _lantern: PointLight2D


func _ready() -> void:
	_tex = _make_texture()
	GameTime.minute_changed.connect(_on_minute)


## Ricrea le luci delle finestre per gli edifici dati (Array di Dictionary con "rect" e
## "door_on_bottom", come BuildingManager.buildings) e, la prima volta, la lanterna del giocatore.
func setup(buildings: Array, avatar: Node2D) -> void:
	for l in _window_lights:
		if is_instance_valid(l):
			l.queue_free()
	_window_lights.clear()
	for b in buildings:
		var rect: Rect2 = b["rect"]
		# Stesse posizioni delle finestre disegnate da BuildingFacade.
		var door_y := rect.size.y - 24.0 if bool(b["door_on_bottom"]) else 0.0
		for fx in [0.2, 0.8]:
			var pos := rect.position + Vector2(rect.size.x * float(fx), door_y + 12.0)
			_window_lights.append(_add_light(pos, 1.7, Color(1.0, 0.78, 0.45), self))
	if avatar != null and not is_instance_valid(_lantern):
		_lantern = _add_light(Vector2.ZERO, 2.6, Color(1.0, 0.86, 0.62), avatar)
	_apply()


func _on_minute(_hour: int, _minute: int) -> void:
	_apply()


# 0 = pieno giorno, 1 = notte fonda (dal colore ambientale: chiaro = giorno, scuro = notte).
func _darkness() -> float:
	var lum := GameTime.get_light_color().get_luminance()
	return clampf((0.85 - lum) / 0.55, 0.0, 1.0)


func _apply() -> void:
	var night := _darkness()
	var on := night > 0.02
	for l in _window_lights:
		if is_instance_valid(l):
			l.energy = night * 0.9
			l.visible = on
	if is_instance_valid(_lantern):
		_lantern.energy = night * 0.55
		_lantern.visible = on


func _add_light(pos: Vector2, light_scale: float, color: Color, parent: Node) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _tex
	l.texture_scale = light_scale
	l.color = color
	l.energy = 0.0
	l.visible = false
	l.shadow_enabled = false
	l.position = pos
	parent.add_child(l)
	return l


# Gradiente radiale bianco -> nero: al centro la luce piena, ai bordi nulla.
func _make_texture() -> GradientTexture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.45, 0.45, 0.45, 1), Color(0, 0, 0, 1)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = TEX_SIZE
	t.height = TEX_SIZE
	return t
