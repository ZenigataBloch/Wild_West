class_name PropertySystem
extends RefCounted
## Sistema proprietà (Feature 18): terreno, casa e negozio sui lotti liberi della città. Dati in data/properties.json.
## - I lotti senza edificio sono in vendita. Prezzo = superficie x prezzo al mq, poi mercato degli immobili
##   (EconomySystem, bene "immobili") e reputazione presso i commercianti. Si compra il solo terreno oppure
##   terreno + costruzione; un terreno si può edificare in seguito. I lavori durano qualche giorno.
## - Casa: letto gratis (cura tutto e fascia le ferite) e ripostiglio sicuro con pochi slot.
## - Negozio: un commesso lavora per te. Ogni giorno entra un incasso (mercato delle merci, fama tra i
##   cittadini, Carisma) meno il salario; resta in cassa fino al ritiro (cassa limitata). Eventi: cliente ricco,
##   furto (meno grave se la legge ti stima), ispezione.
## - Tasse giornaliere per ogni proprietà: si pagano dalla cassa del negozio e dal conto in banca, il resto va
##   in arretrato. Con troppi giorni di arretrato il comune pignora la proprietà.
## - La banca accetta le proprietà come garanzia per i prestiti (BankSystem.max_loan) e, in caso di insolvenza,
##   ipoteca quella di maggior valore (`foreclose`).
## Tutto in memoria (il salvataggio arriverà più avanti). `advance_to(giorno)` la chiama PropertyManager.

const PATH := "res://data/properties.json"

static var _data: Dictionary = {}
static var lots: Dictionary = {}     # id lotto -> {id, side, rect}
static var owned: Dictionary = {}    # id lotto -> record
# record: {lot, kind, ready_day, invested, dues, arrears_days, till, stash, bought_day, last_revenue, last_net, warned}
static var last_day: int = 1
static var version: int = 0           # cresce a ogni cambiamento di stato (per aggiornare grafica e suggerimenti)


static func data() -> Dictionary:
	if _data.is_empty():
		var parsed = null
		if FileAccess.file_exists(PATH):
			parsed = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


static func section(name: String) -> Dictionary:
	return data().get(name, {})


static func text(key: String, vars: Dictionary = {}) -> String:
	return str(data().get("text", {}).get(key, "")).format(vars)


static func today() -> int:
	return int(GameTime.day)


static func _res(ok: bool, msg: String) -> Dictionary:
	return {"ok": ok, "msg": msg}


static func good() -> String:
	return str(data().get("good", "immobili"))


## Nuova partita: nessuna proprietà, nessun lotto registrato.
static func reset() -> void:
	lots.clear()
	owned.clear()
	last_day = today()
	version += 1


## Il PropertyManager registra ogni lotto libero della città.
static func register_lot(id: int, side: String, rect: Rect2) -> void:
	lots[id] = {"id": id, "side": side, "rect": rect}


# --- Tipi e stato ---

static func type_def(kind: String) -> Dictionary:
	return section("types").get(kind, {})


static func type_name(kind: String) -> String:
	return str(type_def(kind).get("name", kind.capitalize()))


static func get_record(lot_id: int) -> Dictionary:
	return owned.get(lot_id, {})


## Cantiere aperto: casa o negozio con i lavori ancora in corso.
static func is_building(rec: Dictionary) -> bool:
	return String(rec.get("kind", "terreno")) != "terreno" and int(rec.get("ready_day", 0)) > 0


static func is_built(rec: Dictionary) -> bool:
	return String(rec.get("kind", "terreno")) != "terreno" and int(rec.get("ready_day", 0)) == 0


## "free", "terreno", "building", "casa" o "negozio".
static func state_of(lot_id: int) -> String:
	if not owned.has(lot_id):
		return "free"
	var rec: Dictionary = owned[lot_id]
	if is_building(rec):
		return "building"
	return String(rec["kind"])


static func build_days_left(rec: Dictionary) -> int:
	return maxi(int(rec.get("ready_day", 0)) - today(), 0)


