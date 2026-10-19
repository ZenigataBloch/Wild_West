class_name MapProps
extends RefCounted
## Piazza i prop della mappa (Mappa 1) a partire da MapData: luoghi di interesse (mulino, ranch,
## cimitero, accampamento, rovine, oasi, carro, cappella), altopiani e formazioni rocciose solide,
## massi, vegetazione a gruppi per bioma, ponti e guadi, arredo della città (lampioni, staccionate,
## cavalli, retrocasa, insegne agli ingressi). Solo dati: il disegno è di PropPainter.
## generate() ritorna {props: Array, solids: Array, avoid: Array[Rect2]}.

const T_DESERT := [
	["saguaro", 3.0, 14.0, 0.8, 1.3], ["barrel_cactus", 3.0, 10.0, 0.8, 1.2], ["nopal", 3.0, 12.0, 0.8, 1.2],
	["agave", 2.0, 12.0, 0.8, 1.2], ["bush", 4.0, 12.0, 0.8, 1.3], ["tuft_dry", 6.0, 6.0, 0.8, 1.3],
	["rock_s", 3.0, 10.0, 0.8, 1.3], ["rock_m", 1.5, 14.0, 0.8, 1.2], ["tumbleweed", 0.6, 8.0, 0.8, 1.2],
	["log", 0.3, 14.0, 0.8, 1.1], ["bones", 0.15, 12.0, 0.8, 1.1], ["wheel", 0.1, 9.0, 0.9, 1.1],
]
const T_SCRUB := [
	["bush", 5.0, 12.0, 0.8, 1.3], ["tuft_dry", 5.0, 6.0, 0.8, 1.3], ["saguaro", 1.0, 14.0, 0.8, 1.2],
	["nopal", 2.0, 12.0, 0.8, 1.2], ["agave", 1.0, 12.0, 0.8, 1.1], ["flowers", 1.0, 8.0, 0.8, 1.2],
	["rock_s", 2.0, 10.0, 0.8, 1.2], ["grass", 1.0, 6.0, 0.8, 1.2],
]
const T_GRASS := [
	["grass", 8.0, 6.0, 0.8, 1.3], ["flowers", 4.0, 8.0, 0.8, 1.2], ["bush", 2.0, 12.0, 0.8, 1.2],
	["cottonwood", 0.6, 26.0, 0.8, 1.2], ["tuft_dry", 1.0, 6.0, 0.8, 1.2], ["rock_s", 0.5, 10.0, 0.8, 1.1],
]
const T_BANK := [
	["cottonwood", 4.0, 26.0, 0.9, 1.3], ["bush", 3.0, 12.0, 0.8, 1.2], ["grass", 5.0, 6.0, 0.8, 1.3],
	["flowers", 2.0, 8.0, 0.8, 1.2], ["log", 0.4, 14.0, 0.8, 1.1], ["rock_s", 1.0, 10.0, 0.8, 1.2],
]
const T_WASH := [
	["dead_tree", 2.0, 14.0, 0.8, 1.2], ["bush", 3.0, 12.0, 0.8, 1.2], ["rock_s", 3.0, 10.0, 0.8, 1.3],
	["bones", 0.3, 12.0, 0.8, 1.1], ["tuft_dry", 2.0, 6.0, 0.8, 1.2], ["tumbleweed", 1.0, 8.0, 0.8, 1.2],
]
const T_HIGH := [
	["juniper", 4.0, 18.0, 0.8, 1.3], ["rock_s", 4.0, 10.0, 0.8, 1.3], ["rock_m", 3.0, 14.0, 0.8, 1.2],
	["dead_tree", 1.0, 14.0, 0.8, 1.2], ["bush", 2.0, 12.0, 0.8, 1.2], ["tuft_dry", 2.0, 6.0, 0.8, 1.2],
	["agave", 1.0, 12.0, 0.8, 1.1],
]
const T_HARD := [
	["rock_s", 2.0, 10.0, 0.8, 1.2], ["bones", 2.0, 12.0, 0.8, 1.1], ["tumbleweed", 3.0, 8.0, 0.8, 1.2],
	["bush", 0.5, 12.0, 0.8, 1.1], ["tuft_dry", 1.0, 6.0, 0.8, 1.2], ["wheel", 0.5, 9.0, 0.9, 1.1],
]
const T_REEDS := [["reeds", 1.0, 10.0, 0.9, 1.3]]


