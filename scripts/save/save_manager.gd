class_name SaveManager
extends Node
## Comandi di salvataggio (Feature 23): F5 salva, F6 carica il salvataggio più recente,
## autosalvataggio a ogni nuovo giorno. Il caricamento vero lo fa World.load_game.

signal message(text: String)
signal load_requested(data: Dictionary)

var _avatar: Node2D
var _version: String = ""


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func setup(avatar: Node2D, game_version: String) -> void:
	_avatar = avatar
	_version = game_version
	GameTime.day_changed.connect(_on_day_changed)


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.pressed or e.echo:
		return
	if e.keycode == KEY_F5:
		save_manual()
		get_viewport().set_input_as_handled()
	elif e.keycode == KEY_F6:
		load_latest()
		get_viewport().set_input_as_handled()


func save_manual() -> void:
	if not _can_act():
		return
	var data := SaveSystem.capture(_avatar, _version)
	if SaveSystem.write(SaveSystem.MANUAL_PATH, data):
		message.emit("Partita salvata (%s)." % SaveSystem.describe(data))
	else:
		message.emit("Salvataggio non riuscito.")


func load_latest() -> void:
	if not _can_act():
		return
	var data := SaveSystem.newest()
	if data.is_empty():
		message.emit("Nessun salvataggio trovato (F5 per salvare).")
		return
	message.emit("Partita caricata (%s)." % SaveSystem.describe(data))
	load_requested.emit(data)


func _on_day_changed(_day: int) -> void:
	if not _can_act() or PlayerState.health <= 0:
		return
	SaveSystem.write(SaveSystem.AUTO_PATH, SaveSystem.capture(_avatar, _version))


# Niente salvataggi o caricamenti mentre un pannello ha messo il gioco in pausa.
func _can_act() -> bool:
	return _avatar != null and is_instance_valid(_avatar) and not get_tree().paused
