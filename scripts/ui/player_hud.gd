extends CanvasLayer
## HUD del giocatore (nome, salute, soldi) e scheda personaggio (statistiche + inventario).
## Aspetto provvisorio con nodi Control standard: lo stile western arriva con la Feature 4.
## Tasto I = apri/chiudi scheda, Esc = chiudi. Doppio click su un oggetto = usalo
## (cibo/medicine) oppure equipaggialo (armi, Feature 12; doppio click sull'arma in mano = la riponi).

signal sheet_toggled(open: bool)

var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _money_label: Label
var _weapon_label: Label
var _wound_label: Label
var _debt_label: Label
var _sheet: CenterContainer
var _sheet_title: Label
var _stats_box: GridContainer
var _sheet_weapon: Label
var _sheet_wounds: Label
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
	PlayerState.equipment_changed.connect(_refresh_inventory)
	PlayerState.equipment_changed.connect(_refresh_weapon)
	PlayerState.inventory_changed.connect(_refresh_weapon)
	PlayerState.wounds_changed.connect(_refresh_stats)
	PlayerState.wounds_changed.connect(_refresh_wounds)
	_refresh_hud()
	_refresh_stats()
	_refresh_inventory()
	_refresh_weapon()
	_refresh_wounds()
	# Il debito cambia anche senza movimenti di denaro (interessi, scadenze): lo aggiorniamo ogni secondo.
	var debt_timer := Timer.new()
	debt_timer.wait_time = 1.0
	debt_timer.autostart = true
	debt_timer.timeout.connect(_refresh_debt)
	add_child(debt_timer)
	_refresh_debt()

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
	_weapon_label = Label.new()
	box.add_child(_weapon_label)
	_wound_label = Label.new()
	box.add_child(_wound_label)
	_debt_label = Label.new()
	box.add_child(_debt_label)

	var hint := Label.new()
	hint.text = "[I] Scheda  [P] Reputazione  [Q] Missioni"
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

	_sheet_weapon = Label.new()
	_sheet_weapon.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sheet_weapon.custom_minimum_size = Vector2(488, 0)
	box.add_child(_sheet_weapon)
	_sheet_wounds = Label.new()
	_sheet_wounds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sheet_wounds.custom_minimum_size = Vector2(488, 0)
	box.add_child(_sheet_wounds)
	box.add_child(HSeparator.new())

	_inv_title = Label.new()
	box.add_child(_inv_title)
	_inv_list = ItemList.new()
	_inv_list.custom_minimum_size = Vector2(0, 150)
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

func _refresh_debt() -> void:
	var t := BankSystem.hud_text()
	_debt_label.visible = t != ""
	_debt_label.text = t
	if BankSystem.has_overdue():
		_debt_label.add_theme_color_override("font_color", Color(0.95, 0.4, 0.35))
	else:
		_debt_label.remove_theme_color_override("font_color")

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
		var cur := PlayerState.get_stat(key)
		var base := PlayerState.get_base_stat(key)
		v.text = "%d / %d" % [cur, PlayerState.stat_max]
		if cur < base:
			v.text += "  (ferite %+d)" % (cur - base)
			v.add_theme_color_override("font_color", Color("#e0654a"))
		_stats_box.add_child(v)

func _refresh_inventory() -> void:
	_inv_list.clear()
	var equipped := PlayerState.get_weapon()
	var marked := false
	for slot in PlayerState.inventory:
		var id := String(slot["id"])
		var d := ItemDB.get_item(id)
		var is_weapon := WeaponDB.is_weapon(id)
		var text := "%s  x%d" % [d.get("name", id), slot["qty"]]
		if is_weapon:
			text = "%s  [%s]" % [d.get("name", id), WeaponDB.rarity_label(id)]
			if id == equipped and not marked:
				text += "  (in mano)"
				marked = true
		var idx := _inv_list.add_item(text)
		_inv_list.set_item_metadata(idx, id)
		_inv_list.set_item_tooltip(idx, String(d.get("description", "")))
		if is_weapon:
			_inv_list.set_item_custom_fg_color(idx, WeaponDB.rarity_color(id))
	_inv_title.text = "Zaino (%d/%d) - doppio click per usare / equipaggiare" % [
		PlayerState.inventory.size(), PlayerState.get_slot_limit()]

func _refresh_weapon() -> void:
	var w := PlayerState.get_weapon()
	if w == "":
		_weapon_label.text = "Arma: a mani nude"
		_sheet_weapon.text = "Arma in mano: nessuna (pugni)"
		return
	_weapon_label.text = "Arma: %s" % WeaponDB.name_of(w)
	_sheet_weapon.text = "Arma in mano: %s\n%s" % [WeaponDB.name_of(w), WeaponDB.stats_text(w)]

func _refresh_wounds() -> void:
	var ws := WoundSystem.wounds
	if ws.is_empty():
		_wound_label.text = "Ferite: nessuna"
		_wound_label.modulate = Color.WHITE
		_sheet_wounds.text = "Ferite: nessuna"
		return
	var bleeding := WoundSystem.is_bleeding()
	_wound_label.text = "Ferite: %d%s" % [ws.size(), "  - stai sanguinando!" if bleeding else ""]
	_wound_label.modulate = Color("#ff7a6a") if bleeding else Color.WHITE
	var lines: Array[String] = ["Ferite:"]
	for w in ws:
		var pen := WoundSystem.penalty_text(w)
		lines.append("• %s — %s%s" % [WoundSystem.wound_name(w), WoundSystem.status_text(w), (" [%s]" % pen) if pen != "" else ""])
	_sheet_wounds.text = "\n".join(lines)

func _on_item_activated(index: int) -> void:
	var id := String(_inv_list.get_item_metadata(index))
	if WeaponDB.is_weapon(id):
		if id == PlayerState.get_weapon():
			PlayerState.unequip_weapon()
		else:
			PlayerState.equip_weapon(id)
		return
	PlayerState.use_item(id)
