class_name MapData
extends RefCounted
## Dati della mappa procedurale (Mappa 1), solo logica: griglia a celle di 16 px con altezza, umidità,
## salina, terra battuta e distanze (dal bordo) da acqua, letti asciutti e sentieri.
## Dal seed (canali "map_*") nascono: un fiume che attraversa la mappa a est o a ovest della città,
## 1-2 letti asciutti, la strada principale con diramazioni, i luoghi di interesse (POI) e gli stagni.
## `tex_a` e `tex_b` alimentano shaders/terrain.gdshader.

const CELL := 16.0
const FAR := 110.0        # valore dei campi di distanza lontano da tutto
const WET_FAR := 280.0

var rect := Rect2()
var cols := 0
var rows := 0
var town_rect := Rect2()
var origin := Vector2.ZERO

var height := PackedFloat32Array()
var moist := PackedFloat32Array()
var hard := PackedFloat32Array()
var yard := PackedFloat32Array()
var water := PackedFloat32Array()   # distanza dal bordo dell'acqua (negativa dentro)
var wash := PackedFloat32Array()    # idem per i letti asciutti
var trail := PackedFloat32Array()   # idem per i sentieri
var wet := PackedFloat32Array()     # distanza dal centro del fiume (per l'umidità)

var river := PackedVector2Array()
var river_hw := PackedFloat32Array()
var washes: Array = []              # Array di PackedVector2Array
var trails: Array = []              # {pts: PackedVector2Array, hw: float, main: bool}
var crossings: Array = []           # {a: Vector2, b: Vector2, main: bool}
var pois: Array = []                # {kind: String, pos: Vector2, r: float, pond: float}
var tex_a: ImageTexture
var tex_b: ImageTexture

var _cfg: Dictionary = {}
var _nh: FastNoiseLite
var _nm: FastNoiseLite


static func generate(bounds: Rect2, town: Dictionary, cfg: Dictionary) -> MapData:
	var m := MapData.new()
	m._build(bounds, town, cfg)
	return m


# ------------------------------------------------------------------ interrogazioni

func _cell(p: Vector2) -> int:
	var cx := clampi(int((p.x - rect.position.x) / CELL), 0, cols - 1)
	var cy := clampi(int((p.y - rect.position.y) / CELL), 0, rows - 1)
	return cy * cols + cx


func h_at(p: Vector2) -> float:
	return height[_cell(p)]


func m_at(p: Vector2) -> float:
	return moist[_cell(p)]


func water_at(p: Vector2) -> float:
	return water[_cell(p)]


func wash_at(p: Vector2) -> float:
	return wash[_cell(p)]


func trail_at(p: Vector2) -> float:
	return trail[_cell(p)]


func hard_at(p: Vector2) -> float:
	return hard[_cell(p)]


func wet_at(p: Vector2) -> float:
	return wet[_cell(p)]


## Distanza (approssimata, campioni ogni ~50 px) dal sentiero più vicino.
func trail_dist(p: Vector2) -> float:
	var best := 99999.0
	for t in trails:
		for q in t["pts"]:
			var d := p.distance_to(q)
			if d < best:
				best = d
	return best


static func rect_dist(r: Rect2, p: Vector2) -> float:
	var dx := maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy := maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


static func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


# ---------------------------------------------------------------------- costruzione

