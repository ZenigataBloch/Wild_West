class_name TownGenerator
extends RefCounted
## Genera la città iniziale come puro dato (Dictionary, compatibile JSON).
## Le coordinate sono in pixel mondo. I "lots" sono lotti vuoti: la Feature 5
## (edifici) assegnerà a ciascuno Saloon, Banca, Sceriffo, Casa.

static func generate(cfg: Dictionary) -> Dictionary:
	var rng := WorldSeed.rng_for("town")
	var origin := Vector2(cfg["origin"][0], cfg["origin"][1])

	var name_str := "%s %s" % [
		cfg["name_prefixes"][rng.randi() % cfg["name_prefixes"].size()],
		cfg["name_suffixes"][rng.randi() % cfg["name_suffixes"].size()]
	]

	var street_w: float = cfg["street_width"]
	var street_len: float = rng.randf_range(cfg["street_length_min"], cfg["street_length_max"])
	var street := Rect2(origin.x - street_len * 0.5, origin.y - street_w * 0.5, street_len, street_w)

	var lots: Array = []
	var id := 0
	for side in ["nord", "sud"]:
		var count: int = rng.randi_range(cfg["lots_per_side_min"], cfg["lots_per_side_max"])
		var x: float = street.position.x + cfg["lot_gap"]
		for i in count:
			var w: float = rng.randf_range(cfg["lot_width_min"], cfg["lot_width_max"])
			if x + w > street.end.x - cfg["lot_gap"]:
				break
			var y: float = street.position.y - cfg["lot_depth"] - 10.0 if side == "nord" else street.end.y + 10.0
			lots.append({
				"id": id,
				"side": side,
				"rect": [x, y, w, cfg["lot_depth"]],
				"building": ""   # assegnato dalla Feature 5
			})
			id += 1
			x += w + cfg["lot_gap"]

	return {
		"name": name_str,
		"origin": [origin.x, origin.y],
		"street": [street.position.x, street.position.y, street.size.x, street.size.y],
		"lots": lots
	}
