class_name WoundManager
extends Node
## Fa scorrere il tempo per le ferite del giocatore: a ogni ora di gioco applica sanguinamento e
## guarigione (WoundSystem.tick_hour), anche se il tempo salta in avanti (dormire, svenire).
## Se il sanguinamento porta la salute a 1 il giocatore sviene: si risveglia in città al mattino,
## fasciato da qualcuno, con metà dei soldi in meno (stessi valori della sconfitta in combattimento).
## Uso:  var wm := WoundManager.new(); add_child(wm)
##       wm.message.connect(prompt_hud.show_message)
##       wm.setup(avatar, centro_citta)

signal message(text: String)

const MAX_STEPS := 72   # al massimo 3 giorni di ore processate in un colpo solo

var avatar: CharacterBody2D
var origin := Vector2.ZERO

var _last_index := 0


func setup(p_avatar: CharacterBody2D, p_origin: Vector2) -> void:
	avatar = p_avatar
	origin = p_origin
	_last_index = _hour_index()
	if not PlayerState.wound_message.is_connected(_on_wound_message):
		PlayerState.wound_message.connect(_on_wound_message)


func _hour_index() -> int:
	return GameTime.day * 24 + int(GameTime.hour_float)


func _on_wound_message(text: String) -> void:
	message.emit(text)


func _process(_delta: float) -> void:
	var now := _hour_index()
	if now < _last_index:   # nuova partita: l'orologio è tornato indietro
		_last_index = now
		return
	if now == _last_index or int(PlayerState.health) <= 0:
		return
	var steps := mini(now - _last_index, MAX_STEPS)
	_last_index = now

	var msgs: Array = []
	var bleed_total := 0
	for _i in steps:
		var r := WoundSystem.tick_hour()
		bleed_total += int(r["bleed"])
		msgs.append_array(r["msgs"])
		if bool(r["fainted"]):
			msgs.append(_faint())
			bleed_total = 0
			break
	if bleed_total > 0:
		msgs.insert(0, "Stai sanguinando: -%d salute." % bleed_total)
		if int(PlayerState.health) <= int(WoundSystem.num("low_health_warning", 20.0)):
			msgs.append("Stai perdendo troppo sangue! Fasciati subito (tasto I, doppio click sulle bende).")
	if not msgs.is_empty():
		message.emit("\n".join(msgs))


func _faint() -> String:
	var text := "Perdi i sensi per il sangue perso... Qualcuno ti ha fasciato e portato in città."
	var lost := int(float(PlayerState.money) * CombatDB.num("lose_money_fraction", 0.5))
	if lost > 0:
		PlayerState.spend_money(lost)
		text += "\nPerdi $%d." % lost
	var min_hp := int(CombatDB.num("lose_hp", 10.0))
	if int(PlayerState.health) < min_hp:
		PlayerState.heal(min_hp - int(PlayerState.health))
	WoundSystem.bandage_all(true)
	if avatar != null:
		avatar.global_position = origin
	GameTime.skip_to_hour(int(CombatDB.num("wake_hour", 7.0)))
	_last_index = _hour_index()   # le ore passate da svenuto non contano
	return text
