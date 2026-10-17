class_name BankSystem
extends RefCounted
## Sistema banca (Feature 17): deposito, prestiti, debiti e interessi. Dati in data/bank.json.
## - Il conto in banca frutta un piccolo interesse ogni giorno di gioco.
## - Il fido dipende dalla reputazione presso i commercianti (fascia) più il deposito in cassa (garanzia).
## - Tasso del prestito = tasso base x reputazione (stessa fascia dei prezzi) x mercato (indice dei beni
##   che compri, EconomySystem) x durata scelta. Commissione di apertura aggiunta al debito.
## - Il debito matura interessi ogni giorno. Dopo la scadenza scattano penale, tasso doppio e reputazione
##   in calo; dopo alcuni giorni di ritardo la banca dichiara l'insolvenza: sequestra il deposito,
##   punisce reputazione e rapporto con il banchiere e ti nega credito per un po' (lista nera).
## Tutto vive in memoria (il salvataggio arriverà più avanti). `advance_to(giorno)` la chiama BankManager.

const PATH := "res://data/bank.json"

static var _data: Dictionary = {}
static var balance: int = 0
static var interest_frac: float = 0.0
static var interest_earned: int = 0
static var loans: Array[Dictionary] = []   # {id, principal, remaining, rate, taken_day, due_day, overdue_days, status, warned}
static var next_id: int = 1
static var blacklist_until: int = 0
static var last_day: int = 1


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


## Nuova partita: conto e debiti azzerati.
static func reset() -> void:
	balance = 0
	interest_frac = 0.0
	interest_earned = 0
	loans.clear()
	next_id = 1
	blacklist_until = 0
	last_day = today()


# --- Stato ---

static func debt_total() -> int:
	var t := 0
	for l in loans:
		t += int(l["remaining"])
	return t


static func has_debt() -> bool:
	return not loans.is_empty()


## Debito scaduto o in insolvenza.
static func has_overdue() -> bool:
	for l in loans:
		if String(l["status"]) != "active":
			return true
	return false


static func is_blacklisted() -> bool:
	return today() < blacklist_until


static func get_loan(id: int) -> Dictionary:
	for l in loans:
		if int(l["id"]) == id:
			return l
	return {}


static func days_left(loan: Dictionary) -> int:
	return int(loan["due_day"]) - today()


## Riga per l'HUD ("" se non hai debiti).
static func hud_text() -> String:
	if loans.is_empty():
		return ""
	var s := "Debito banca: $%d" % debt_total()
	if has_overdue():
		return s + "  - SCADUTO!"
	var soon := 999
	for l in loans:
		soon = mini(soon, days_left(l))
	return s + "  (scade fra %d g)" % maxi(soon, 0)


# --- Deposito ---

static func deposit_rate() -> float:
	return float(section("deposit").get("daily_rate", 0.0))


static func deposit(amount: int) -> Dictionary:
	if amount <= 0:
		return _res(false, text("nothing_to_deposit"))
	if PlayerState.money < amount or not PlayerState.spend_money(amount):
		return _res(false, text("no_cash"))
	balance += amount
	return _res(true, text("deposited", {"amount": amount, "balance": balance}))


static func withdraw(amount: int) -> Dictionary:
	if amount <= 0 or amount > balance:
		return _res(false, text("no_balance"))
	balance -= amount
	PlayerState.add_money(amount)
	return _res(true, text("withdrawn", {"amount": amount, "balance": balance}))


# --- Prestiti ---

static func terms() -> Array:
	return section("loans").get("terms", [])


static func term(index: int) -> Dictionary:
	var t := terms()
	if t.is_empty():
		return {"days": 10, "rate_mult": 1.0, "label": "10 giorni"}
	return t[clampi(index, 0, t.size() - 1)]


static func _rep_group() -> String:
	return String(data().get("rep_group", "commercianti"))


## Fido base della fascia di reputazione corrente.
static func tier_limit() -> int:
	var label := ReputationSystem.tier_label(_rep_group())
	return int(section("loans").get("limits", {}).get(label, 0))


## Cifra massima che puoi chiedere adesso (0 = nessun credito).
static func max_loan() -> int:
	var lc := section("loans")
	if is_blacklisted() or has_overdue() or loans.size() >= int(lc.get("max_active", 2)):
		return 0
	var limit := tier_limit() + roundi(float(balance) * float(lc.get("collateral_factor", 1.0)))
	return maxi(0, limit - debt_total())


## Motivo per cui non puoi chiedere un prestito ("" = puoi).
static func block_reason() -> String:
	if is_blacklisted():
		return text("blacklisted", {"days": blacklist_until - today()})
	if has_overdue():
		return text("has_overdue")
	if loans.size() >= int(section("loans").get("max_active", 2)):
		return text("too_many")
	if max_loan() <= 0:
		return text("no_credit", {"tier": ReputationSystem.tier_label(_rep_group())})
	return ""


## Moltiplicatore di mercato: sale se i beni che compri costano tanto.
static func market_mult() -> float:
	var sum := 0.0
	var n := 0
	for g in EconomySystem.good_ids():
		if EconomySystem.good_kind(String(g)) == "buy":
			sum += EconomySystem.index(String(g))
			n += 1
	if n == 0:
		return 1.0
	return clampf(1.0 + (sum / float(n) - 1.0) * float(section("loans").get("market_sensitivity", 0.5)), 0.8, 1.3)


## Tasso giornaliero per una durata: base x reputazione x mercato x durata.
static func rate_for(t: Dictionary) -> float:
	var lc := section("loans")
	var r := float(lc.get("base_daily_rate", 0.02)) * ReputationSystem.price_mult() * market_mult() * float(t.get("rate_mult", 1.0))
	return clampf(r, float(lc.get("min_rate", 0.005)), float(lc.get("max_rate", 0.08)))


