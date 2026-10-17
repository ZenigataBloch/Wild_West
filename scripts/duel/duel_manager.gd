class_name DuelManager
extends Node
## Gestisce le sfide: crea il DuelSystem, apre la schermata del duello, mette il gioco in pausa
## e applica gli esiti. Va creato da world.gd (come gli altri manager).
##
## API:
##   challenge_npc(npc_id)    uno specifico cittadino sfida il giocatore
##   challenge_stranger()     un pistolero di passaggio sfida il giocatore
##   setup(avatar, origin)    come gli altri manager: le sfide casuali scattano solo in città
## Debug: tasto T = sfida di un pistolero.

signal duel_started(opponent: Dictionary)
signal duel_finished(result: Dictionary)
signal message(text: String)

var town_center: Vector2 = Vector2.ZERO
var town_radius: float = 600.0
var _avatar: Node2D

var _active: bool = false
var _layer: CanvasLayer
var _panel: DuelPanel
var _count: int = 0
var _check: float = 0.0
var _rolled_day: int = -1
var _cooldown_until_day: int = 0


func setup(avatar: Node2D, origin: Vector2) -> void:
	_avatar = avatar
	town_center = origin
	town_radius = float(DuelDB.section("random_challenge").get("town_radius", 600.0))


func _exit_tree() -> void:
	# Se la partita viene riavviata durante un duello, non lasciare il gioco in pausa.
	if _active:
		_active = false
		if is_inside_tree():
			get_tree().paused = false


# ----------------------------------------------------------------- sfide

func challenge_npc(npc_id: String) -> bool:
	var npc = NPCRegistry.get_npc(npc_id)
	if not (npc is Dictionary) or npc.is_empty():
		return false
	var opp := DuelSystem.from_npc(npc)
	if opp.is_empty():
		return false
	return _start(opp)


func challenge_stranger() -> bool:
	_count += 1
	var rng := WorldSeed.rng_for("duel_stranger_%d" % _count)
	return _start(DuelSystem.make_stranger(rng))


## "inside" nel registro NPC può essere bool, testo (edificio) o numero: vero se l'NPC è dentro.
func _is_inside(v) -> bool:
	if v is bool:
		return v
	if v is String or v is StringName:
		return str(v) != ""
	if v is int or v is float:
		return v != 0
	return v != null


func _sheriff_present(exclude_id: String) -> bool:
	for job in ["sceriffo", "Sceriffo"]:
		var list = NPCRegistry.by_job(job)
		if list is Array:
			for n in list:
				if n is Dictionary and str(n.get("id", "")) != exclude_id and not _is_inside(n.get("inside", false)):
					return true
			if not list.is_empty():
				return false
	return false


## Pubblico: i cittadini che sono davvero in strada vicino al giocatore (non dentro un edificio,
## sfidante escluso), più qualche passante di passaggio e, a mezzogiorno, i curiosi accorsi.
func _audience_size(rng: RandomNumberGenerator, exclude_id: String = "") -> int:
	var c: Dictionary = DuelDB.section("audience")
	var radius := float(c.get("street_radius", 500.0))
	var centre := town_center
	if _avatar != null and is_instance_valid(_avatar):
		centre = _avatar.global_position
	var n := 0
	for npc in NPCRegistry.npcs:
		if str(npc.get("id", "")) == exclude_id or _is_inside(npc.get("inside", false)):
			continue
		var pos = npc.get("position", null)
		if pos is Vector2 and (pos as Vector2).distance_to(centre) <= radius:
			n += 1
	n += rng.randi_range(int(c.get("passers_min", 0)), int(c.get("passers_max", 2)))
	var win: Array = c.get("noon_window", [11, 14])
	if "hour" in GameTime:
		var hr := float(GameTime.hour)
		if hr >= float(win[0]) and hr < float(win[1]):
			n += int(c.get("noon_bonus", 2))
	return n


func _start(opp: Dictionary) -> bool:
	if _active or get_tree().paused:
		return false
	_count += 1
	var rng := WorldSeed.rng_for("duel_%d" % _count)
	var stake := DuelSystem.suggest_stake(int(opp.get("fame", 2)), int(PlayerState.money))
	var sys := DuelSystem.new()
	sys.setup(opp, stake, _audience_size(rng, str(opp.get("npc_id", ""))), _sheriff_present(str(opp.get("npc_id", ""))), rng)

	_active = true
	get_tree().paused = true
	_layer = CanvasLayer.new()
	_layer.layer = 60
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)
	_panel = DuelPanel.new()
	_panel.setup(sys)
	_panel.finished.connect(_on_finished)
	_layer.add_child(_panel)
	duel_started.emit(opp)
	return true


func _on_finished(result: Dictionary) -> void:
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = null
	_panel = null
	_active = false
	get_tree().paused = false
	var lines: Array = result.get("lines", [])
	if not lines.is_empty():
		message.emit(str(lines[0]))
	duel_finished.emit(result)


# ------------------------------------------------------- sfide casuali a mezzogiorno

func _process(delta: float) -> void:
	_check += delta
	if _check < 2.0:
		return
	_check = 0.0
	if _active or get_tree().paused:
		return
	var rc: Dictionary = DuelDB.section("random_challenge")
	if not bool(rc.get("enabled", true)) or not ("hour" in GameTime) or not ("day" in GameTime):
		return
	var day := int(GameTime.day)
	var hr := float(GameTime.hour)
	var noon := float(DuelDB.value("noon_hour", 12))
	if hr < noon or hr >= noon + 2.0 or day == _rolled_day or day < _cooldown_until_day:
		return
	if _avatar == null or not is_instance_valid(_avatar):
		return
	if _avatar.global_position.distance_to(town_center) > town_radius:
		return
	_rolled_day = day
	var fame := _player_fame()
	if fame < float(rc.get("min_fame", 15)):
		return
	var chance := float(rc.get("base_chance", 0.15)) + fame / 100.0 * float(rc.get("fame_chance", 0.5))
	var rng := WorldSeed.rng_for("duel_roll_%d" % day)
	if rng.randf() < chance:
		_cooldown_until_day = day + int(rc.get("cooldown_days", 3))
		challenge_stranger()


## Fama del giocatore: la reputazione più marcata tra cittadini, gang e legge.
func _player_fame() -> float:
	var best := 0.0
	for g in ["cittadini", "gang", "legge"]:
		best = maxf(best, absf(float(ReputationSystem.value(g))))
	return best


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_T:
		if challenge_stranger():
			get_viewport().set_input_as_handled()