func _build(bounds: Rect2, town: Dictionary, cfg: Dictionary) -> void:
	_cfg = cfg
	rect = bounds
	origin = Vector2(float(town["origin"][0]), float(town["origin"][1]))
	cols = int(ceil(bounds.size.x / CELL))
	rows = int(ceil(bounds.size.y / CELL))
	var n := cols * rows
	height.resize(n)
	moist.resize(n)
	hard.resize(n)
	yard.resize(n)
	water.resize(n)
	wash.resize(n)
	trail.resize(n)
	wet.resize(n)
	water.fill(FAR)
	wash.fill(FAR)
	trail.fill(FAR)
	wet.fill(WET_FAR)

	var s: Array = town["street"]
	town_rect = Rect2(s[0], s[1], s[2], s[3])
	for lot in town["lots"]:
		var r: Array = lot["rect"]
		town_rect = town_rect.merge(Rect2(r[0], r[1], r[2], r[3]))

	var seed_i := WorldSeed.world_seed
	var ncfg: Dictionary = cfg.get("noise", {})
	_nh = _noise(seed_i + 11, float(ncfg.get("height_freq", 0.00085)), 4)
	_nm = _noise(seed_i + 23, float(ncfg.get("moist_freq", 0.0011)), 3)

	_make_river()
	_make_washes()
	_fill_terrain()
	_place_pois()
	_make_trails(town)
	_finish_fields()
	_make_textures()


static func _noise(seed_v: int, freq: float, octaves: int) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.seed = seed_v
	n.frequency = freq
	n.fractal_type = FastNoiseLite.FRACTAL_FBM
	n.fractal_octaves = octaves
	return n


func _stamp(field: PackedFloat32Array, p: Vector2, radius: float, reach: float) -> void:
	var span := reach + radius
	var cx0 := maxi(0, int(floor((p.x - span - rect.position.x) / CELL)))
	var cx1 := mini(cols - 1, int(ceil((p.x + span - rect.position.x) / CELL)))
	var cy0 := maxi(0, int(floor((p.y - span - rect.position.y) / CELL)))
	var cy1 := mini(rows - 1, int(ceil((p.y + span - rect.position.y) / CELL)))
	for cy in range(cy0, cy1 + 1):
		var py := rect.position.y + (float(cy) + 0.5) * CELL
		for cx in range(cx0, cx1 + 1):
			var px := rect.position.x + (float(cx) + 0.5) * CELL
			var d := Vector2(px, py).distance_to(p) - radius
			var i := cy * cols + cx
			if d < field[i]:
				field[i] = d


func _stamp_poly(field: PackedFloat32Array, pts: PackedVector2Array, hws: PackedFloat32Array, reach: float, step: float) -> void:
	for i in range(pts.size() - 1):
		var a := pts[i]
		var b := pts[i + 1]
		var k := maxi(1, int(a.distance_to(b) / step))
		for j in k:
			var t := float(j) / float(k)
			_stamp(field, a.lerp(b, t), lerpf(hws[i], hws[i + 1], t), reach)
	_stamp(field, pts[pts.size() - 1], hws[pts.size() - 1], reach)