## Contenitore dei risultati con le funzioni per aggiungere prop e ostacoli solidi.
class Ctx:
	var props: Array = []
	var solids: Array = []
	var avoid: Array[Rect2] = []
	var rng: RandomNumberGenerator

	func add(t: String, pos: Vector2, s: float = 1.0, extra: Dictionary = {}) -> void:
		var d := {"t": t, "x": pos.x, "y": pos.y, "s": s, "v": rng.randi() % 1000, "flip": rng.randf() < 0.5}
		for k in extra:
			d[k] = extra[k]
		props.append(d)

	func circle(pos: Vector2, r: float) -> void:
		solids.append({"k": "circle", "pos": pos, "r": r})
		avoid.append(Rect2(pos - Vector2(r, r), Vector2(r, r) * 2.0))

	func box(rect: Rect2) -> void:
		solids.append({"k": "rect", "rect": rect})
		avoid.append(rect)

	func house(pos: Vector2, w: float, h: float, style: String = "house") -> void:
		add("house", pos, 1.0, {"w": w, "h": h, "style": style})
		box(Rect2(pos - Vector2(w, h) * 0.5, Vector2(w, h)))


## Controllo di distanza tra prop con una griglia spaziale.
class Spacing:
	var cell := 64.0
	var d := {}

	func fits(p: Vector2, r: float) -> bool:
		var cx := int(floor(p.x / cell))
		var cy := int(floor(p.y / cell))
		for ix in range(cx - 3, cx + 4):
			for iy in range(cy - 3, cy + 4):
				var key := Vector2i(ix, iy)
				if d.has(key):
					for o in d[key]:
						if p.distance_to(o[0]) < r + float(o[1]):
							return false
		return true

	func add(p: Vector2, r: float) -> void:
		var key := Vector2i(int(floor(p.x / cell)), int(floor(p.y / cell)))
		if not d.has(key):
			d[key] = []
		d[key].append([p, r])


static func generate(map: MapData, town: Dictionary, cfg: Dictionary) -> Dictionary:
	var c := Ctx.new()
	c.rng = WorldSeed.rng_for("map_props")
	var sp := Spacing.new()
	var zones: Array = []
	var pc: Dictionary = cfg.get("props", {})
	_pois(c, map, sp, zones)
	_formations(c, map, sp, zones, pc)
	_natural(c, map, sp, zones, pc)
	_town(c, town)
	_crossings(c, map)
	return {"props": c.props, "solids": c.solids, "avoid": c.avoid}


# ------------------------------------------------------------------ luoghi di interesse

static func _pois(c: Ctx, map: MapData, sp: Spacing, zones: Array) -> void:
	for poi in map.pois:
		var pos: Vector2 = poi["pos"]
		var r := float(poi["r"])
		zones.append([pos, r])
		sp.add(pos, r * 0.5)
		c.avoid.append(Rect2(pos - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6))
		match str(poi["kind"]):
			"windmill": _windmill(c, pos)
			"ranch": _ranch(c, pos)
			"graveyard": _graveyard(c, pos)
			"camp": _camp(c, pos)
			"ruins": _ruins(c, pos)
			"oasis": _oasis(c, pos, float(poi["pond"]))
			"wreck": _wreck(c, pos)
			"chapel": _chapel(c, pos)


