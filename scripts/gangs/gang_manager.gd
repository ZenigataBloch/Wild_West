class_name GangManager
extends Node
## Gestisce le bande nel mondo (Feature 19): rifugi e territori, giorni che passano,
## pattuglie e incontri, scontri con CombatManager, pannello N.
##
## Uso in world.gd (vedi recap.md):
## (già collegato in world.gd, dentro _build_town_nodes()):
##   setup(avatar, origin, _combat) e set_world(bounds, avoid); si apre con N.

signal message(text: String)

const PANEL_KEY := KEY_N
## Segnali di fine scontro che CombatManager potrebbe avere (si usa il primo trovato).
const COMBAT_END_SIGNALS := ["encounter_finished", "combat_finished", "combat_ended", "encounter_ended", "finished"]

var _avatar: Node2D = null
var _origin: Vector2 = Vector2.ZERO
var _combat: Node = null

var _layer: CanvasLayer = null
var _panel: GangPanel = null
var _enc_panel: GangEncounterPanel = null

var _views: Dictionary = {}
var _view_version: int = -1

var _timer: float = 0.0
var _patrol_timer: float = 0.0
var _cooldown: float = 0.0
var _inside_id: String = ""

var _pending_combat: Dictionary = {}   # scontro da avviare alla chiusura dell'incontro
var _pending: Dictionary = {}          # scontro in corso
var _awaiting_end: bool = false
var _saw_pause: bool = false
var _await_time: float = 0.0


func _init() -> void:
	# deve girare anche in pausa per accorgersi della fine di uno scontro
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(avatar: Node2D, origin: Vector2, combat: Node) -> void:
	_avatar = avatar
	_origin = origin
	_combat = combat
	if _layer == null:
		_layer = CanvasLayer.new()
		_layer.layer = 30
		add_child(_layer)
		_panel = GangPanel.new()
		_panel.closed.connect(_on_panel_closed)
		_layer.add_child(_panel)
		_enc_panel = GangEncounterPanel.new()
		_enc_panel.option_chosen.connect(_on_option)
		_enc_panel.closed.connect(_on_encounter_closed)
		_layer.add_child(_enc_panel)


## Crea (o ricrea, per una nuova partita) le bande in base al seed.
## limiti: Rect2 dell'area di gioco; evitare: lista di Rect2 (strada e lotti della città).
func set_world(limiti: Variant, evitare: Array = []) -> void:
	var b := Rect2()
	if limiti is Rect2:
		b = limiti as Rect2
	GangSystem.generate(_origin, b, evitare, int(GameTime.day))
	_inside_id = ""
	_cooldown = 0.0
	_pending_combat = {}
	_pending = {}
	_awaiting_end = false
	_view_version = -1
	_rebuild_views()


func _process(delta: float) -> void:
	if get_tree().paused:
		if _awaiting_end:
			_saw_pause = true
		return
	if _awaiting_end:
		_await_time += delta
		if _saw_pause or _await_time > 30.0:
			_finish_pending("unknown")
	_cooldown = maxf(0.0, _cooldown - delta)
	_timer += delta
	if _timer < 0.5:
		return
	var dt: float = _timer
	_timer = 0.0
	_sync_days()
	if GangSystem.version != _view_version:
		_rebuild_views()
	if _avatar == null or not is_instance_valid(_avatar):
		return
	_check_territory(_avatar.global_position, dt)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or _panel == null:
		return
	if event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo and k.keycode == PANEL_KEY:
			_panel.open(_origin)
			get_tree().paused = true
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ giorni e grafica

func _sync_days() -> void:
	var lines: Array = GangSystem.advance_to(int(GameTime.day))
	if lines.is_empty():
		return
	# a schermo solo le ultime due notizie, tutte restano nel pannello N
	var start: int = maxi(0, lines.size() - 2)
	for i in range(start, lines.size()):
		message.emit(str(lines[i]))


func _rebuild_views() -> void:
	for id in _views.keys():
		var old: Node = _views[id]
		if is_instance_valid(old):
			old.queue_free()
	_views = {}
	for g in GangSystem.gangs:
		var view := GangTerritoryView.new()
		add_child(view)
		view.global_position = g["hideout"]
		view.setup(g)
		_views[str(g["id"])] = view
	_view_version = GangSystem.version


# ------------------------------------------------------------------ territori e pattuglie

