extends Node2D
## Scena principale: genera la città e il paesaggio, ospita giocatore, HUD e ciclo giorno/notte.
## Comandi: WASD/frecce muovi, Shift corri, E interagisci, rotella zoom, I scheda personaggio.
## Debug: R nuova partita, 1/2/3/4 velocità tempo, Spazio pausa,
##        X combattimento di prova (fuori città scattano imboscate casuali),
##        H -10 salute, J +10 salute, K +10 soldi, B aggiunge bende, G regala un'arma casuale,
##        V ti infligge una ferita casuale, T una sfida a duello,
##        L pannello dei lavori, M pannello del mercato.
## I lotti senza edificio sono in vendita: E sul cartello per comprare terreno, casa o negozio (Feature 18).

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
var _buildings: BuildingManager
var _npcs: NPCManager
var _quests: QuestManager
var _combat: CombatManager
var _wounds: WoundManager
var _duels: DuelManager
var _jobs: JobManager
var _economy: EconomyManager
var _bank: BankManager
var _property: PropertyManager

func _ready() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	var cfg: Dictionary = JSON.parse_string(f.get_as_text())
	_town_cfg = cfg["town"]
	_world_cfg = cfg["world"]

	_modulate = CanvasModulate.new()
	add_child(_modulate)

	avatar = AvatarScript.new()
	avatar.name = "Player"
	avatar.add_to_group("player")
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
	add_child(ReputationManager.new())
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
	DialogueState.reset()
	BuildingActions.reset()
	PropertySystem.reset()
	town = TownGenerator.generate(_town_cfg)
	scenery = SceneryGenerator.generate(_world_cfg, town)

	var origin := Vector2(town["origin"][0], town["origin"][1])
	var hw: float = _world_cfg["half_width"]
	var hh: float = _world_cfg["half_height"]
	bounds = Rect2(origin.x - hw, origin.y - hh, hw * 2.0, hh * 2.0)

	_build_town_nodes()
	avatar.setup(bounds, origin)
	queue_redraw()

# Lotti solidi, edifici (Feature 5), NPC (Feature 6-8); i lotti ancora liberi vanno in vendita (Feature 18).
func _build_town_nodes() -> void:
	if _town_root != null:
		_town_root.queue_free()
	_town_root = Node2D.new()
	add_child(_town_root)

	var rects: Array[Rect2] = []
	for lot in town["lots"]:
		var r: Array = lot["rect"]
		rects.append(Rect2(r[0], r[1], r[2], r[3]))

	var st: Array = town["street"]
	_buildings = BuildingManager.new()
	_buildings.street_y = st[1] + st[3] * 0.5
	_town_root.add_child(_buildings)
	_buildings.spawn(rects)

	_npcs = NPCManager.new()
	_town_root.add_child(_npcs)
	_npcs.spawn(_buildings.buildings, _buildings.street_y)

	_quests = QuestManager.new()
	_town_root.add_child(_quests)
	_quests.message.connect(_prompt_hud.show_message)
	_quests.setup(avatar, bounds, Vector2(town["origin"][0], town["origin"][1]), rects)

	_combat = CombatManager.new()
	_town_root.add_child(_combat)
	_combat.message.connect(_prompt_hud.show_message)
	_combat.setup(avatar, Vector2(town["origin"][0], town["origin"][1]))
	_quests.set_combat(_combat)

	_wounds = WoundManager.new()
	_town_root.add_child(_wounds)
	_wounds.message.connect(_prompt_hud.show_message)
	_wounds.setup(avatar, Vector2(town["origin"][0], town["origin"][1]))

	_duels = DuelManager.new()
	_town_root.add_child(_duels)
	_duels.message.connect(_prompt_hud.show_message)
	_duels.setup(avatar, Vector2(town["origin"][0], town["origin"][1]))
	_npcs.duel_requested.connect(func(id: String): _duels.challenge_npc(id))

	_jobs = JobManager.new()
	_town_root.add_child(_jobs)
	_jobs.message.connect(_prompt_hud.show_message)
	_jobs.setup(avatar, Vector2(town["origin"][0], town["origin"][1]), _combat)
	_economy = EconomyManager.new()
	_town_root.add_child(_economy)
	_economy.message.connect(_prompt_hud.show_message)
	_economy.setup()
	_bank = BankManager.new()
	_town_root.add_child(_bank)
	_bank.message.connect(_prompt_hud.show_message)

	var avoid: Array[Rect2] = rects.duplicate()
	avoid.append(Rect2(st[0], st[1], st[2], st[3]))
	_jobs.set_world(_buildings.buildings, bounds, avoid)

	var used: Array[Rect2] = []
	for b in _buildings.buildings:
		used.append(b["rect"])

	_property = PropertyManager.new()
	_town_root.add_child(_property)
	_property.message.connect(_prompt_hud.show_message)
	_property.setup(town["lots"], used, _buildings.street_y)

	for i in town["lots"].size():
		var rect: Rect2 = rects[i]

		var body := StaticBody2D.new()
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var rs := RectangleShape2D.new()
		rs.size = rect.size
		shape.shape = rs
		body.add_child(shape)
		_town_root.add_child(body)

func _process(_d: float) -> void:
	_modulate.color = GameTime.get_light_color()
	_info.text = "%s  |  Giorno %d  %s  (%s)  |  seed %d  |  x%.0f  |  WASD muovi, Shift corri, E interagisci, L lavoro, M mercato" % [
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
		KEY_V:
			var rv := RandomNumberGenerator.new()
			rv.randomize()
			var vw := WoundSystem.random_wound(rv)
			if not vw.is_empty():
				_prompt_hud.show_message("Debug: %s" % WoundSystem.wound_name(vw))
		KEY_G:
			var r := RandomNumberGenerator.new()
			r.randomize()
			var wid := WeaponDB.random_id(r)
			if wid != "" and PlayerState.add_item(wid, 1) == 0:
				_prompt_hud.show_message("Debug: %s (%s)" % [WeaponDB.name_of(wid), WeaponDB.rarity_label(wid)])

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
