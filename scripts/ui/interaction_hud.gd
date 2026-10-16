extends CanvasLayer
## Suggerimento di interazione ("[E] ...") e messaggi temporanei in basso al centro.

var _prompt: Label
var _toast: Label
var _timer: Timer

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

	_toast = _make_label(20)
	box.add_child(_toast)
	_prompt = _make_label(22)
	_prompt.modulate = Color("#ffe08a")
	box.add_child(_prompt)

	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(func(): _toast.visible = false)
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
	_toast.text = text
	_toast.visible = text != ""
	_timer.start(seconds)