## Tassa giornaliera (un cantiere paga come un terreno).
static func tax_of(rec: Dictionary) -> int:
	if is_building(rec):
		return int(type_def("terreno").get("tax", 1))
	return int(type_def(String(rec.get("kind", "terreno"))).get("tax", 0))


# --- Prezzi ---

static func land_base(lot_id: int) -> int:
	var lot: Dictionary = lots.get(lot_id, {})
	if lot.is_empty():
		return 0
	var r: Rect2 = lot["rect"]
	var lc := section("land")
	var base := roundi(r.size.x * r.size.y / 1000.0 * float(lc.get("price_per_k", 2.6)))
	return maxi(base, int(lc.get("min_price", 90)))


static func land_price(lot_id: int) -> int:
	return EconomySystem.price(good(), land_base(lot_id))


static func build_price(kind: String) -> int:
	return EconomySystem.price(good(), int(type_def(kind).get("build_cost", 0)))


## Prezzo di acquisto di un lotto libero: solo terreno, oppure terreno + costruzione.
static func buy_price(lot_id: int, kind: String) -> int:
	if kind == "terreno":
		return land_price(lot_id)
	return land_price(lot_id) + build_price(kind)


## Quanto incassi vendendo (valore investito x percentuale x mercato), cassa del negozio esclusa.
static func sell_value(rec: Dictionary) -> int:
	var sc := section("sell")
	var mk := clampf(EconomySystem.index(good()), float(sc.get("market_min", 0.8)), float(sc.get("market_max", 1.2)))
	return roundi(float(rec.get("invested", 0)) * float(sc.get("ratio", 0.6)) * mk)


static func max_properties() -> int:
	return int(data().get("max_properties", 5))


# --- Acquisto, costruzione, vendita ---

static func _rep(key: String) -> void:
	var fx: Dictionary = section("reputation").get(key, {})
	for g in fx:
		ReputationSystem.add(String(g), int(fx[g]))


static func _new_record(lot_id: int, kind: String, invested: int) -> Dictionary:
	var rec := {
		"lot": lot_id, "kind": kind, "ready_day": 0, "invested": invested, "dues": 0, "arrears_days": 0,
		"till": 0, "stash": [], "bought_day": today(), "last_revenue": 0, "last_net": 0, "warned": false,
	}
	if kind != "terreno":
		rec["ready_day"] = today() + int(type_def(kind).get("build_days", 1))
	return rec


## Compra un lotto libero: kind = "terreno", "casa" o "negozio" (le ultime due includono la costruzione).
static func buy(lot_id: int, kind: String) -> Dictionary:
	if not lots.has(lot_id) or owned.has(lot_id):
		return _res(false, text("not_free"))
	if kind != "terreno" and type_def(kind).is_empty():
		return _res(false, text("unknown_type"))
	if owned.size() >= max_properties():
		return _res(false, text("too_many", {"max": max_properties()}))
	var price := buy_price(lot_id, kind)
	if PlayerState.money < price or not PlayerState.spend_money(price):
		return _res(false, text("no_money", {"price": price}))
	var first := owned.is_empty()
	var rec := _new_record(lot_id, kind, price)
	owned[lot_id] = rec
	EconomySystem.on_purchase(good(), 1 if kind == "terreno" else 2)
	if first:
		_rep("first_property")
	version += 1
	if kind == "terreno":
		return _res(true, text("bought_land", {"lot": lot_id, "price": price}))
	return _res(true, text("bought_build", {"lot": lot_id, "name": type_name(kind), "day": int(rec["ready_day"]), "price": price}))


