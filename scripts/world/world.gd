extends Node2D
## Scena principale: genera la città e il paesaggio, ospita giocatore, HUD e ciclo giorno/notte.
## Comandi: WASD/frecce muovi, Shift corri, E interagisci, rotella zoom, I scheda personaggio.
## Debug: R nuova partita, 1/2/3/4 velocità tempo, Spazio pausa,
##        X combattimento di prova (fuori città scattano imboscate casuali),
##        H -10 salute, J +10 salute, K +10 soldi, B aggiunge bende, G regala un'arma casuale,
##        V ti infligge una ferita casuale, T una sfida a duello,
##        L pannello dei lavori, M pannello del mercato, N pannello delle bande (Feature 19),
##        C pannello del malaffare: furti, rapine, ricatti, contrabbando (Feature 20).
## Con notorietà alta i vice dello sceriffo ti inseguono e ti arrestano (Feature 21).
## Eventi casuali (rapina in banca, incendio, aggressione, carovana, duello, incontro misterioso): Y ne fa partire uno (Feature 22).
## I lotti senza edificio sono in vendita: E sul cartello per comprare terreno, casa o negozio (Feature 18).
## F1 apre il menu con i comandi, Salva e Carica (Feature 26).
## Se muori (salute 0) compare la schermata di morte: carica l'ultimo salvataggio o nuova partita (Feature 25).
## F5 salva la partita, F6 carica il salvataggio più recente; autosalvataggio a ogni nuovo giorno (Feature 23).
## Feature 27: pannello orario in stile western, terreno e strada rifiniti, luci notturne, vignettatura.
## Mappa 1: mappa procedurale (MapView): biomi, fiume e ponte, sentieri, formazioni rocciose, luoghi di interesse.

const CONFIG_PATH := "res://data/world_config.json"
const AvatarScript := preload("res://scripts/player/player_avatar.gd")
const HudScript := preload("res://scripts/ui/player_hud.gd")
const PromptScript := preload("res://scripts/ui/interaction_hud.gd")
const VIGNETTE_SHADER := preload("res://shaders/screen_vignette.gdshader")

var town: Dictionary = {}
var bounds: Rect2 = Rect2()

var avatar
var _prompt_hud
var _world_cfg: Dictionary = {}
var _town_cfg: Dictionary = {}
var _modulate: CanvasModulate
var _info: Label
var _info_hint: Label
var _night: NightLights
var _map: MapView
var _last_light_hour: float = -1.0
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
var _gangs: GangManager
var _crime: CrimeManager
var _law: LawManager
var _events: EventManager
var _save: SaveManager
var _death: DeathManager
var _menu: GameMenu

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
	layer.layer = 2   # sopra la vignettatura (livello 1), sotto HUD e pannelli
	add_child(layer)
	var info_panel := PanelContainer.new()
	WesternTheme.apply(info_panel)
	info_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	info_panel.offset_left = 16
	info_panel.offset_right = 16
	info_panel.offset_top = -12
	info_panel.offset_bottom = -12
	info_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	layer.add_child(info_panel)
	var info_box := VBoxContainer.new()
	info_box.add_theme_constant_override("separation", 0)
	info_panel.add_child(info_box)
	_info = Label.new()
	_info.add_theme_font_size_override("font_size", 18)
	info_box.add_child(_info)
	_info_hint = Label.new()
	_info_hint.add_theme_font_size_override("font_size", 13)
	_info_hint.modulate = Color(1, 1, 1, 0.65)
	info_box.add_child(_info_hint)

	var hud = HudScript.new()
	add_child(hud)
	add_child(ReputationManager.new())
	_save = SaveManager.new()
	add_child(_save)
	_prompt_hud = PromptScript.new()
	add_child(_prompt_hud)

	avatar.prompt_changed.connect(_prompt_hud.set_prompt)
	_save.message.connect(_prompt_hud.show_message)
	_save.load_requested.connect(load_game, CONNECT_DEFERRED)
	_save.setup(avatar, HudScript.GAME_VERSION)
	_menu = GameMenu.new()
	add_child(_menu)
	_menu.save_requested.connect(_save.save_manual)
	_menu.load_requested.connect(_save.load_latest)
	_death = DeathManager.new()
	add_child(_death)
	_death.load_requested.connect(load_game)
	_death.new_game_requested.connect(func(): _new_game(0))
	hud.sheet_toggled.connect(func(open: bool): avatar.input_enabled = not open)

	GameTime.minute_changed.connect(func(_h: int, _m: int): _refresh_info())
	GameTime.phase_changed.connect(func(_p: String): _refresh_info())
	_add_vignette()
	_night = NightLights.new()
	add_child(_night)
	PlayerState.player_died.connect(func(): print("Il giocatore è morto"))
	_new_game(0)