## Preventivo: commissione, tasso, giorni, totale circa da restituire alla scadenza.
static func quote(amount: int, term_index: int) -> Dictionary:
	var t := term(term_index)
	var fee := ceili(float(amount) * float(section("loans").get("origination_fee", 0.0)))
	var r := rate_for(t)
	var days := int(t.get("days", 10))
	var owed := roundi(float(amount + fee) * pow(1.0 + r, float(days)))
	return {"fee": fee, "rate": r, "days": days, "owed": owed, "due_day": today() + days}


static func take_loan(amount: int, term_index: int) -> Dictionary:
	var reason := block_reason()
	if reason != "":
		return _res(false, reason)
	if amount <= 0 or amount > max_loan():
		return _res(false, text("too_high"))
	var q := quote(amount, term_index)
	loans.append({
		"id": next_id, "principal": amount, "remaining": amount + int(q["fee"]), "rate": float(q["rate"]),
		"taken_day": today(), "due_day": int(q["due_day"]), "overdue_days": 0, "status": "active", "warned": false,
	})
	next_id += 1
	PlayerState.add_money(amount)
	return _res(true, text("loan_taken", {"amount": amount, "due": q["due_day"], "owed": q["owed"]}))


## Versa fino a `amount` (limitato ai contanti e al debito residuo).
static func repay(loan_id: int, amount: int) -> Dictionary:
	var loan := get_loan(loan_id)
	if loan.is_empty():
		return _res(false, text("no_balance"))
	var pay := mini(mini(amount, int(loan["remaining"])), PlayerState.money)
	if pay <= 0 or not PlayerState.spend_money(pay):
		return _res(false, text("repay_nothing"))
	loan["remaining"] = int(loan["remaining"]) - pay
	if int(loan["remaining"]) > 0:
		return _res(true, text("repaid_part", {"paid": pay, "left": loan["remaining"]}))
	var rep: Dictionary = data().get("reputation", {})
	var late := String(loan["status"]) != "active"
	ReputationSystem.add(_rep_group(), int(rep.get("late_repaid" if late else "on_time", 0)))
	loans.erase(loan)
	return _res(true, text("repaid_full_late" if late else "repaid_full", {"paid": pay}))


# --- Scorrere dei giorni ---

## Applica i giorni trascorsi (max 60 per volta). Ritorna i messaggi per il giocatore.
static func advance_to(day: int) -> Array[String]:
	var msgs: Array[String] = []
	var from := last_day + 1
	for d in range(from, mini(day, from + 59) + 1):
		msgs.append_array(_daily(d))
	last_day = day
	return msgs


static func _daily(d: int) -> Array[String]:
	var msgs: Array[String] = []
	var dc := section("deposit")
	var pc := section("penalties")
	var rc := section("reputation")

	# Interessi sul deposito
	if balance >= int(dc.get("min_balance", 10)):
		var gain := float(balance) * deposit_rate() + interest_frac
		var whole := mini(int(gain), int(dc.get("max_interest_per_day", 25)))
		interest_frac = gain - floorf(gain)
		if whole > 0:
			balance += whole
			interest_earned += whole

	# Debiti
	for loan in loans.duplicate():
		match String(loan["status"]):
			"active":
				loan["remaining"] = int(loan["remaining"]) + ceili(float(loan["remaining"]) * float(loan["rate"]))
				var left := int(loan["due_day"]) - d
				if left == 1 and not bool(loan["warned"]):
					loan["warned"] = true
					msgs.append(text("warn_tomorrow", {"id": loan["id"], "owed": loan["remaining"]}))
				elif left < 0:
					var fee := ceili(float(loan["remaining"]) * float(pc.get("late_fee", 0.05)))
					loan["remaining"] = int(loan["remaining"]) + fee
					loan["status"] = "overdue"
					loan["overdue_days"] = 0
					ReputationSystem.add(_rep_group(), int(rc.get("overdue_start", -4)))
					msgs.append(text("overdue", {"id": loan["id"], "fee": fee, "owed": loan["remaining"]}))
			"overdue":
				var extra := ceili(float(loan["remaining"]) * float(loan["rate"]) * float(pc.get("overdue_rate_mult", 2.0)))
				loan["remaining"] = int(loan["remaining"]) + extra
				loan["overdue_days"] = int(loan["overdue_days"]) + 1
				ReputationSystem.add(_rep_group(), int(rc.get("overdue_day", -1)))
				if int(loan["overdue_days"]) >= int(pc.get("default_days", 5)):
					msgs.append_array(_default(loan, d))
	return msgs


static func _default(loan: Dictionary, d: int) -> Array[String]:
	var msgs: Array[String] = [text("default", {"id": loan["id"]})]
	var pc := section("penalties")
	var rc := section("reputation")
	var seized := mini(balance, int(loan["remaining"]))
	if seized > 0:
		balance -= seized
		loan["remaining"] = int(loan["remaining"]) - seized
		msgs.append(text("seized", {"seized": seized}))
	blacklist_until = d + int(pc.get("blacklist_days", 10))
	ReputationSystem.add(_rep_group(), int(rc.get("default_commercianti", -20)))
	ReputationSystem.add("cittadini", int(rc.get("default_cittadini", -6)))
	for n in NPCRegistry.by_job("banchiere"):
		NPCRegistry.change_relationship(String(n["id"]), int(pc.get("banker_relationship", -15)))
	if int(loan["remaining"]) <= 0:
		loans.erase(loan)
	else:
		loan["status"] = "default"
		msgs.append(text("default_left", {"left": loan["remaining"], "days": blacklist_until - d}))
	return msgs