## Avvia la costruzione di una casa o di un negozio su un terreno tuo.
static func build(lot_id: int, kind: String) -> Dictionary:
	var rec: Dictionary = owned.get(lot_id, {})
	if rec.is_empty():
		return _res(false, text("not_yours"))
	if String(rec["kind"]) != "terreno":
		return _res(false, text("not_land"))
	if kind == "terreno" or type_def(kind).is_empty():
		return _res(false, text("unknown_type"))
	var price := build_price(kind)
	if PlayerState.money < price or not PlayerState.spend_money(price):
		return _res(false, text("no_money", {"price": price}))
	rec["kind"] = kind
	rec["ready_day"] = today() + int(type_def(kind).get("build_days", 1))
	rec["invested"] = int(rec["invested"]) + price
	EconomySystem.on_purchase(good(), 1)
	version += 1
	return _res(true, text("build_started", {"lot": lot_id, "name": type_name(kind), "day": int(rec["ready_day"]), "price": price}))


## Vende la proprietà: ricevi il valore di vendita più la cassa del negozio, meno le tasse arretrate.
static func sell(lot_id: int) -> Dictionary:
	var rec: Dictionary = owned.get(lot_id, {})
	if rec.is_empty():
		return _res(false, text("not_yours"))
	var stash: Array = rec["stash"]
	if not stash.is_empty():
		return _res(false, text("stash_not_empty"))
	var label := type_name(String(rec["kind"]))
	var total := sell_value(rec) + int(rec["till"])
	var dues := int(rec["dues"])
	var pay := mini(dues, total)
	var amount := total - pay
	owned.erase(lot_id)
	if amount > 0:
		PlayerState.add_money(amount)
	EconomySystem.on_supply(good(), 0.04)
	version += 1
	if dues > 0:
		return _res(true, text("sold_dues", {"name": label, "lot": lot_id, "amount": amount, "dues": pay}))
	return _res(true, text("sold", {"name": label, "lot": lot_id, "amount": amount}))


# --- Tasse e cassa ---

static func pay_dues(lot_id: int) -> Dictionary:
	var rec: Dictionary = owned.get(lot_id, {})
	if rec.is_empty():
		return _res(false, text("not_yours"))
	var dues := int(rec["dues"])
	if dues <= 0:
		return _res(false, text("no_dues"))
	var pay := mini(dues, PlayerState.money)
	if pay <= 0 or not PlayerState.spend_money(pay):
		return _res(false, text("no_cash"))
	rec["dues"] = dues - pay
	version += 1
	if int(rec["dues"]) <= 0:
		rec["arrears_days"] = 0
		rec["warned"] = false
		return _res(true, text("dues_paid", {"amount": pay, "lot": lot_id}))
	return _res(true, text("dues_part", {"amount": pay, "lot": lot_id, "left": int(rec["dues"])}))


static func collect_till(lot_id: int) -> Dictionary:
	var rec: Dictionary = owned.get(lot_id, {})
	if rec.is_empty() or String(rec["kind"]) != "negozio":
		return _res(false, text("not_yours"))
	if not is_built(rec):
		return _res(false, text("not_built"))
	var till := int(rec["till"])
	if till <= 0:
		return _res(false, text("till_empty"))
	PlayerState.add_money(till)
	rec["till"] = 0
	version += 1
	return _res(true, text("till_taken", {"amount": till}))


## Giorni che restano prima del pignoramento (tolleranza piena se non ci sono arretrati).
static func days_to_seizure(rec: Dictionary) -> int:
	var grace := int(section("taxes").get("grace_days", 15))
	if int(rec.get("dues", 0)) <= 0:
		return grace
	return maxi(grace - int(rec.get("arrears_days", 0)), 0)


static func total_dues() -> int:
	var t := 0
	for lot_id in owned:
		t += int(owned[lot_id]["dues"])
	return t


static func total_till() -> int:
	var t := 0
	for lot_id in owned:
		t += int(owned[lot_id]["till"])
	return t


## Riga per l'HUD ("" se non possiedi nulla).
static func hud_text() -> String:
	if owned.is_empty():
		return ""
	var s := "Proprietà: %d" % owned.size()
	var till := total_till()
	if till > 0:
		s += "  - incassi $%d" % till
	var dues := total_dues()
	if dues > 0:
		var soon := 999
		for lot_id in owned:
			var rec: Dictionary = owned[lot_id]
			if int(rec["dues"]) > 0:
				soon = mini(soon, days_to_seizure(rec))
		s += "  - tasse $%d (pignoramento fra %d g)" % [dues, soon]
	return s