static func _windmill(c: Ctx, p: Vector2) -> void:
	c.add("windmill", p)
	c.circle(p + Vector2(0, -6), 12.0)
	c.add("tank", p + Vector2(54, 14))
	c.circle(p + Vector2(54, 8), 15.0)
	c.add("trough", p + Vector2(-48, 28))
	c.house(p + Vector2(-100, -56), 70.0, 56.0)
	c.add("crate", p + Vector2(30, 46))
	c.add("crate", p + Vector2(42, 50))
	c.add("barrel", p + Vector2(-10, 52))
	c.add("tuft_dry", p + Vector2(-70, 20))
	c.add("wheel", p + Vector2(88, 52))


static func _ranch(c: Ctx, p: Vector2) -> void:
	c.house(p + Vector2(-130, -70), 120.0, 90.0)
	c.house(p + Vector2(80, -80), 170.0, 120.0, "barn")
	var corral := p + Vector2(-70, 84)
	c.add("fence_rect", corral, 1.0, {"w": 240.0, "h": 140.0, "gap": 50.0})
	for i in c.rng.randi_range(2, 3):
		c.add("horse", corral + Vector2(c.rng.randf_range(-90.0, 90.0), c.rng.randf_range(-30.0, 40.0)))
	c.add("trough", corral + Vector2(0, -52))
	for k in 3:
		c.add("haystack", p + Vector2(190.0 + float(k % 2) * 30.0, 10.0 + float(k) * 34.0))
	c.add("wagon", p + Vector2(110, 120), 1.0, {"a": c.rng.randf_range(-0.2, 0.2)})
	c.add("dead_tree", p + Vector2(-190, 30))
	c.add("woodpile", p + Vector2(-190, -20))
	c.add("barrel", p + Vector2(-60, -10))


static func _graveyard(c: Ctx, p: Vector2) -> void:
	c.add("fence_rect", p, 1.0, {"w": 260.0, "h": 200.0, "gap": 60.0})
	var n := 0
	for j in 3:
		for i in 4:
			if c.rng.randf() < 0.2:
				continue
			var q := p + Vector2((float(i) - 1.5) * 52.0 + c.rng.randf_range(-6.0, 6.0), (float(j) - 1.0) * 50.0 - 6.0)
			c.add("cross" if (n + i) % 3 == 0 else "headstone", q)
			n += 1
	c.add("signpost", p + Vector2(-110, 118), 1.0, {"text": "BOOT HILL", "w": 90.0})
	c.add("dead_tree", p + Vector2(-150, -60))
	c.add("dead_tree", p + Vector2(150, 40))


static func _camp(c: Ctx, p: Vector2) -> void:
	c.add("campfire", p)
	c.add("tent", p + Vector2(-72, -34))
	c.add("tent", p + Vector2(66, -48))
	c.add("tent", p + Vector2(-6, -98))
	c.add("bedroll", p + Vector2(-36, 40))
	c.add("bedroll", p + Vector2(38, 42))
	c.add("log", p + Vector2(-26, 14), 0.9, {"a": 0.1})
	c.add("log", p + Vector2(28, 16), 0.9, {"a": -0.1})
	c.add("horse", p + Vector2(118, 28))
	c.add("horse", p + Vector2(132, 46))
	c.add("crate", p + Vector2(-100, 16))
	c.add("barrel", p + Vector2(-112, 26))


static func _ruins(c: Ctx, p: Vector2) -> void:
	c.add("ruin", p, 1.0, {"w": 130.0, "h": 100.0})
	c.circle(p + Vector2(40, -34), 9.0)
	c.add("rock_s", p + Vector2(-96, 28))
	c.add("dead_tree", p + Vector2(96, 30))
	c.add("wheel", p + Vector2(-70, 66))
	c.add("bones", p + Vector2(20, 86))
	c.add("tumbleweed", p + Vector2(-110, -30))