# Carica un salvataggio: rigenera il mondo con lo stesso seed e poi riapplica lo stato (Feature 23).
func load_game(data: Dictionary) -> void:
	_new_game(int(data.get("seed", 0)))
	SaveSystem.apply(data, avatar)
	_refresh_info()

func _new_game(forced_seed: int) -> void:
	WorldSeed.new_game(forced_seed)
	GameTime.reset()
	PlayerState.new_character()
	DialogueState.reset()
	BuildingActions.reset()
	PropertySystem.reset()
	town = TownGenerator.generate(_town_cfg)

	var origin := Vector2(town["origin"][0], town["origin"][1])
	var hw: float = _world_cfg["half_width"]
	var hh: float = _world_cfg["half_height"]
	bounds = Rect2(origin.x - hw, origin.y - hh, hw * 2.0, hh * 2.0)
	if _map != null:
		_map.queue_free()
	_map = MapView.new()
	add_child(_map)
	_map.build(bounds, town)

	_build_town_nodes()
	_night.setup(_buildings.buildings, avatar)
	avatar.setup(bounds, origin)
	_refresh_info()

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
	var quest_avoid: Array[Rect2] = rects.duplicate()
	quest_avoid.append_array(_map.avoid_rects)
	_quests.setup(avatar, bounds, Vector2(town["origin"][0], town["origin"][1]), quest_avoid)

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
	avoid.append_array(_map.avoid_rects)
	_jobs.set_world(_buildings.buildings, bounds, avoid)

	_gangs = GangManager.new()
	_town_root.add_child(_gangs)
	_gangs.message.connect(_prompt_hud.show_message)
	_gangs.setup(avatar, Vector2(town["origin"][0], town["origin"][1]), _combat)
	_gangs.set_world(bounds, avoid)

	_crime = CrimeManager.new()
	_town_root.add_child(_crime)
	_crime.message.connect(_prompt_hud.show_message)
	_crime.setup(avatar, Vector2(town["origin"][0], town["origin"][1]), _combat)

	_law = LawManager.new()
	_town_root.add_child(_law)
	_law.message.connect(_prompt_hud.show_message)
	_law.setup(avatar, Vector2(town["origin"][0], town["origin"][1]), _combat, _buildings)

	_events = EventManager.new()
	_town_root.add_child(_events)
	_events.message.connect(_prompt_hud.show_message)
	_events.setup(avatar, Vector2(town["origin"][0], town["origin"][1]), _combat, _duels)

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
	# Il colore ambientale cambia solo quando l'ora cambia (non mentre il tempo è fermo).
	var h := GameTime.hour_float
	if h != _last_light_hour:
		_last_light_hour = h
		_modulate.color = GameTime.get_light_color()


# Riga informativa in basso a sinistra: si aggiorna solo quando cambia qualcosa (minuto, fase, velocità).
func _refresh_info() -> void:
	if _info == null:
		return
	var extra := ""
	if GameTime.paused:
		extra = "  ·  PAUSA"
	elif GameTime.time_scale != 1.0:
		extra = "  ·  x%.0f" % GameTime.time_scale
	_info.text = "%s  ·  Giorno %d  ·  %s (%s)%s" % [
		town.get("name", "?"), GameTime.day, GameTime.get_time_string(), GameTime.phase, extra]
	_info_hint.text = "seed %d  ·  F1 menu  ·  F5 salva  ·  F6 carica" % WorldSeed.world_seed

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
	_refresh_info()

# Vignettatura a tutto schermo (livello sotto HUD e pannelli, non toccata da CanvasModulate).
func _add_vignette() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = VIGNETTE_SHADER
	mat.set_shader_parameter("strength", float(WesternTheme.config()["shader"]["vignette"]) + 0.1)
	rect.material = mat
	layer.add_child(rect)