# --- Casa: riposo e ripostiglio ---

## Dormi a casa tua: salute piena, ferite fasciate, ti svegli all'alba.
static func rest(lot_id: int) -> Dictionary:
	var rec: Dictionary = owned.get(lot_id, {})
	if rec.is_empty() or String(rec["kind"]) != "casa":
		return _res(false, text("not_yours"))
	if not is_built(rec):
		return _res(false, text("not_built"))
	PlayerState.heal(100000)
	var msg := text("slept")
	if WoundSystem.bandage_all(true) > 0:
		msg += text("slept_bandage")
	GameTime.skip_to_hour(int(type_def("casa").get("wake_hour", 6)))
	return _res(true, msg)


static func stash_slots_max() -> int:
	return int(type_def("casa").get("stash_slots", 8))


static func stash_of(lot_id: int) -> Array:
	var rec: Dictionary = owned.get(lot_id, {})
	if rec.is_empty():
		return []
	return rec["stash"]


static func _item_name(id: String) -> String:
	return str(ItemDB.get_item(id).get("name", id))


## Mette oggetti nel ripostiglio (impila come lo zaino). Ritorna la quantità che non è entrata.
static func _stash_add(stash: Array, id: String, qty: int) -> int:
	var def := ItemDB.get_item(id)
	if def.is_empty() or qty <= 0:
		return qty
	var max_stack := int(def.get("max_stack", 1)) if def.get("stackable", false) else 1
	for slot in stash:
		if qty <= 0:
			break
		if String(slot["id"]) == id and int(slot["qty"]) < max_stack:
			var put := mini(qty, max_stack - int(slot["qty"]))
			slot["qty"] = int(slot["qty"]) + put
			qty -= put
	while qty > 0 and stash.size() < stash_slots_max():
		var put2 := mini(qty, max_stack)
		stash.append({"id": id, "qty": put2})
		qty -= put2
	return qty


## Ripone nel ripostiglio tutto il contenuto dello slot `pack_index` dello zaino.
static func stash_deposit(lot_id: int, pack_index: int) -> Dictionary:
	var rec: Dictionary = owned.get(lot_id, {})
	if rec.is_empty() or String(rec["kind"]) != "casa" or not is_built(rec):
		return _res(false, text("not_built"))
	if pack_index < 0 or pack_index >= PlayerState.inventory.size():
		return _res(false, text("pack_full"))
	var slot: Dictionary = PlayerState.inventory[pack_index]
	var id := String(slot["id"])
	var qty := int(slot["qty"])
	var stash: Array = rec["stash"]
	var moved := qty - _stash_add(stash, id, qty)
	if moved <= 0:
		return _res(false, text("stash_full"))
	PlayerState.remove_item(id, moved)
	return _res(true, text("stash_in", {"item": _item_name(id)}))


## Riprende nello zaino tutto il contenuto dello slot `stash_index` del ripostiglio.
static func stash_withdraw(lot_id: int, stash_index: int) -> Dictionary:
	var rec: Dictionary = owned.get(lot_id, {})
	if rec.is_empty() or String(rec["kind"]) != "casa" or not is_built(rec):
		return _res(false, text("not_built"))
	var stash: Array = rec["stash"]
	if stash_index < 0 or stash_index >= stash.size():
		return _res(false, text("stash_full"))
	var slot: Dictionary = stash[stash_index]
	var id := String(slot["id"])
	var qty := int(slot["qty"])
	var left := PlayerState.add_item(id, qty)
	if qty - left <= 0:
		return _res(false, text("pack_full"))
	if left <= 0:
		stash.remove_at(stash_index)
	else:
		slot["qty"] = left
	return _res(true, text("stash_out", {"item": _item_name(id)}))


# --- Negozio: incasso previsto ---

