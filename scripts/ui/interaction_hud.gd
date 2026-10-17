extends CanvasLayer
## Suggerimento di interazione ("[E] ...") e messaggi temporanei in basso al centro.
## I messaggi stanno su una targa di legno (WesternTheme) con dissolvenza in entrata e in uscita.

var _prompt: Label
var _toast_panel: PanelContainer
var _toast: Label
var _timer: Timer
var _fade: Tween

func _ready() -> void:
	layer = 9
	var box := VBoxContainer.new()
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_top = -70.0
	box.offset_bottom = -70.0
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	_toast_panel = PanelContainer.new()
	WesternTheme.apply(_toast_panel)
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(_toast_panel)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override("font_size", 19)
	_toast_panel.add_child(_toast)
	_prompt = _make_label(22)
	_prompt.modulate = Color("#ffe08a")
	box.add_child(_prompt)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_hide_toast)
	add_child(_timer)

func _make_label(size: int) -> Label:
	var l := Label.new()
	l.visible = false
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	return l

func set_prompt(text: String) -> void:
	_prompt.text = text
	_prompt.visible = text != ""

func show_message(text: String, seconds: float = 3.5) -> void:
	if text == "":
		_toast_panel.visible = false
		return
	_toast.text = text
	_toast_panel.visible = true
	if _fade != null:
		_fade.kill()
	_toast_panel.modulate.a = 0.0
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(_toast_panel, "modulate:a", 1.0, 0.15)
	_timer.start(seconds)

func _hide_toast() -> void:
	if _fade != null:
		_fade.kill()
	_fade = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_fade.tween_property(_toast_panel, "modulate:a", 0.0, 0.35)
	_fade.tween_callback(func(): _toast_panel.visible = false)
