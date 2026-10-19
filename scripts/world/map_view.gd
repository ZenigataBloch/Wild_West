class_name MapView
extends Node2D
## Mappa procedurale del mondo (Mappa 1): terreno a shader, suolo della città, prop a riquadri e
## ostacoli solidi (formazioni rocciose, massi, edifici dei luoghi di interesse). Sostituisce il
## terreno, la strada e lo scenario che prima disegnava world.gd. Livelli (z): terreno -10, suolo
## città -5, prop -1; i personaggi (0 e 1) restano sopra.
## Uso: build(bounds, town); poi `avoid_rects` (da evitare per missioni, miniera, bande) e `data`.

const CONFIG_PATH := "res://data/map_config.json"
const TERRAIN_SHADER := preload("res://shaders/terrain.gdshader")
const CHUNK := 640.0

var data: MapData
var avoid_rects: Array[Rect2] = []


## Nodo che copre il mondo con il materiale del terreno.
class TerrainLayer:
	extends Node2D
	var area := Rect2()

	func _draw() -> void:
		draw_rect(area, Color.WHITE)


func build(bounds: Rect2, town: Dictionary) -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var cfg: Dictionary = JSON.parse_string(f.get_as_text())
	data = MapData.generate(bounds, town, cfg)
	var res := MapProps.generate(data, town, cfg)

	var terrain := TerrainLayer.new()
	terrain.z_index = -10
	terrain.area = bounds.grow(1500.0)
	var mat := ShaderMaterial.new()
	mat.shader = TERRAIN_SHADER
	mat.set_shader_parameter("data_a", data.tex_a)
	mat.set_shader_parameter("data_b", data.tex_b)
	mat.set_shader_parameter("world_rect", Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y))
	mat.set_shader_parameter("seed_off", float(WorldSeed.world_seed % 9973))
	terrain.material = mat
	add_child(terrain)

	var ground := MapTownGround.new()
	add_child(ground)
	ground.z_index = -5
	ground.setup(bounds, town)

	var buckets := {}
	for p in res["props"]:
		var key := Vector2i(int(floor((float(p["x"]) - bounds.position.x) / CHUNK)), int(floor((float(p["y"]) - bounds.position.y) / CHUNK)))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(p)
	for key in buckets:
		var chunk := MapChunk.new()
		chunk.z_index = -1
		add_child(chunk)
		chunk.setup(buckets[key])

	_add_solids(res["solids"])
	avoid_rects.clear()
	for r in res["avoid"]:
		avoid_rects.append(r)
	_add_water_rects()


func _add_solids(solids: Array) -> void:
	for s in solids:
		var body := StaticBody2D.new()
		match str(s["k"]):
			"circle":
				var shape := CollisionShape2D.new()
				var circle := CircleShape2D.new()
				circle.radius = float(s["r"])
				shape.shape = circle
				body.position = s["pos"]
				body.add_child(shape)
			"rect":
				var rect: Rect2 = s["rect"]
				var shape := CollisionShape2D.new()
				var rs := RectangleShape2D.new()
				rs.size = rect.size
				shape.shape = rs
				body.position = rect.get_center()
				body.add_child(shape)
			"poly":
				var cp := CollisionPolygon2D.new()
				cp.polygon = s["pts"]
				body.add_child(cp)
		add_child(body)


# Il fiume e gli stagni si possono guadare, ma missioni, miniera e bande non devono comparirci dentro.
func _add_water_rects() -> void:
	for i in range(0, data.river.size(), 3):
		var p: Vector2 = data.river[i]
		var hw := data.river_hw[i] + 24.0
		avoid_rects.append(Rect2(p.x - hw, p.y - 70.0, hw * 2.0, 140.0))
	for poi in data.pois:
		if float(poi["pond"]) > 0.0:
			var pos: Vector2 = poi["pos"]
			var r := float(poi["pond"]) + 24.0
			avoid_rects.append(Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0))
