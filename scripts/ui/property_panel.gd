class_name PropertyPanel
extends WesternPanel
## Pannello di un lotto (basato su WesternPanel), generato dallo stato di PropertySystem:
## lotto libero -> compra terreno / terreno + casa / terreno + negozio;
## terreno tuo -> costruisci casa o negozio, vendi; cantiere -> attesa e vendita;
## casa -> dormi gratis, ripostiglio, vendi; negozio -> cassa e incasso, vendi.
## In tutti i casi: tasse (e pagamento degli arretrati). La vendita chiede conferma.
## Va aggiunto all'albero con title != "" (es. " ") per riservare il banner.

signal exit_requested

var lot_id := -1

var _status: Label
var _money_label: Label
var _status_text := ""
var _confirm_sell := false
var _pop_pending := false


func setup(id: int) -> void:
	lot_id = id
	_status_text = ""
	_confirm_sell = false
	_build()


func _build() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	var st := PropertySystem.state_of(lot_id)
	var rec := PropertySystem.get_record(lot_id)
	var title_text := "Lotto %d" % lot_id
	if st != "free":
		title_text += " - " + PropertySystem.type_name(String(rec["kind"]))
	set_title(title_text)
	custom_minimum_size = Vector2(520, 0)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	add_child(vb)

	_text(vb, _describe(st, rec))
	vb.add_child(HSeparator.new())
	_money_row(vb)

	match st:
		"free":
			_build_free(vb)
		"terreno":
			_build_land(vb, rec)
		"building":
			_build_site(vb, rec)
		"casa":
			_build_house(vb, rec)
		"negozio":
			_build_shop(vb, rec)
	if not rec.is_empty():
		_dues_block(vb, rec)

	_status = Label.new()
	_status.text = _status_text
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(480, 0)
	_status.add_theme_color_override("font_color", WesternTheme.color("gold"))
	vb.add_child(_status)

	var exit_btn := Button.new()
	exit_btn.text = "Esci  [Esc]"
	exit_btn.pressed.connect(func(): exit_requested.emit())
	vb.add_child(exit_btn)
	reset_size()
	if _pop_pending:
		_pop_pending = false
		UIFx.pop(_money_label)


func _describe(st: String, rec: Dictionary) -> String:
	match st:
		"free":
			return "Un lotto libero sulla via principale, in vendita. Puoi comprare il solo terreno oppure farci costruire subito una casa o un negozio."
		"building":
			var kind := String(rec["kind"])
			return "Cantiere aperto: %s. %s" % [PropertySystem.type_name(kind), PropertySystem.text("build_wait", {
				"day": int(rec["ready_day"]), "left": PropertySystem.build_days_left(rec)})]
	return String(PropertySystem.type_def(String(rec["kind"])).get("desc", ""))


# --- Stati ---

func _build_free(vb: VBoxContainer) -> void:
	_text(vb, "Proprietà possedute: %d / %d.  Mercato immobili: %s." % [
		PropertySystem.owned.size(), PropertySystem.max_properties(), EconomySystem.pct_text(PropertySystem.good())])
	_button(vb, "Compra il terreno  —  $%d" % PropertySystem.buy_price(lot_id, "terreno"),
		_tax_tip("terreno"), func(): _act(PropertySystem.buy(lot_id, "terreno")))
	for kind in ["casa", "negozio"]:
		var def := PropertySystem.type_def(kind)
		var label := "Terreno + %s  —  $%d  (lavori: %d giorni)" % [
			kind, PropertySystem.buy_price(lot_id, kind), int(def.get("build_days", 1))]
		_button(vb, label, "%s\n%s" % [String(def.get("desc", "")), _tax_tip(kind)],
			func(): _act(PropertySystem.buy(lot_id, kind)))


func _build_land(vb: VBoxContainer, rec: Dictionary) -> void:
	_text(vb, "Investito finora: $%d.  Mercato immobili: %s." % [int(rec["invested"]), EconomySystem.pct_text(PropertySystem.good())])
	for kind in ["casa", "negozio"]:
		var def := PropertySystem.type_def(kind)
		var label := "Costruisci %s  —  $%d  (lavori: %d giorni)" % [
			kind, PropertySystem.build_price(kind), int(def.get("build_days", 1))]
		_button(vb, label, "%s\n%s" % [String(def.get("desc", "")), _tax_tip(kind)],
			func(): _act(PropertySystem.build(lot_id, kind)))
	_sell_button(vb, rec)


func _build_site(vb: VBoxContainer, rec: Dictionary) -> void:
	_text(vb, "Investito finora: $%d. Finché i lavori non finiscono non puoi usare l'edificio." % int(rec["invested"]))
	_sell_button(vb, rec)


func _build_house(vb: VBoxContainer, rec: Dictionary) -> void:
	_button(vb, "Dormi fino all'alba  (gratis)", "Salute piena e ferite fasciate.",
		func(): _act(PropertySystem.rest(lot_id)))
	vb.add_child(HSeparator.new())
	_stash_ui(vb)
	_sell_button(vb, rec)