func _check_territory(pos: Vector2, dt: float) -> void:
	if pos.distance_to(_origin) < GangDB.num("patrol", "town_safe_radius", 900.0):
		_inside_id = ""
		return
	var g: Dictionary = GangSystem.gang_at(pos)
	var gid: String = ""
	if not g.is_empty():
		gid = str(g["id"])
	if gid != _inside_id:
		if _inside_id != "":
			var old: Dictionary = GangSystem.by_id(_inside_id)
			if not old.is_empty():
				message.emit(GangDB.fmt("leave_territory", {"gang": old["name"]}))
		_inside_id = gid
		_patrol_timer = 0.0
		if gid != "":
			GangSystem.discover(g)
			message.emit(GangDB.fmt("enter", {"gang": g["name"], "stance": GangSystem.stance_label(g)}))
	if gid == "" or _cooldown > 0.0 or not GangSystem.can_patrol(g):
		return
	if GangSystem.in_core(g, pos):
		_trigger(g)
		return
	_patrol_timer += dt
	if _patrol_timer < GangDB.num("patrol", "check_seconds", 6.0):
		return
	_patrol_timer = 0.0
	var chances: Dictionary = GangDB.section("patrol").get("chance", {})
	var chance: float = float(chances.get(GangSystem.stance(g), 0.0))
	if randf() < chance:
		_trigger(g)


func _trigger(g: Dictionary) -> void:
	GangSystem.note_encounter(g)
	_cooldown = GangDB.num("patrol", "cooldown_seconds", 90.0)
	_enc_panel.open_encounter(str(g["id"]))
	get_tree().paused = true


# ------------------------------------------------------------------ incontri

func _on_option(gang_id: String, option_id: String) -> void:
	var res: Dictionary = GangSystem.resolve(gang_id, option_id)
	var text: String = "\n".join(PackedStringArray(res["lines"]))
	if bool(res["close"]):
		_pending_combat = res["combat"]
		_enc_panel.show_result(text)
	else:
		_enc_panel.show_notice(text, GangSystem.options_for(gang_id))


func _on_encounter_closed() -> void:
	get_tree().paused = false
	_view_version = -1
	if _pending_combat.is_empty():
		return
	var info: Dictionary = _pending_combat
	_pending_combat = {}
	_start_combat(info)


func _on_panel_closed() -> void:
	get_tree().paused = false


# ------------------------------------------------------------------ scontri

func _start_combat(info: Dictionary) -> void:
	if _combat == null or not _combat.has_method("start_encounter"):
		message.emit(GangDB.text("no_combat"))
		return
	_pending = info
	_awaiting_end = true
	_saw_pause = false
	_await_time = 0.0
	_hook_combat_end()
	_combat.call("start_encounter", info["enemies"], str(info["title"]), bool(info["ambush"]))


## Si aggancia al segnale di fine scontro di CombatManager, se ne ha uno.
## Altrimenti l'esito resta "unknown" (vedi recap.md, assunzioni da verificare).
func _hook_combat_end() -> void:
	for sig in COMBAT_END_SIGNALS:
		if _combat.has_signal(sig) and not _combat.is_connected(sig, _on_combat_signal):
			_combat.connect(sig, _on_combat_signal, CONNECT_ONE_SHOT)


func _on_combat_signal(a: Variant = null, b: Variant = null, c: Variant = null) -> void:
	if _pending.is_empty():
		return
	_finish_pending(_parse_outcome([a, b, c]))


func _parse_outcome(values: Array) -> String:
	for v in values:
		if v is bool:
			return "won" if v else "lost"
		var s: String = ""
		if v is String:
			s = (v as String).to_lower()
		elif v is Dictionary:
			s = str((v as Dictionary).get("result", (v as Dictionary).get("outcome", ""))).to_lower()
		if s in ["victory", "win", "won", "vittoria"]:
			return "won"
		if s in ["defeat", "lost", "loss", "sconfitta"]:
			return "lost"
		if s in ["flee", "fled", "fuga"]:
			return "fled"
	return "unknown"


func _finish_pending(outcome: String) -> void:
	if _pending.is_empty():
		return
	var info: Dictionary = _pending
	_pending = {}
	_awaiting_end = false
	var lines: Array = GangSystem.on_clash(str(info["gang"]), outcome, info["enemies"], str(info.get("ally", "")))
	for l in lines:
		message.emit(str(l))
	_cooldown = GangDB.num("patrol", "cooldown_seconds", 90.0)
	_view_version = -1