## Incasso giornaliero medio (senza rumore né eventi): base x mercato x fama x Carisma.
static func shop_base() -> float:
	var sc := section("shop")
	var market := EconomySystem.index(String(sc.get("good", "merci")))
	var tier := ReputationSystem.tier_label(String(sc.get("flow_group", "cittadini")))
	var flow := float(sc.get("flow_by_tier", {}).get(tier, 1.0))
	var charm := 1.0 + float(PlayerState.get_base_stat("carisma")) * float(sc.get("carisma_bonus", 0.03))
	return float(sc.get("base_daily", 34)) * market * flow * charm


static func shop_wage() -> int:
	return int(section("shop").get("wage", 8))


static func shop_till_cap() -> int:
	return int(section("shop").get("till_cap", 400))


## Guadagno netto previsto al giorno per un negozio (dopo salario e tassa).
static func shop_expected_net() -> int:
	return roundi(shop_base()) - shop_wage() - int(type_def("negozio").get("tax", 0))


# --- Scorrere dei giorni ---

## Applica i giorni trascorsi (max 60 per volta). `pay_from_bank(importo) -> int` preleva dal conto in banca
## (la passa PropertyManager, così PropertySystem non dipende da BankSystem). Ritorna i messaggi.
static func advance_to(day: int, pay_from_bank: Callable = Callable()) -> Array[String]:
	var msgs: Array[String] = []
	var acc := {"bank": 0}
	var from := last_day + 1
	for d in range(from, mini(day, from + 59) + 1):
		msgs.append_array(_daily(d, pay_from_bank, acc))
	last_day = day
	if int(acc["bank"]) > 0:
		msgs.append(text("auto_paid", {"amount": int(acc["bank"])}))
	return msgs


static func _daily(d: int, pay_from_bank: Callable, acc: Dictionary) -> Array[String]:
	var msgs: Array[String] = []
	var tc := section("taxes")
	var grace := int(tc.get("grace_days", 15))
	var warn_left := int(tc.get("warn_days_left", 3))
	for lot_id in owned.keys():
		var lid := int(lot_id)
		var rec: Dictionary = owned[lid]
		var kind := String(rec["kind"])

		# Lavori
		var finished_today := false
		if int(rec["ready_day"]) > 0 and d >= int(rec["ready_day"]):
			rec["ready_day"] = 0
			finished_today = true
			msgs.append(text("build_done", {"lot": lid, "name": type_name(kind)}))
			if kind == "negozio":
				_rep("shop_built")
			version += 1

		# Tassa del giorno (un cantiere che finisce oggi paga già come edificio)
		rec["dues"] = int(rec["dues"]) + tax_of(rec)

		# Negozio: incasso del giorno (dal giorno dopo l'inaugurazione)
		if kind == "negozio" and not finished_today and is_built(rec):
			msgs.append_array(_shop_day(rec, lid, d))

		# Pagamento: prima la cassa del negozio, poi il conto in banca
		var dues := int(rec["dues"])
		if dues > 0 and int(rec["till"]) > 0:
			var from_till := mini(dues, int(rec["till"]))
			rec["till"] = int(rec["till"]) - from_till
			dues -= from_till
		if dues > 0 and bool(tc.get("auto_pay_bank", true)) and pay_from_bank.is_valid():
			var got := int(pay_from_bank.call(dues))
			dues -= got
			acc["bank"] = int(acc["bank"]) + got
		rec["dues"] = dues

		# Arretrati e pignoramento
		if dues > 0:
			rec["arrears_days"] = int(rec["arrears_days"]) + 1
			var ad := int(rec["arrears_days"])
			if ad >= grace:
				msgs.append_array(_seize(lid))
				continue
			var left := grace - ad
			if left <= warn_left and not bool(rec["warned"]):
				rec["warned"] = true
				msgs.append(text("tax_warn", {"lot": lid, "days": ad, "left": left}))
		else:
			rec["arrears_days"] = 0
			rec["warned"] = false
	return msgs


