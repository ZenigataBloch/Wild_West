class_name JobSites
extends RefCounted
## Luoghi di lavoro nel mondo (Feature 15 collegata a edifici e mappa).
## Un lavoro in data/jobs.json può avere "place": {"kind": "building"|"site", "id": ..., "radius": px, "label": ...}.
## "building" = ingresso di un edificio (BuildingManager), "site" = punto fuori città creato dal JobManager (es. la miniera).
## can_work() chiede qui dove si trova il luogo; se non esiste (dati mancanti) il vincolo non si applica.

static var points: Dictionary = {}   # "building:saloon" / "site:miniera" -> Vector2


static func reset() -> void:
	points.clear()


static func set_point(kind: String, id: String, pos: Vector2) -> void:
	points["%s:%s" % [kind, id]] = pos


## Vector2 oppure null se il luogo non esiste.
static func place_pos(place: Dictionary):
	return points.get("%s:%s" % [str(place.get("kind", "")), str(place.get("id", ""))], null)


static func is_near(place: Dictionary, pos: Vector2) -> bool:
	var p = place_pos(place)
	if p == null:
		return true
	return pos.distance_to(p as Vector2) <= float(place.get("radius", 160.0))
