extends Node2D
## Scena principale: genera la città e il paesaggio, ospita giocatore, HUD e ciclo giorno/notte.
## Comandi: WASD/frecce muovi, Shift corri, E interagisci, rotella zoom, I scheda personaggio.
## Debug: R nuova partita, 1/2/3/4 velocità tempo, Spazio pausa,
##        H -10 salute, J +10 salute, K +10 soldi, B aggiunge bende.

const CONFIG_PATH := "res://data/world_config.json"
const AvatarScript := preload("res://scripts/player/player_avatar.gd")
const HudScript := preload("res://scripts/ui/player_hud.gd")
const PromptScript := preload("res://scripts/ui/interaction_hud.gd")

var town: Dictionary = {}
var scenery: Array = []
var bounds: Rect2 = Rect2()

var avatar
var _prompt_hud
var _world_cfg: Dictionary = {}
var _town_cfg: Dictionary = {}
var _modulate: CanvasModulate
var _info: Label
var _town_root: Node2D

func _ready() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var cfg: Dictionary = JSON.parse_string(f.get_as_text())
	_town_cfg = cfg["town"]
	_world_cfg = cfg["world"]

	_modulate = CanvasModulate.new()
	add_child(_modulate)

	avatar = AvatarScript.new()
	add_child(avatar)

	var layer := CanvasLayer.new()
	add_child(layer)
	_info = Label.new()
	_info.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_info.offset_left = 16
	_info.offset_top = -36
	_info.offset_bottom = -8
	_info.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_info.add_theme_font_size_override("font_size", 18)
	layer.add_child(_info)

	var hud = HudScript.new()
	add_child(hud)
	_prompt_hud = PromptScript.new()
	add_child(_prompt_hud)

	avatar.prompt_changed.connect(_prompt_hud.set_prompt)
	hud.sheet_toggled.connect(func(open: bool): avatar.input_enabled = not open)

	GameTime.phase_changed.connect(func(p): print("Fase: ", p))
	GameTime.day_changed.connect(func(d): print("Giorno ", d))
	PlayerState.player_died.connect(func(): print("Il giocatore è morto"))
	_new_game(0)

func _new_game(forced_seed: int) -> void:
	WorldSeed.new_game(forced_seed)
	GameTime.reset()
	PlayerState.new_character()
	town = TownGenerator.generate(_town_cfg)
	scenery = SceneryGenerator.generate(_world_cfg, town)

	var origin := Vector2(town["origin"][0], town["origin"][1])
	var hw: float = _world_cfg["half_width"]
	var hh: float = _world_cfg["half_height"]
	bounds = Rect2(origin.x - hw, origin.y - hh, hw * 2.0, hh * 2.0)

	_build_town_nodes()
	avatar.setup(bounds, origin)
	queue_redraw()

# Lotti solidi + punti interattivi (segnaposto: la Feature 5 li sostituirà con gli edifici).
func _build_town_nodes() -> void:
	if _town_root != null:
		_town_root.queue_free()
	_town_root = Node2D.new()
	add_child(_town_root)
	for lot in town["lots"]:
		var r: Array = lot["rect"]
		var rect := Rect2(r[0], r[1], r[2], r[3])

		var body := StaticBody2D.new()
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = rect.size
		shape.shape = rs
		body.add_child(shape)
		_town_root.add_child(body)

		var it := Interactable.new()
		it.prompt = "Esamina il lotto"
		it.message = "Lotto %d (%s): terreno libero, qui sorgerà un edificio." % [lot["id"], lot["side"]]
		var edge_y: float = rect.end.y + 30.0 if lot["side"] == "nord" else rect.position.y - 30.0
		it.position = Vector2(rect.get_center().x, edge_y)
		it.interacted.connect(_on_interacted.bind(it))
		_town_root.add_child(it)

func _on_interacted(it: Interactable) -> void:
	_prompt_hud.show_message(it.message)

func _process(_d: float) -> void:
	_modulate.color = GameTime.get_light_color()
	_info.text = "%s  |  Giorno %d  %s  (%s)  |  seed %d  |  x%.0f  |  WASD muovi, Shift corri, E interagisci" % [
		town.get("name", "?"), GameTime.day, GameTime.get_time_string(),
		GameTime.phase, WorldSeed.world_seed, GameTime.time_scale]

func _unhandled_key_input(e: InputEvent) -> void:
	if not e.pressed or e.echo:
		return
	match e.keycode:
		KEY_R: _new_game(0)
		KEY_SPACE: GameTime.paused = not GameTime.paused
		KEY_1: GameTime.time_scale = 1.0
		KEY_2: GameTime.time_scale = 5.0
		KEY_3: GameTime.time_scale = 20.0
		KEY_4: GameTime.time_scale = 60.0
		KEY_H: PlayerState.damage(10)
		KEY_J: PlayerState.heal(10)
		KEY_K: PlayerState.add_money(10)
		KEY_B: PlayerState.add_item("bende", 1)

# Rendering segnaposto: la grafica vera arriva con la Feature 4.
func _draw() -> void:
	if town.is_empty():
		return
	draw_rect(bounds.grow(1500.0), Color("#c9a66b"))                      # terreno
	draw_rect(bounds, Color("#3b2614"), false, 8.0)                       # limite dell'area
	var s: Array = town["street"]
	draw_rect(Rect2(s[0], s[1], s[2], s[3]), Color("#9c7a4a"))            # strada principale
	for lot in town["lots"]:
		var r: Array = lot["rect"]
		draw_rect(Rect2(r[0], r[1], r[2], r[3]), Color("#6b4a2b"))
		draw_rect(Rect2(r[0], r[1], r[2], r[3]), Color("#3b2614"), false, 4.0)
	for prop in scenery:
		var p := Vector2(prop["pos"][0], prop["pos"][1])
		var k: float = prop["size"]
		match prop["type"]:
			"cactus":
				var g := Color("#3f7a3a")
				draw_rect(Rect2(p.x - 5 * k, p.y - 34 * k, 10 * k, 34 * k), g)
				draw_rect(Rect2(p.x - 16 * k, p.y - 24 * k, 12 * k, 5 * k), g)
				draw_rect(Rect2(p.x - 16 * k, p.y - 34 * k, 5 * k, 15 * k), g)
				draw_rect(Rect2(p.x + 4 * k, p.y - 18 * k, 12 * k, 5 * k), g)
				draw_rect(Rect2(p.x + 11 * k, p.y - 28 * k, 5 * k, 15 * k), g)
			"roccia":
				draw_circle(p, 14 * k, Color("#7d746a"))
				draw_circle(p + Vector2(-3, -3) * k, 8 * k, Color("#9a9086"))
			"cespuglio":
				draw_circle(p, 10 * k, Color("#8a7a45"))
				draw_circle(p + Vector2(6, 2) * k, 7 * k, Color("#7a6a3a"))