static func _oasis(c: Ctx, p: Vector2, pond: float) -> void:
	for i in c.rng.randi_range(6, 9):
		var a := c.rng.randf() * TAU
		var d := pond + c.rng.randf_range(22.0, 48.0)
		c.add("palm", p + Vector2(cos(a), sin(a) * 0.8) * d, c.rng.randf_range(0.9, 1.25))
	for i in 5:
		var a := c.rng.randf() * TAU
		c.add("reeds", p + Vector2(cos(a), sin(a) * 0.8) * (pond + 6.0), 1.0)
	c.add("tent", p + Vector2(pond + 90.0, 24.0))
	c.add("campfire", p + Vector2(pond + 90.0, 64.0))
	c.add("bedroll", p + Vector2(pond + 56.0, 70.0))
	c.add("rock_m", p + Vector2(-pond - 40.0, 30.0))


static func _wreck(c: Ctx, p: Vector2) -> void:
	c.add("wagon", p, 1.0, {"a": c.rng.randf_range(-0.3, 0.3), "broken": true})
	c.add("wheel", p + Vector2(-50, 24))
	c.add("wheel", p + Vector2(54, 30))
	c.add("bones", p + Vector2(-20, 52))
	c.add("bones", p + Vector2(70, -26))
	for k in 3:
		c.add("crate", p + Vector2(c.rng.randf_range(-70.0, 70.0), c.rng.randf_range(20.0, 60.0)))
	c.add("barrel", p + Vector2(40, 52))
	c.add("saguaro", p + Vector2(-96, -10))


static func _chapel(c: Ctx, p: Vector2) -> void:
	c.house(p, 90.0, 130.0, "chapel")
	for i in 5:
		c.add("cross" if i % 2 == 0 else "headstone", p + Vector2(-100.0 - float(i % 2) * 36.0, -40.0 + float(i) * 28.0))
	c.add("well", p + Vector2(124, 56))
	c.circle(p + Vector2(124, 50), 14.0)
	c.add("dead_tree", p + Vector2(96, -70))
	c.add("signpost", p + Vector2(-30, 110), 1.0, {"text": "MISSIONE", "w": 80.0})


# --------------------------------------------------------------------------- rocce

static func _formations(c: Ctx, map: MapData, sp: Spacing, zones: Array, pc: Dictionary) -> void:
	var rng := c.rng
	var want := rng.randi_range(int(pc.get("formations_min", 14)), int(pc.get("formations_max", 22)))
	var made := 0
	var tries := 0
	while made < want and tries < 600:
		tries += 1
		var p := Vector2(
			rng.randf_range(map.rect.position.x + 300.0, map.rect.end.x - 300.0),
			rng.randf_range(map.rect.position.y + 300.0, map.rect.end.y - 300.0))
		var radius := rng.randf_range(70.0, 150.0)
		if not _site_ok(map, sp, zones, p, radius, 700.0):
			continue
		var pts := PackedVector2Array()
		var n := 11
		var world := PackedVector2Array()
		for i in n:
			var a := (float(i) + rng.randf_range(-0.25, 0.25)) / float(n) * TAU
			var rr := radius * rng.randf_range(0.72, 1.0)
			var q := Vector2(cos(a) * rr, sin(a) * rr * 0.8)
			pts.append(q)
			world.append(p + q)
		c.props.append({"t": "butte", "x": p.x, "y": p.y, "pts": pts, "tiers": clampi(int(radius / 50.0), 2, 4), "s": 1.0})
		c.solids.append({"k": "poly", "pts": world})
		c.avoid.append(Rect2(p - Vector2(radius, radius), Vector2(radius, radius) * 2.0))
		sp.add(p, radius + 20.0)
		made += 1

	var boulders := int(pc.get("boulders", 45))
	made = 0
	tries = 0
	while made < boulders and tries < 800:
		tries += 1
		var p := Vector2(
			rng.randf_range(map.rect.position.x + 100.0, map.rect.end.x - 100.0),
			rng.randf_range(map.rect.position.y + 100.0, map.rect.end.y - 100.0))
		var radius := rng.randf_range(14.0, 30.0)
		if not _site_ok(map, sp, zones, p, radius, 260.0):
			continue
		c.add("boulder", p, 1.0, {"r": radius})
		c.circle(p + Vector2(0, -radius * 0.3), radius * 0.85)
		sp.add(p, radius + 10.0)
		made += 1


