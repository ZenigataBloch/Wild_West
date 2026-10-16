extends CanvasLayer
## HUD del giocatore (nome, salute, soldi) e scheda personaggio (statistiche + inventario).
## Aspetto provvisorio con nodi Control standard: lo stile western arriva con la Feature 4.
## Tasto I = apri/chiudi scheda, Esc = chiudi. Doppio click su un oggetto = usalo.

signal sheet_toggled(open: bool)

var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _money_label: Label
var _sheet: CenterContainer
var _sheet_title: Label
var _stats_box: GridContainer
var _inv_title: Label
var _inv_list: ItemList

func _ready() -> void:
	layer = 10
	_build_hud()
	_build_sheet()
	PlayerState.name_changed.connect(_refresh_hud.unbind(1))
	PlayerState.health_changed.connect(_refresh_hud.unbind(2))
	PlayerState.money_changed.connect(_refresh_hud.unbind(1))
	PlayerState.stats_changed.connect(_refresh_stats)
	PlayerState.inventory_changed.connect(_refresh_inventory)
	_refresh_hud()
	_refresh_stats()
	_refresh_inventory()

func _build_hud() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(16, 12)
	add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(240, 0)
	panel.add_child(box)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", 20)
	box.add_child(_name_label)

	_hp_bar = ProgressBar.new()
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(0, 18)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("#b3261e")
	_hp_bar.add_theme_stylebox_override("fill", fill)
	box.add_child(_hp_bar)

	_hp_label = Label.new()
	box.add_child(_hp_label)
	_money_label = Label.new()
	box.add_child(_money_label)

	var hint := Label.new()
	hint.text = "[I] Scheda personaggio"
	hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(hint)

func _build_sheet() -> void:
	_sheet = CenterContainer.new()
	_sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	_sheet.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sheet.visible = false
	add_child(_sheet)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	_sheet.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	_sheet_title = Label.new()
	_sheet_title.add_theme_font_size_override("font_size", 24)
	box.add_child(_sheet_title)
	box.add_child(HSeparator.new())

	var stats_title := Label.new()
	stats_title.text = "Statistiche"
	box.add_child(stats_title)
	_stats_box = GridContainer.new()
	_stats_box.columns = 2
	_stats_box.add_theme_constant_override("h_separation", 40)
	box.add_child(_stats_box)
	box.add_child(HSeparator.new())

	_inv_title = Label.new()
	box.add_child(_inv_title)
	_inv_list = ItemList.new()
	_inv_list.custom_minimum_size = Vector2(0, 220)
	_inv_list.item_activated.connect(_on_item_activated)
	box.add_child(_inv_list)

func _unhandled_key_input(e: InputEvent) -> void:
	if not e.pressed or e.echo:
		return
	if e.keycode == KEY_I:
		_set_sheet(not _sheet.visible)
	elif e.keycode == KEY_ESCAPE and _sheet.visible:
		_set_sheet(false)

func _set_sheet(open: bool) -> void:
	_sheet.visible = open
	sheet_toggled.emit(open)

func _refresh_hud() -> void:
	_name_label.text = PlayerState.player_name
	_hp_bar.max_value = PlayerState.max_health
	_hp_bar.value = PlayerState.health
	_hp_label.text = "Salute %d / %d" % [PlayerState.health, PlayerState.max_health]
	_money_label.text = "$ %d" % PlayerState.money
	_sheet_title.text = PlayerState.player_name

func _refresh_stats() -> void:
	for c in _stats_box.get_children():
		c.queue_free()
	for key in PlayerState.stats:
		var l := Label.new()
		l.text = PlayerState.get_stat_label(key)
		_stats_box.add_child(l)
		var v := Label.new()
		v.text = "%d / %d" % [PlayerState.get_stat(key), PlayerState.stat_max]
		_stats_box.add_child(v)

func _refresh_inventory() -> void:
	_inv_list.clear()
	for slot in PlayerState.inventory:
		var d := ItemDB.get_item(slot["id"])
		var idx := _inv_list.add_item("%s  x%d" % [d.get("name", slot["id"]), slot["qty"]])
		_inv_list.set_item_metadata(idx, slot["id"])
		_inv_list.set_item_tooltip(idx, String(d.get("description", "")))
	_inv_title.text = "Zaino (%d/%d) - doppio click per usare" % [
		PlayerState.inventory.size(), PlayerState.get_slot_limit()]

func _on_item_activated(index: int) -> void:
	PlayerState.use_item(String(_inv_list.get_item_metadata(index)))
