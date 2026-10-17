class_name BuildingActions
extends RefCounted
## Esegue le azioni definite in data/buildings.json.
## Ogni azione ritorna {"ok": bool, "msg": String}.
## Il conto in banca, i prestiti e i debiti vivono in BankSystem (Feature 17).


## Nuova partita: conto e debiti della banca tornano a zero.
static func reset() -> void:
	BankSystem.reset()


static func player_money() -> int:
	var m = PlayerState.get("money")
	return int(m) if m != null else 0


static func is_open(def: Dictionary) -> bool:
	var oh: Array = def.get("open_hours", [])
	if oh.size() < 2:
		return true
	var h = GameTime.get("hour")
	if h == null:
		return true
	var hh := float(h)
	var a := float(oh[0])
	var b := float(oh[1])
	if a < b:
		return hh >= a and hh < b
	return hh >= a or hh < b


static func opening_text(def: Dictionary) -> String:
	var oh: Array = def.get("open_hours", [])
	if oh.size() < 2:
		return ""
	return "%02d:00" % int(oh[0])


static func _result(ok: bool, msg: String) -> Dictionary:
	return {"ok": ok, "msg": msg}


static func _spend(amount: int) -> bool:
	if amount <= 0:
		return true
	var have = PlayerState.get("money")
	if have != null and int(have) < amount:
		return false
	var r = PlayerState.spend_money(amount)
	return not (r is bool and r == false)


## Prezzo base di un'azione (per le armi viene da data/weapons.json).
static func action_cost(action: Dictionary) -> int:
	if String(action.get("type", "")) == "buy_weapon":
		return WeaponDB.price(String(action.get("weapon", "")))
	return int(action.get("cost", 0))


## Prezzo finale: prezzo base x mercato del bene (EconomySystem, Feature 16) x reputazione.
static func price(action: Dictionary) -> int:
	return EconomySystem.price(str(action.get("good", "")), action_cost(action))


static func action_label(action: Dictionary) -> String:
	if action.has("label"):
		return String(action["label"])
	if String(action.get("type", "")) == "buy_weapon":
		var w := String(action.get("weapon", ""))
		return "Compra: %s (%s)" % [WeaponDB.name_of(w), WeaponDB.rarity_label(w)]
	return "Azione"


static func action_tooltip(action: Dictionary) -> String:
	if String(action.get("type", "")) == "buy_weapon":
		var w := String(action.get("weapon", ""))
		return "%s\n%s" % [String(WeaponDB.weapon(w).get("desc", "")), WeaponDB.stats_text(w)]
	return ""


## Esegue l'azione; se è un acquisto riuscito di un bene, la domanda del mercato sale.
static func execute(action: Dictionary, def: Dictionary) -> Dictionary:
	var r := _execute_raw(action, def)
	var good := str(action.get("good", ""))
	if good != "" and bool(r.get("ok", false)):
		EconomySystem.on_purchase(good, int(action.get("qty", 1)))
	return r


static func _execute_raw(action: Dictionary, _def: Dictionary) -> Dictionary:
	match String(action.get("type", "")):
		"buy_weapon":
			var wid := String(action.get("weapon", ""))
			if not WeaponDB.is_weapon(wid):
				return _result(false, "Arma sconosciuta.")
			if PlayerState.has_item(wid):
				return _result(false, "Hai già %s." % WeaponDB.the_name(wid))
			if PlayerState.inventory.size() >= PlayerState.get_slot_limit():
				return _result(false, "Lo zaino è pieno.")
			var cost := price(action)
			if not _spend(cost):
				return _result(false, "Non hai abbastanza soldi.")
			PlayerState.add_item(wid, 1)
			var msg := "Compri %s per $%d." % [WeaponDB.the_name(wid), cost]
			if PlayerState.get_weapon() == "" and WeaponDB.kind(wid) == "ranged":
				PlayerState.equip_weapon(wid)
				msg += " La tieni subito in mano."
			else:
				msg += " Equipaggiala dalla scheda (tasto I)."
			return _result(true, msg)
		"buy_heal":
			var cost := price(action)
			if not _spend(cost):
				return _result(false, "Non hai abbastanza soldi.")
			PlayerState.heal(int(action.get("heal", 0)))
			return _result(true, String(action.get("text", "Ti senti meglio.")))
		"buy_item":
			var item := String(action.get("item", ""))
			if not ItemDB.has_item(item):
				return _result(false, "Oggetto sconosciuto.")
			var icost := price(action)
			if not _spend(icost):
				return _result(false, "Non hai abbastanza soldi.")
			if PlayerState.add_item(item, int(action.get("qty", 1))) > 0:
				PlayerState.add_money(icost)
				return _result(false, "Lo zaino è pieno.")
			return _result(true, String(action.get("text", "Acquisto fatto.")))
		"rest":
			var cost := price(action)
			if not _spend(cost):
				return _result(false, "Non hai abbastanza soldi.")
			var heal = action.get("heal", 0)
			PlayerState.heal(100000 if str(heal) == "full" else int(heal))
			var msg := String(action.get("text", "Ti riposi."))
			if WoundSystem.bandage_all(true) > 0:
				msg += " Prima di coricarti fasci le ferite che sanguinavano."
			var wake := int(action.get("wake_hour", -1))
			if wake >= 0 and GameTime.has_method("skip_to_hour"):
				GameTime.skip_to_hour(wake)
			return _result(true, msg)
		"info":
			return _result(true, String(action.get("text", "")))
	return _result(false, "Azione sconosciuta.")