static func _site_ok(map: MapData, sp: Spacing, zones: Array, p: Vector2, radius: float, town_dist: float) -> bool:
	if MapData.rect_dist(map.town_rect, p) < town_dist:
		return false
	if map.water_at(p) < MapData.FAR - 0.5 or map.wash_at(p) < MapData.FAR - 0.5 or map.wet_at(p) < 200.0:
		return false
	if map.trail_dist(p) < radius + 90.0:
		return false
	for z in zones:
		if p.distance_to(z[0]) < float(z[1]) + radius * 0.7:
			return false
	return sp.fits(p, radius + 60.0)


# --------------------------------------------------------------------- vegetazione

static func _pick(table: Array, rng: RandomNumberGenerator) -> Array:
	var total := 0.0
	for e in table:
		total += float(e[1])
	var roll := rng.randf() * total
	for e in table:
		roll -= float(e[1])
		if roll <= 0.0:
			return e
	return table[0]


static func _natural(c: Ctx, map: MapData, sp: Spacing, zones: Array, pc: Dictionary) -> void:
	var rng := c.rng
	var cluster := FastNoiseLite.new()
	cluster.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cluster.seed = WorldSeed.world_seed + 83
	cluster.frequency = 0.0045
	var margin := float(pc.get("town_margin", 150))
	var town_zone := map.town_rect.grow(margin)
	var area := map.rect.grow(-30.0)
	var count := int(pc.get("candidates", 15000))
	for i in count:
		var p := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if town_zone.has_point(p):
			continue
		var tr := map.trail_at(p)
		if tr < 10.0:
			continue
		var wd := map.water_at(p)
		var ws := map.wash_at(p)
		var h := map.h_at(p)
		var m := map.m_at(p)
		var table: Array = T_DESERT
		var acc := 0.35
		if wd < 14.0:
			if wd > -14.0 and rng.randf() < 0.5:
				table = T_REEDS
				acc = 0.5
			else:
				continue
		elif wd < 110.0:
			table = T_BANK
			acc = 0.8
		elif ws < 0.0:
			continue
		elif ws < 45.0:
			table = T_WASH
			acc = 0.5
		elif h > 0.64:
			table = T_HIGH
			acc = 0.45
		elif map.hard_at(p) > 0.5:
			table = T_HARD
			acc = 0.12
		elif m > 0.62:
			table = T_GRASS
			acc = 0.7
		elif m > 0.45:
			table = T_SCRUB
			acc = 0.5
		var cl := cluster.get_noise_2d(p.x, p.y) * 0.5 + 0.5
		if rng.randf() > acc * (0.25 + cl * 1.2):
			continue
		var e := _pick(table, rng)
		var rad := float(e[2])
		if tr < 40.0 and rad > 8.0:
			continue
		var blocked := false
		for z in zones:
			if p.distance_to(z[0]) < float(z[1]):
				blocked = true
				break
		if blocked or not sp.fits(p, rad):
			continue
		sp.add(p, rad)
		c.add(str(e[0]), p, rng.randf_range(float(e[3]), float(e[4])))


# ------------------------------------------------------------------------- città