static func _const_array(n: int, v: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	a.fill(v)
	return a


## Percorso ondulato da a a b (agli estremi non si sposta).
static func _path(a: Vector2, b: Vector2, wob: FastNoiseLite, amp: float, salt: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var length := a.distance_to(b)
	var steps := maxi(2, int(length / 50.0))
	var perp := (b - a).orthogonal().normalized()
	for i in steps + 1:
		var t := float(i) / float(steps)
		var off := wob.get_noise_2d(t * length * 0.004 + salt, salt) * amp * sin(t * PI)
		pts.append(a.lerp(b, t) + perp * off)
	return pts


# ------------------------------------------------------------------- fiume e letti

func _make_river() -> void:
	var rng := WorldSeed.rng_for("map_river")
	var rc: Dictionary = _cfg.get("river", {})
	var half_len := town_rect.size.x * 0.5
	var side := -1.0 if rng.randf() < 0.5 else 1.0
	var x0 := origin.x + side * (half_len + rng.randf_range(float(rc.get("min_offset", 450)), float(rc.get("max_offset", 1300))))
	x0 = clampf(x0, rect.position.x + 450.0, rect.end.x - 450.0)
	var amp := float(rc.get("meander", 380))
	var hw_range: Array = rc.get("half_width", [34, 50])
	var n1 := _noise(WorldSeed.world_seed + 51, 1.0, 2)
	var hw_base := rng.randf_range(float(hw_range[0]), float(hw_range[1]))
	var y := rect.position.y - 40.0
	while y <= rect.end.y + 40.0:
		var x := x0 + n1.get_noise_2d(y * 0.0016, 3.0) * amp + n1.get_noise_2d(y * 0.006, 9.0) * 60.0
		river.append(Vector2(x, y))
		river_hw.append(hw_base + n1.get_noise_2d(y * 0.004, 21.0) * 12.0)
		y += 40.0
	_stamp_poly(water, river, river_hw, FAR, 12.0)
	_stamp_poly(wet, river, _const_array(river.size(), 0.0), WET_FAR, 40.0)


func _make_washes() -> void:
	var rng := WorldSeed.rng_for("map_wash")
	var wc: Dictionary = _cfg.get("washes", {})
	var count := rng.randi_range(int(wc.get("count_min", 1)), int(wc.get("count_max", 2)))
	var hw_range: Array = wc.get("half_width", [14, 24])
	var min_dy := float(wc.get("min_town_dy", 650))
	var wob := _noise(WorldSeed.world_seed + 61, 1.0, 2)
	for i in count:
		# Parte dal fiume (a una quota lontana dalla città) e si dirige verso un bordo laterale.
		var tries := 0
		var y0 := origin.y
		while tries < 40:
			tries += 1
			y0 = rng.randf_range(rect.position.y + 400.0, rect.end.y - 400.0)
			if absf(y0 - origin.y) >= min_dy:
				break
		var start := river[clampi(int((y0 - rect.position.y + 40.0) / 40.0), 0, river.size() - 1)]
		var to_east := start.x < origin.x
		var edge_x := rect.end.x + 20.0 if to_east else rect.position.x - 20.0
		var stop := Vector2(edge_x, clampf(y0 + rng.randf_range(-500.0, 500.0), rect.position.y + 100.0, rect.end.y - 100.0))
		if absf(stop.y - origin.y) < min_dy * 0.6:
			stop.y = origin.y + signf(y0 - origin.y) * min_dy
		var pts := _path(start, stop, wob, 260.0, float(i) * 7.0 + 2.0)
		washes.append(pts)
		_stamp_poly(wash, pts, _const_array(pts.size(), rng.randf_range(float(hw_range[0]), float(hw_range[1]))), FAR, 12.0)


# -------------------------------------------------------------------- terreno base

func _fill_terrain() -> void:
	var fc: Dictionary = _cfg.get("town_flat", {})
	var f_in := float(fc.get("inner", 260))
	var f_out := float(fc.get("outer", 1300))
	for cy in rows:
		var py := rect.position.y + (float(cy) + 0.5) * CELL
		for cx in cols:
			var p := Vector2(rect.position.x + (float(cx) + 0.5) * CELL, py)
			var i := cy * cols + cx
			var flat := _smooth(f_in, f_out, rect_dist(town_rect, p))
			var w := wet[i]
			var valley := exp(-pow(w / 200.0, 2.0))
			var h := _nh.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			h = lerpf(0.40, h, flat) - 0.14 * valley
			var m := _nm.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			m = lerpf(0.32, m, flat) + 0.55 * exp(-pow(w / 150.0, 2.0))
			height[i] = clampf(h, 0.0, 1.0)
			moist[i] = clampf(m, 0.0, 1.0)


func _finish_fields() -> void:
	for cy in rows:
		var py := rect.position.y + (float(cy) + 0.5) * CELL
		for cx in cols:
			var p := Vector2(rect.position.x + (float(cx) + 0.5) * CELL, py)
			var i := cy * cols + cx
			var salt := clampf((0.37 - height[i]) / 0.07, 0.0, 1.0) * clampf((0.46 - moist[i]) / 0.14, 0.0, 1.0)
			hard[i] = salt
			yard[i] = 1.0 - _smooth(0.0, 260.0, rect_dist(town_rect, p))


# ---------------------------------------------------------------- luoghi di interesse

func _pick_kind(kinds: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in kinds:
		total += float(kinds[k].get("weight", 1))
	var roll := rng.randf() * total
	for k in kinds:
		roll -= float(kinds[k].get("weight", 1))
		if roll <= 0.0:
			return str(k)
	return str(kinds.keys()[0])


func _place_pois() -> void:
	var rng := WorldSeed.rng_for("map_pois")
	var pc: Dictionary = _cfg.get("pois", {})
	var kinds: Dictionary = pc.get("kinds", {})
	if kinds.is_empty():
		return
	var count := rng.randi_range(int(pc.get("count_min", 6)), int(pc.get("count_max", 9)))
	var min_town := float(pc.get("min_town_dist", 950))
	var sep := float(pc.get("min_sep", 800))
	var tries := 0
	while pois.size() < count and tries < 800:
		tries += 1
		var p := Vector2(
			rng.randf_range(rect.position.x + 380.0, rect.end.x - 380.0),
			rng.randf_range(rect.position.y + 380.0, rect.end.y - 380.0))
		if rect_dist(town_rect, p) < min_town:
			continue
		var kind := _pick_kind(kinds, rng)
		var r := float(kinds[kind].get("radius", 140))
		if water_at(p) < FAR - 0.5 or wash_at(p) < FAR - 0.5 or wet_at(p) < r + 80.0:
			continue
		if h_at(p) > 0.64:
			continue
		var ok := true
		for o in pois:
			if p.distance_to(o["pos"]) < sep:
				ok = false
				break
		if not ok:
			continue
		var poi := {"kind": kind, "pos": p, "r": r, "pond": 0.0}
		if kind == "oasis":
			var pr := rng.randf_range(60.0, 100.0)
			poi["pond"] = pr
			_stamp_pond(p, pr)
		pois.append(poi)


func _stamp_pond(p: Vector2, r: float) -> void:
	_stamp(water, p, r, FAR)
	var span := 320.0
	var cx0 := maxi(0, int(floor((p.x - span - rect.position.x) / CELL)))
	var cx1 := mini(cols - 1, int(ceil((p.x + span - rect.position.x) / CELL)))
	var cy0 := maxi(0, int(floor((p.y - span - rect.position.y) / CELL)))
	var cy1 := mini(rows - 1, int(ceil((p.y + span - rect.position.y) / CELL)))
	for cy in range(cy0, cy1 + 1):
		for cx in range(cx0, cx1 + 1):
			var c := Vector2(rect.position.x + (float(cx) + 0.5) * CELL, rect.position.y + (float(cy) + 0.5) * CELL)
			var d := maxf(c.distance_to(p) - r, 0.0)
			var i := cy * cols + cx
			moist[i] = clampf(moist[i] + 0.5 * exp(-pow(d / 130.0, 2.0)), 0.0, 1.0)
			height[i] = clampf(height[i] - 0.10 * exp(-pow(d / 160.0, 2.0)), 0.0, 1.0)


# ------------------------------------------------------------------------- sentieri

func _make_trails(town: Dictionary) -> void:
	var rng := WorldSeed.rng_for("map_trails")
	var tc: Dictionary = _cfg.get("trails", {})
	var wob := _noise(WorldSeed.world_seed + 71, 1.0, 2)
	var s: Array = town["street"]
	var street := Rect2(s[0], s[1], s[2], s[3])
	var mid_y := street.position.y + street.size.y * 0.5
	var main_hw := float(tc.get("main_half_width", 24))

	var west := _path(Vector2(street.position.x, mid_y), Vector2(rect.position.x + 10.0, mid_y + rng.randf_range(-300.0, 300.0)), wob, 220.0, 1.0)
	var east := _path(Vector2(street.end.x, mid_y), Vector2(rect.end.x - 10.0, mid_y + rng.randf_range(-300.0, 300.0)), wob, 220.0, 5.0)
	trails.append({"pts": west, "hw": main_hw, "main": true})
	trails.append({"pts": east, "hw": main_hw, "main": true})

	# Diramazioni verso nord e sud, partendo dalla strada fuori città.
	var branch_hw := float(tc.get("branch_half_width", 17))
	var nb := rng.randi_range(int(tc.get("branches_min", 2)), int(tc.get("branches_max", 3)))
	for i in nb:
		var base_trail: PackedVector2Array = (west if rng.randf() < 0.5 else east)
		var start_pt: Vector2 = base_trail[rng.randi_range(base_trail.size() / 3, base_trail.size() - 3)]
		var north := rng.randf() < 0.5
		var to := Vector2(clampf(start_pt.x + rng.randf_range(-700.0, 700.0), rect.position.x + 60.0, rect.end.x - 60.0),
				rect.position.y + 10.0 if north else rect.end.y - 10.0)
		trails.append({"pts": _path(start_pt, to, wob, 260.0, 11.0 + float(i) * 3.0), "hw": branch_hw, "main": false})

	# Un sentiero da ogni luogo di interesse alla strada o al sentiero più vicino.
	var poi_hw := float(tc.get("poi_half_width", 12))
	var base_count := trails.size()
	for poi in pois:
		var pos: Vector2 = poi["pos"]
		var best := Vector2.ZERO
		var bd := 999999.0
		for k in base_count:
			for q in trails[k]["pts"]:
				var d := pos.distance_to(q)
				if d < bd:
					bd = d
					best = q
		trails.append({"pts": _path(pos, best, wob, minf(bd * 0.25, 160.0), 23.0 + pos.x * 0.001), "hw": poi_hw, "main": false})

	for t in trails:
		var pts: PackedVector2Array = t["pts"]
		_stamp_poly(trail, pts, _const_array(pts.size(), float(t["hw"])), FAR, 12.0)
	_find_crossings()


## Dove un sentiero entra in acqua: ponte per la strada principale, guado per gli altri.
func _find_crossings() -> void:
	var margin := float(_cfg.get("river", {}).get("bridge_margin", 36))
	for t in trails:
		var pts: PackedVector2Array = t["pts"]
		var inside := false
		var enter := Vector2.ZERO
		var last := Vector2.ZERO
		for i in range(pts.size() - 1):
			var a := pts[i]
			var b := pts[i + 1]
			var k := maxi(1, int(a.distance_to(b) / 10.0))
			for j in k:
				var p := a.lerp(b, float(j) / float(k))
				var is_in := water_at(p) < 0.0
				if is_in and not inside:
					inside = true
					enter = p
				elif not is_in and inside:
					inside = false
					var dir := (p - enter).normalized()
					crossings.append({"a": enter - dir * margin, "b": p + dir * margin, "main": bool(t["main"])})
				last = p
		if inside:
			crossings.append({"a": enter, "b": last, "main": false})


# ------------------------------------------------------------------------- texture

static func _b(v: float) -> int:
	return int(clampf(v, 0.0, 1.0) * 255.0 + 0.5)


static func _enc(d: float) -> int:
	return int(clampf((d + 80.0) / 280.0, 0.0, 1.0) * 255.0 + 0.5)


func _make_textures() -> void:
	var n := cols * rows
	var a := PackedByteArray()
	var b := PackedByteArray()
	a.resize(n * 4)
	b.resize(n * 4)
	for i in n:
		a[i * 4] = _b(height[i])
		a[i * 4 + 1] = _b(moist[i])
		a[i * 4 + 2] = _enc(trail[i])
		a[i * 4 + 3] = _enc(water[i])
		b[i * 4] = _enc(wash[i])
		b[i * 4 + 1] = _b(hard[i])
		b[i * 4 + 2] = _b(yard[i])
		b[i * 4 + 3] = 255
	tex_a = ImageTexture.create_from_image(Image.create_from_data(cols, rows, false, Image.FORMAT_RGBA8, a))
	tex_b = ImageTexture.create_from_image(Image.create_from_data(cols, rows, false, Image.FORMAT_RGBA8, b))
