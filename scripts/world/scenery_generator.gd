class_name SceneryGenerator
extends RefCounted
## Genera cactus, rocce e cespugli fuori dalla città (solo dati, dipendono dal seed).

static func generate(world_cfg: Dictionary, town: Dictionary) -> Array:
	var rng := WorldSeed.rng_for("scenery")
	var o: Array = town["origin"]
	var hw: float = world_cfg["half_width"]
	var hh: float = world_cfg["half_height"]
	var area := Rect2(o[0] - hw, o[1] - hh, hw * 2.0, hh * 2.0)

	# zona della città = strada + lotti, con un margine libero
	var s: Array = town["street"]
	var town_rect := Rect2(s[0], s[1], s[2], s[3])
	for lot in town["lots"]:
		var r: Array = lot["rect"]
		town_rect = town_rect.merge(Rect2(r[0], r[1], r[2], r[3]))
	town_rect = town_rect.grow(float(world_cfg["scenery_clear_margin"]))

	var types := ["cactus", "roccia", "cespuglio"]
	var target := int(world_cfg["scenery_count"])
	var props: Array = []
	var tries := 0
	while props.size() < target and tries < target * 20:
		tries += 1
		var p := Vector2(
			rng.randf_range(area.position.x + 40.0, area.end.x - 40.0),
			rng.randf_range(area.position.y + 40.0, area.end.y - 40.0))
		if town_rect.has_point(p):
			continue
		props.append({
			"type": types[rng.randi() % types.size()],
			"pos": [p.x, p.y],
			"size": rng.randf_range(0.8, 1.4)
		})
	return props
