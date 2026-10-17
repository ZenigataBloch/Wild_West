class_name BankSection
extends VBoxContainer
## Parte bancaria del BuildingPanel (edifici con "bank_ui": true in buildings.json):
## deposito e ritiro, debiti aperti con pagamento, nuovi prestiti (durata + importo).
## Il contenuto sta in uno ScrollContainer per non uscire dallo schermo.
## BuildingPanel chiama refresh() dopo ogni azione; `result` porta l'esito al suo messaggio di stato.

signal result(msg: String, ok: bool)

var _term_idx := 1
var _scroll: ScrollContainer
var _body: VBoxContainer


func _init() -> void:
	add_theme_constant_override("separation", 6)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(450, 290)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)


func refresh() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	_build_account()
	_body.add_child(HSeparator.new())
	_build_debts()
	_build_new_loan()


# --- Conto ---

func _build_account() -> void:
	var info := Label.new()
	info.text = "Interesse sul conto: %s al giorno  -  guadagnati finora: $%d" % [_pct(BankSystem.deposit_rate()), BankSystem.interest_earned]
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(430, 0)
	_body.add_child(info)

	var quick: Array = BankSystem.section("deposit").get("quick_amounts", [10, 50, "all"])
	_body.add_child(_amount_row("Deposita", quick, PlayerState.money, func(a: int): _emit(BankSystem.deposit(a))))
	_body.add_child(_amount_row("Ritira", quick, BankSystem.balance, func(a: int): _emit(BankSystem.withdraw(a))))


func _amount_row(title: String, quick: Array, available: int, action: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(90, 0)
	row.add_child(l)
	for q in quick:
		var amount := available if str(q) == "all" else int(q)
		var b := Button.new()
		b.text = "Tutto ($%d)" % amount if str(q) == "all" else "$%d" % amount
		b.disabled = amount <= 0 or amount > available
		b.pressed.connect(action.bind(amount))
		row.add_child(b)
	return row


# --- Debiti ---

func _build_debts() -> void:
	if not BankSystem.has_debt():
		return
	var head := Label.new()
	head.theme_type_variation = &"TitleLabel"
	head.text = "I tuoi debiti"
	_body.add_child(head)
	var quick: Array = BankSystem.section("loans").get("repay_quick_amounts", [25, 100])
	for loan in BankSystem.loans:
		var l := Label.new()
		l.text = _loan_text(loan)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(430, 0)
		if String(loan["status"]) != "active":
			l.add_theme_color_override("font_color", Color(0.9, 0.4, 0.35))
		_body.add_child(l)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var id := int(loan["id"])
		for q in quick:
			var b := Button.new()
			b.text = "Paga $%d" % int(q)
			b.disabled = PlayerState.money <= 0
			b.pressed.connect(func(): _emit(BankSystem.repay(id, int(q))))
			row.add_child(b)
		var all := Button.new()
		all.text = "Estingui ($%d)" % int(loan["remaining"])
		all.disabled = PlayerState.money <= 0
		all.pressed.connect(func(): _emit(BankSystem.repay(id, int(loan["remaining"]))))
		row.add_child(all)
		_body.add_child(row)
	_body.add_child(HSeparator.new())


func _loan_text(loan: Dictionary) -> String:
	var s := "Prestito #%d: devi $%d" % [int(loan["id"]), int(loan["remaining"])]
	match String(loan["status"]):
		"active":
			var left := BankSystem.days_left(loan)
			s += " - scade fra %d giorni (giorno %d)" % [maxi(left, 0), int(loan["due_day"])]
		"overdue":
			s += " - SCADUTO da %d giorni, tasso doppio" % int(loan["overdue_days"])
		"default":
			s += " - INSOLVENZA: salda il debito"
	return s


# --- Nuovo prestito ---

func _build_new_loan() -> void:
	var head := Label.new()
	head.theme_type_variation = &"TitleLabel"
	head.text = "Nuovo prestito"
	_body.add_child(head)

	var reason := BankSystem.block_reason()
	if reason != "":
		var r := Label.new()
		r.text = reason
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size = Vector2(430, 0)
		_body.add_child(r)
		return

	var maxv := BankSystem.max_loan()
	var cap := Label.new()
	var guarantee := "il tuo conto in cassa fa da garanzia"
	if BankSystem.property_collateral() > 0:
		guarantee = "conto in cassa e proprietà fanno da garanzia"
	cap.text = "Puoi chiedere fino a $%d (%s)." % [maxv, guarantee]
	cap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap.custom_minimum_size = Vector2(430, 0)
	_body.add_child(cap)

	# Durata (con il tasso giornaliero di oggi)
	var terms := BankSystem.terms()
	_term_idx = clampi(_term_idx, 0, maxi(terms.size() - 1, 0))
	var group := ButtonGroup.new()
	var trow := HFlowContainer.new()
	trow.add_theme_constant_override("h_separation", 6)
	for i in terms.size():
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == _term_idx
		b.text = "%s (%s/g)" % [String(terms[i].get("label", "")), _pct(BankSystem.rate_for(terms[i]))]
		b.pressed.connect(func():
			_term_idx = i
			refresh.call_deferred())
		trow.add_child(b)
	_body.add_child(trow)

	# Importi
	var amounts: Array = BankSystem.section("loans").get("amounts", [])
	var offered: Array[int] = []
	for a in amounts:
		if int(a) <= maxv:
			offered.append(int(a))
	if not offered.has(maxv):
		offered.append(maxv)
	var arow := HFlowContainer.new()
	arow.add_theme_constant_override("h_separation", 6)
	arow.add_theme_constant_override("v_separation", 6)
	for a in offered:
		var q := BankSystem.quote(a, _term_idx)
		var b := Button.new()
		b.text = "Prendi $%d  >  ~$%d" % [a, int(q["owed"])]
		b.tooltip_text = "Ricevi $%d. Commissione $%d, tasso %s al giorno.\nDa restituire entro il giorno %d: circa $%d." % [
			a, int(q["fee"]), _pct(float(q["rate"])), int(q["due_day"]), int(q["owed"])]
		b.pressed.connect(func(): _emit(BankSystem.take_loan(a, _term_idx)))
		arow.add_child(b)
	_body.add_child(arow)


func _emit(r: Dictionary) -> void:
	result.emit(String(r.get("msg", "")), bool(r.get("ok", false)))


func _pct(rate: float) -> String:
	return "%.1f%%" % (rate * 100.0)
