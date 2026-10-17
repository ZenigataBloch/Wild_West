class_name DeathManager
extends Node
## Schermata di morte (Feature 25). Quando la salute arriva a 0 (ferite, lavori pericolosi, eventi,
## crimini, duelli) il gioco si ferma e si sceglie: caricare l'ultimo salvataggio o ricominciare.
## Lo svenimento in combattimento o per dissanguamento non passa di qui (non è morte).

signal load_requested(data: Dictionary)
signal new_game_requested

var _layer: CanvasLayer
var _title: Label
var _body: Label
var _load_btn: Button
var _open: bool = false
var _paused_by_me: bool = false


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	_layer.visible = false
	add_child(_layer)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.1, 0.0, 0.0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(center)
	WesternTheme.apply(center)

	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(460, 0)
	box.add_theme_constant_override("separation", 14)
	center.add_child(box)

	_title = Label.new()
	_title.text = "SEI MORTO"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 54)
	_title.add_theme_color_override("font_color", WesternTheme.color("blood").lightened(0.25))
	box.add_child(_title)

	_body = Label.new()
	_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.add_theme_font_size_override("font_size", 20)
	_body.add_theme_color_override("font_color", WesternTheme.color("parchment"))
	box.add_child(_body)

	_load_btn = Button.new()
	_load_btn.pressed.connect(_on_load)
	box.add_child(_load_btn)

	var new_btn := Button.new()
	new_btn.text = "Nuova partita"
	new_btn.pressed.connect(_on_new)
	box.add_child(new_btn)

	PlayerState.player_died.connect(_on_died)


func _on_died() -> void:
	if _open:
		return
	_open = true
	var h := float(GameTime.hour_float)
	_body.text = "%s è caduto al giorno %d, alle %02d:%02d, con $%d in tasca.\n\nIl Far West non fa sconti." % [
		PlayerState.player_name, int(GameTime.day), int(h), int((h - int(h)) * 60.0), PlayerState.money]
	var saved := SaveSystem.newest()
	_load_btn.disabled = saved.is_empty()
	_load_btn.text = "Carica l'ultimo salvataggio (%s)" % SaveSystem.describe(saved) if not saved.is_empty() \
		else "Carica l'ultimo salvataggio (nessuno)"
	_layer.visible = true
	_paused_by_me = not get_tree().paused
	get_tree().paused = true
	if not _load_btn.disabled:
		_load_btn.grab_focus()


func _close() -> void:
	_open = false
	_layer.visible = false
	if _paused_by_me:
		get_tree().paused = false
	_paused_by_me = false


func _on_load() -> void:
	var data := SaveSystem.newest()
	if data.is_empty():
		return
	_close()
	load_requested.emit(data)


func _on_new() -> void:
	_close()
	new_game_requested.emit()