static func _shop_day(rec: Dictionary, lid: int, d: int) -> Array[String]:
	var msgs: Array[String] = []
	var sc := section("shop")
	var rng := WorldSeed.rng_for("property_%d_day_%d" % [lid, d])
	var noise := float(sc.get("noise", 0.2))
	var gross := roundi(shop_base() * rng.randf_range(1.0 - noise, 1.0 + noise))
	var net := maxi(gross - shop_wage(), 0)
	var cap := shop_till_cap()
	var till := int(rec["till"])
	rec["till"] = till + mini(net, maxi(cap - till, 0))
	rec["last_revenue"] = gross
	rec["last_net"] = net
	EconomySystem.on_supply(String(sc.get("good", "merci")), float(sc.get("supply_per_day", 0.015)))

	var roll := rng.randf()
	var acc := 0.0
	for ev in sc.get("events", []):
		acc += float(ev.get("chance", 0.0))
		if roll < acc:
			var line := _shop_event(rec, ev, rng, cap)
			if line != "":
				msgs.append(line)
			break
	return msgs


static func _shop_event(rec: Dictionary, ev: Dictionary, rng: RandomNumberGenerator, cap: int) -> String:
	var sc := section("shop")
	var amount := 0
	match String(ev.get("kind", "")):
		"bonus":
			var rb: Array = ev.get("amount", [0, 0])
			amount = rng.randi_range(int(rb[0]), int(rb[1]))
			var room := maxi(cap - int(rec["till"]), 0)
			amount = mini(amount, room)
			rec["till"] = int(rec["till"]) + amount
		"theft":
			var fr: Array = ev.get("frac", [0.25, 0.5])
			var frac := rng.randf_range(float(fr[0]), float(fr[1]))
			if ReputationSystem.value(String(sc.get("law_group", "legge"))) >= int(sc.get("law_protect_min", 15)):
				frac *= float(sc.get("law_protect_mult", 0.4))
			amount = roundi(float(rec["till"]) * frac)
			rec["till"] = int(rec["till"]) - amount
		"fine":
			var rf: Array = ev.get("amount", [0, 0])
			amount = mini(rng.randi_range(int(rf[0]), int(rf[1])), int(rec["till"]))
			rec["till"] = int(rec["till"]) - amount
	if amount <= 0:
		return ""
	return str(ev.get("text", "")).format({"amount": amount})


static func _seize(lid: int) -> Array[String]:
	var msgs: Array[String] = []
	var rec: Dictionary = owned.get(lid, {})
	if rec.is_empty():
		return msgs
	var msg := text("seized", {"name": type_name(String(rec["kind"])), "lot": lid})
	var stash: Array = rec["stash"]
	if not stash.is_empty():
		msg += text("seized_stash")
	owned.erase(lid)
	_rep("seized")
	version += 1
	msgs.append(msg)
	return msgs


# --- Rapporti con la banca ---

## Garanzia che le proprietà aggiungono al fido (BankSystem passa il suo fattore).
static func collateral(factor: float) -> int:
	var total := 0
	for lot_id in owned:
		total += int(owned[lot_id]["invested"])
	return roundi(float(total) * factor)


## Insolvenza: la banca ipoteca la proprietà di maggior valore a copertura del debito `amount`.
## Se vale più del debito, la differenza torna a te. Ritorna {name, lot, applied, excess} oppure {}.
static func foreclose(amount: int) -> Dictionary:
	if owned.is_empty() or amount <= 0:
		return {}
	var best := -1
	var best_invested := -1
	for lot_id in owned:
		var inv := int(owned[lot_id]["invested"])
		if inv > best_invested:
			best_invested = inv
			best = int(lot_id)
	if best < 0:
		return {}
	var rec: Dictionary = owned[best]
	var value := roundi(float(rec["invested"]) * float(section("sell").get("ratio", 0.6)))
	var applied := mini(value, amount)
	var excess := value - applied
	var label := type_name(String(rec["kind"]))
	owned.erase(best)
	if excess > 0:
		PlayerState.add_money(excess)
	version += 1
	return {"name": label, "lot": best, "applied": applied, "excess": excess}