func _build_shop(vb: VBoxContainer, rec: Dictionary) -> void:
	var till := int(rec["till"])
	_text(vb, "Cassa: $%d / $%d" % [till, PropertySystem.shop_till_cap()])
	_text(vb, "Ultimo giorno: incasso $%d, netto dopo il commesso $%d." % [int(rec["last_revenue"]), int(rec["last_net"])])
	var market := EconomySystem.pct_text(String(PropertySystem.section("shop").get("good", "merci")))
	_text(vb, "Previsione: circa $%d al giorno al netto di salario ($%d) e tasse. Mercato delle merci: %s." % [
		PropertySystem.shop_expected_net(), PropertySystem.shop_wage(), market])
	var take := _button(vb, "Ritira l'incasso  —  $%d" % till, "Quando la cassa è piena l'incasso in più va perso.",
		func(): _act(PropertySystem.collect_till(lot_id)))
	take.disabled = till <= 0
	_sell_button(vb, rec)


func _stash_ui(vb: VBoxContainer) -> void:
	var stash := PropertySystem.stash_of(lot_id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)

	var pack_box := VBoxContainer.new()
	pack_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(pack_box)
	var pack_title := Label.new()
	pack_title.text = "Zaino (%d/%d) - doppio click: riponi" % [PlayerState.inventory.size(), PlayerState.get_slot_limit()]
	pack_box.add_child(pack_title)
	var pack := ItemList.new()
	pack.custom_minimum_size = Vector2(240, 150)
	for slot in PlayerState.inventory:
		pack.add_item(_slot_text(String(slot["id"]), int(slot["qty"])))
	pack.item_activated.connect(func(i: int): _act(PropertySystem.stash_deposit(lot_id, i)))
	pack_box.add_child(pack)

	var stash_box := VBoxContainer.new()
	stash_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(stash_box)
	var stash_title := Label.new()
	stash_title.text = "Ripostiglio (%d/%d) - doppio click: riprendi" % [stash.size(), PropertySystem.stash_slots_max()]
	stash_box.add_child(stash_title)
	var store := ItemList.new()
	store.custom_minimum_size = Vector2(240, 150)
	for slot in stash:
		store.add_item(_slot_text(String(slot["id"]), int(slot["qty"])))
	store.item_activated.connect(func(i: int): _act(PropertySystem.stash_withdraw(lot_id, i)))
	stash_box.add_child(store)


func _slot_text(id: String, qty: int) -> String:
	if WeaponDB.is_weapon(id):
		return "%s  [%s]" % [WeaponDB.name_of(id), WeaponDB.rarity_label(id)]
	return "%s  x%d" % [str(ItemDB.get_item(id).get("name", id)), qty]


func _dues_block(vb: VBoxContainer, rec: Dictionary) -> void:
	vb.add_child(HSeparator.new())
	_text(vb, "Tasse: $%d al giorno, prelevate in automatico dalla cassa del negozio e dal conto in banca. Con troppi giorni di arretrato il comune pignora la proprietà." % PropertySystem.tax_of(rec))
	var dues := int(rec["dues"])
	if dues > 0:
		var warn := _text(vb, "Tasse arretrate: $%d  -  pignoramento fra %d giorni." % [dues, PropertySystem.days_to_seizure(rec)])
		warn.add_theme_color_override("font_color", Color(0.95, 0.45, 0.38))
		_button(vb, "Paga le tasse  —  $%d" % dues, "", func(): _act(PropertySystem.pay_dues(lot_id)))


func _sell_button(vb: VBoxContainer, rec: Dictionary) -> void:
	var value := PropertySystem.sell_value(rec) + int(rec["till"])
	if _confirm_sell:
		var sure := _button(vb, "Conferma la vendita  —  ricevi circa $%d" % value,
			"Le tasse arretrate vengono scalate dal ricavo.", func(): _act(PropertySystem.sell(lot_id)))
		sure.add_theme_color_override("font_color", Color(0.95, 0.5, 0.4))
	else:
		_button(vb, "Vendi  —  circa $%d" % value, "Valore investito x percentuale di vendita x mercato degli immobili.", func():
			_confirm_sell = true
			_status_text = ""
			_build.call_deferred())


# --- Azioni e utilità ---

## Esegue l'esito di un'azione: messaggio di stato, animazione e ricostruzione del pannello.
func _act(r: Dictionary) -> void:
	_confirm_sell = false
	_status_text = String(r.get("msg", ""))
	if bool(r.get("ok", false)):
		_pop_pending = true
	else:
		UIFx.shake(self)
	_build.call_deferred()


func _tax_tip(kind: String) -> String:
	return "Tassa: $%d al giorno." % int(PropertySystem.type_def(kind).get("tax", 0))


func _text(parent: Control, msg: String) -> Label:
	var l := Label.new()
	l.text = msg
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(480, 0)
	parent.add_child(l)
	return l


func _button(parent: Control, label: String, tip: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = label
	b.tooltip_text = tip
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _money_row(vb: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var coin := WesternIcon.new()
	coin.kind = WesternIcon.Kind.COIN
	row.add_child(coin)
	_money_label = Label.new()
	_money_label.text = "$%d" % PlayerState.money
	row.add_child(_money_label)
	vb.add_child(row)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		exit_requested.emit()
