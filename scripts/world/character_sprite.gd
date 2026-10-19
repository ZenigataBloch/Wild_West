class_name CharacterSprite
extends Sprite2D
## Personaggio in sprite (32x64 per fotogramma) ricolorabile per regioni con
## shaders/character_palette.gdshader. Se i file in assets/characters/ mancano,
## setup() restituisce false e chi lo usa ricade sul disegno a codice.
##
## Foglio: 8 colonne x 2 righe. Indici (riga*8 + colonna):
##   giù fermo 0, su fermo 1, destra fermo 13,
##   camminata giù [2,0,3,0], su [10,1,11,1], destra [14,13,15,13] (sinistra = specchio).

const SHEET := "res://assets/characters/man_base.png"
const MAP := "res://assets/characters/man_map.png"
const SHADER_PATH := "res://shaders/character_palette.gdshader"
const STEP_TIME := 0.15
const FEET_OFFSET := Vector2(0.0, -10.0)   # piedi circa 12 px sotto l'origine del nodo

const IDLE := {"down": 0, "up": 1, "side": 13}
const WALK := {"down": [2, 0, 3, 0], "up": [10, 1, 11, 1], "side": [14, 13, 15, 13]}

var _dir := "down"
var _moving := false
var _t := 0.0
var _step := 0

static func available() -> bool:
	return ResourceLoader.exists(SHEET) and ResourceLoader.exists(MAP) and ResourceLoader.exists(SHADER_PATH)


## Colori per regione: skin, hair, shirt, pants, boots, hat (tutti Color).
func setup(colors: Dictionary) -> bool:
	if not available():
		return false
	texture = load(SHEET)
	hframes = 8
	vframes = 2
	offset = FEET_OFFSET
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var mat := ShaderMaterial.new()
	mat.shader = load(SHADER_PATH)
	mat.set_shader_parameter("region_map", load(MAP))
	for k in ["skin", "hair", "shirt", "pants", "boots", "hat"]:
		if colors.has(k):
			mat.set_shader_parameter("c_" + k, colors[k])
	material = mat
	frame = IDLE["down"]
	return true


## Direzione (vettore) e se sta camminando.
func face(dir: Vector2, moving: bool) -> void:
	var d := _dir
	if absf(dir.x) > absf(dir.y) and absf(dir.x) > 0.1:
		d = "side"
		flip_h = dir.x < 0.0
	elif dir.y < -0.1:
		d = "up"
	elif dir.y > 0.1:
		d = "down"
	if d != _dir or moving != _moving:
		_dir = d
		_moving = moving
		_t = 0.0
		_step = 0
		_apply()


func _process(delta: float) -> void:
	if not _moving:
		return
	_t += delta
	if _t >= STEP_TIME:
		_t = 0.0
		_step = (_step + 1) % 4
		_apply()


func _apply() -> void:
	frame = int(WALK[_dir][_step]) if _moving else int(IDLE[_dir])


## Colori di un NPC: pelle, camicia e cappello dai dati; capelli, pantaloni e stivali dall'id.
static func colors_for(npc: Dictionary) -> Dictionary:
	var hairs := [Color("#2b1a0e"), Color("#4a2f1a"), Color("#7a5230"), Color("#b08850"), Color("#1c1c1c"), Color("#8a8a8a")]
	var pants := [Color("#3b3a52"), Color("#4a3a2a"), Color("#2f3f33"), Color("#5a4a3a"), Color("#33333a")]
	var h := absi(hash(String(npc.get("id", npc.get("name", "")))))
	return {
		"skin": Color(String(npc.get("skin", "#e8c9a0"))),
		"hair": hairs[h % hairs.size()],
		"shirt": Color(String(npc.get("shirt", "#4a6fa5"))),
		"pants": pants[(h / 7) % pants.size()],
		"boots": Color("#3a2416"),
		"hat": Color(String(npc.get("hat", "#5b3a1e"))),
	}


static func player_colors() -> Dictionary:
	return {
		"skin": Color("#e8c9a0"), "hair": Color("#4a2f1a"), "shirt": Color("#4a6fa5"),
		"pants": Color("#3b3a52"), "boots": Color("#3a2416"), "hat": Color("#5b3a1e"),
	}
