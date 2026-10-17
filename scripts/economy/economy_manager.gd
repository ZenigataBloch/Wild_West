class_name EconomyManager
extends Node
## Fa scorrere i giorni di mercato (EconomySystem) e apre il pannello del mercato con il tasto M
## (gioco in pausa mentre è aperto). Creato da world.gd: setup() poi message -> HUD.

signal message(text: String)

@export var pause_game_while_open: bool = true

var _panel: MarketPanel


func setup() -> void:
	EconomySystem.reset()
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)
	_panel = MarketPanel.new()
	_panel.title = " "
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false
	layer.add_child(_panel)
	_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.exit_requested.connect(func(): _panel.close())
	_panel.closed.connect(func():
		if pause_game_while_open:
			get_tree().paused = false)


func _process(_delta: float) -> void:
	var day := int(GameTime.day)
	if day != EconomySystem.last_day:
		var msgs := EconomySystem.advance_to(day)
		if not msgs.is_empty():
			message.emit("\n".join(msgs))


func _unhandled_key_input(e: InputEvent) -> void:
	if not e.pressed or e.echo or e.keycode != KEY_M or _panel == null:
		return
	if _panel.visible:
		_panel.close()
	elif not get_tree().paused:
		_panel.setup()
		_panel.open()
		if pause_game_while_open:
			get_tree().paused = true
