class_name DuelFighter
extends RefCounted
## Duellante in sprite (fogli 48x48 di «Cowboy (Animated Pixel Art)», Samuel Lee).
## Gli sprite guardano a destra; `facing` = -1 li specchia. Si disegna dentro il _draw()
## di un CanvasItem. Se i file mancano, available() è false e il pannello usa le sagome a codice.

const FRAME := 48
const FEET := Vector2(24.0, 48.0)      # punto d'appoggio nel fotogramma
const MUZZLE := Vector2(14.0, -22.0)   # bocca della canna rispetto ai piedi (verso destra)
const CHEST := Vector2(0.0, -24.0)
const DIR := "res://assets/duel/"
const FALL_TIME := 0.55
## nome: [file, fotogrammi, fps, ciclico, animazione successiva ("" = resta sull'ultimo fotogramma)]
const ANIMS := {
	"idle": ["CowBoyIdle", 7, 7.0, true, ""],
	"walk": ["CowBoyWalking", 8, 10.0, true, ""],
	"draw": ["CowBoyDrawWeapon", 6, 14.0, false, ""],
	"shoot": ["CowBoyShoot", 5, 14.0, false, ""],
	"quick": ["CowBoyQuickDrawShot", 18, 13.0, false, ""],
	"holster": ["CowBoyHolsterWeapon", 8, 10.0, false, "idle"],
}

var anim: String = "idle"
var down := false
var hurt := 0.0
var _t := 0.0
var _down_t := 0.0
var _tex: Dictionary = {}


static func available() -> bool:
	for k in ANIMS:
		if not ResourceLoader.exists(DIR + str(ANIMS[k][0]) + ".png"):
			return false
	return true


func play(name: String) -> void:
	if down or not ANIMS.has(name):
		return
	anim = name
	_t = 0.0


func hit() -> void:
	hurt = 1.0


func fall() -> void:
	if not down:
		down = true
		_down_t = 0.0


## Vero se l'animazione a un colpo è arrivata in fondo.
func finished() -> bool:
	var a: Array = ANIMS[anim]
	return not bool(a[3]) and _t * float(a[2]) >= float(a[1])


func update(delta: float) -> void:
	_t += delta
	hurt = maxf(0.0, hurt - delta * 4.0)
	if down:
		_down_t += delta
		return
	if finished():
		var nxt := str(ANIMS[anim][4])
		if nxt != "":
			play(nxt)


func frame_index() -> int:
	var a: Array = ANIMS[anim]
	var i := int(_t * float(a[2]))
	if bool(a[3]):
		return i % int(a[1])
	return mini(i, int(a[1]) - 1)


## Bocca della canna sullo schermo.
func muzzle(pos: Vector2, facing: int, s: float) -> Vector2:
	return pos + Vector2(MUZZLE.x * float(facing), MUZZLE.y) * s


func chest(pos: Vector2, s: float) -> Vector2:
	return pos + CHEST * s


func draw(ci: CanvasItem, pos: Vector2, facing: int, s: float, tint: Color = Color.WHITE) -> void:
	var f := float(facing)
	# Ombra: a mezzogiorno quasi sotto i piedi.
	ci.draw_set_transform(pos, 0.0, Vector2(s, s))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(-14, 0), Vector2(-7, -3), Vector2(7, -3), Vector2(14, 0), Vector2(7, 3), Vector2(-7, 3)
	]), Color(0.0, 0.0, 0.0, 0.32))
	var k := 0.0
	if down:
		k = clampf(_down_t / FALL_TIME, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
	var rot := -f * k * 1.45
	var recoil := Vector2(-f * hurt * 3.0 * s, 0.0)
	var drop := Vector2(0.0, 3.0 * s * k)
	ci.draw_set_transform(pos + recoil + drop, rot, Vector2(f * s, s))
	var col := tint.lerp(Color(1.0, 0.25, 0.2), hurt * 0.7)
	ci.draw_texture_rect_region(_texture(anim), Rect2(-FEET.x, -FEET.y, FRAME, FRAME),
			Rect2(float(frame_index() * FRAME), 0.0, float(FRAME), float(FRAME)), col)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Un fotogramma fermo (pubblico): niente stato, niente caduta.
func draw_still(ci: CanvasItem, name: String, frame: int, pos: Vector2, facing: int, s: float, tint: Color) -> void:
	var n := int(ANIMS[name][1])
	ci.draw_set_transform(pos, 0.0, Vector2(float(facing) * s, s))
	ci.draw_texture_rect_region(_texture(name), Rect2(-FEET.x, -FEET.y, FRAME, FRAME),
			Rect2(float((frame % n) * FRAME), 0.0, float(FRAME), float(FRAME)), tint)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _texture(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load(DIR + str(ANIMS[name][0]) + ".png")
	return _tex[name]