static func _town(c: Ctx, town: Dictionary) -> void:
	var rng := WorldSeed.rng_for("map_town")
	c.rng = rng
	var s: Array = town["street"]
	var st := Rect2(s[0], s[1], s[2], s[3])
	var sides := {"nord": [], "sud": []}
	for lot in town["lots"]:
		var r: Array = lot["rect"]
		sides[lot["side"]].append(Rect2(r[0], r[1], r[2], r[3]))
	var gaps: Array = []
	var well_done := false
	for side in ["nord", "sud"]:
		var north: bool = side == "nord"
		var lots: Array = sides[side]
		var lamp_y := st.position.y + 14.0 if north else st.end.y - 6.0
		var rail_y := st.position.y + 20.0 if north else st.end.y - 24.0
		for i in lots.size():
			var r: Rect2 = lots[i]
			var gx := r.end.x + 20.0
			gaps.append([gx, north])
			if gx < st.end.x - 10.0 and rng.randf() < 0.85:
				c.add("lamp", Vector2(gx, lamp_y))
			if gx < st.end.x - 10.0:
				if not well_done and rng.randf() < 0.18:
					well_done = true
					c.add("well", Vector2(gx, r.end.y - 60.0 if north else r.position.y + 60.0))
				else:
					for k in rng.randi_range(0, 2):
						var ay := r.end.y - 22.0 - rng.randf() * 100.0 if north else r.position.y + 22.0 + rng.randf() * 100.0
						c.add("barrel" if rng.randf() < 0.5 else "crate", Vector2(gx + rng.randf_range(-8.0, 8.0), ay))
			# Staccionata per i cavalli davanti al lotto, lontano dalla porta.
			if rng.randf() < 0.55:
				var off := clampf(r.size.x * 0.5 - 55.0, 70.0, 115.0) * (1.0 if rng.randf() < 0.5 else -1.0)
				var rx := r.get_center().x + off
				c.add("rail", Vector2(rx, rail_y), 1.0, {"w": 70.0})
				for k in rng.randi_range(0, 2):
					c.add("horse", Vector2(rx - 16.0 + float(k) * 32.0, rail_y + 16.0))
				if rng.randf() < 0.25:
					c.add("trough", Vector2(r.get_center().x - off * 0.9, rail_y + 10.0))
			# Retrocasa.
			var back_y := r.position.y - 22.0 if north else r.end.y + 22.0
			var dirn := -1.0 if north else 1.0
			if rng.randf() < 0.6:
				c.add("fence_line", Vector2(r.position.x + 8.0, back_y), 1.0, {"x2": r.end.x - 8.0, "y2": back_y})
			for k in rng.randi_range(1, 3):
				var t: String = ["outhouse", "woodpile", "barrel", "crate", "haystack", "bush", "dead_tree", "tuft_dry"][rng.randi() % 8]
				c.add(t, Vector2(rng.randf_range(r.position.x + 30.0, r.end.x - 30.0), back_y + dirn * (22.0 + rng.randf() * 100.0)))
			if rng.randf() < 0.12:
				var cc := Vector2(r.get_center().x, back_y + dirn * 95.0)
				c.add("fence_rect", cc, 1.0, {"w": 170.0, "h": 100.0})
				c.add("horse", cc + Vector2(-20, 10))
				c.add("trough", cc + Vector2(40, -20))
	# Un paio di carri parcheggiati lungo la strada.
	for k in mini(2, gaps.size()):
		var g: Array = gaps[rng.randi() % gaps.size()]
		var wy := st.position.y + 50.0 if bool(g[1]) else st.end.y - 50.0
		c.add("wagon", Vector2(float(g[0]), wy), 1.0, {"a": 0.0 if rng.randf() < 0.5 else PI})
	var title := str(town.get("name", ""))
	c.add("signpost", Vector2(st.position.x - 50.0, st.position.y + 40.0), 1.0, {"text": title, "w": 150.0})
	c.add("signpost", Vector2(st.end.x + 50.0, st.end.y - 20.0), 1.0, {"text": title, "w": 150.0})


# ----------------------------------------------------------------- ponti e guadi

static func _crossings(c: Ctx, map: MapData) -> void:
	for x in map.crossings:
		var a: Vector2 = x["a"]
		var b: Vector2 = x["b"]
		var mid := (a + b) * 0.5
		var length := a.distance_to(b)
		if bool(x["main"]):
			c.props.append({"t": "bridge", "x": mid.x, "y": mid.y, "a": (b - a).angle(), "len": length, "w": 64.0, "s": 1.0})
		else:
			c.props.append({"t": "stones", "x": mid.x, "y": mid.y, "a": (b - a).angle(), "len": length, "v": c.rng.randi() % 1000, "s": 1.0})
