class_name DuelPanel
extends Control
## Schermata del duello: strada principale a mezzogiorno, pubblico, due sagome e il segnale.
## Fasi: sfida -> intro -> attesa del segnale -> SPARA -> scambio di colpi -> esito.

signal finished(result: Dictionary)

enum Stage { CHALLENGE, INTRO, STANDOFF, CUE, RESOLVE, RESULT }

const SKY_TOP := Color(0.98, 0.93, 0.78)
const SKY_BOTTOM := Color(0.95, 0.80, 0.52)
const GROUND := Color(0.76, 0.58, 0.36)
const GROUND_FAR := Color(0.83, 0.67, 0.44)
const WOOD := Color(0.36, 0.23, 0.14)
const WOOD_DARK := Color(0.24, 0.15, 0.09)
const SHADOW := Color(0.0, 0.0, 0.0, 0.35)
const INK := Color(0.10, 0.07, 0.05)

var system: DuelSystem

var _stage: int = Stage.CHALLENGE
var _t: float = 0.0
var _cue_tick: int = 0
var _ev_i: int = 0
var _ev_t: float = 0.0
var _end_t: float = 0.0
var _flash_p: float = 0.0
var _flash_o: float = 0.0
var _shake: float = 0.0
var _pose_p: String = "ready"
var _pose_o: String = "ready"
var _log_lines: Array[String] = []
var _can_accept: bool = true

# Restyle a sprite (se i file mancano restano le sagome a codice).
var _fp: DuelFighter
var _fo: DuelFighter
var _aud: DuelFighter
var _clock := 0.0
var _cue_flash := 0.0
var _accepted := false
var _first_shooter := ""
var _first_shot_done := false
var _walk_dust := 0.0
var _parts: Array[Dictionary] = []
var _tracers: Array[Dictionary] = []

var _title: Label
var _sub: Label
var _text: Label
var _big: Label
var _buttons: HBoxContainer
var _bar_p: ProgressBar
var _bar_o: ProgressBar
var _name_p: Label
var _name_o: Label


func setup(sys: DuelSystem) -> void:
	system = sys
	_can_accept = system.has_ranged_weapon()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	size = get_viewport_rect().size
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if DuelFighter.available():
		_fp = DuelFighter.new()
		_fo = DuelFighter.new()
		_aud = DuelFighter.new()
	_build_ui()
	_show_challenge()


# ------------------------------------------------------------------ interfaccia

func _build_ui() -> void:
	WesternTheme.apply(self)

	_title = Label.new()
	_title.text = "DUELLO A MEZZOGIORNO"
	_title.theme_type_variation = "TitleLabel"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_title.offset_left = 0
	_title.offset_right = 0
	_title.offset_top = 16
	_title.offset_bottom = 56
	add_child(_title)

	_sub = Label.new()
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_sub.offset_left = 0
	_sub.offset_right = 0
	_sub.offset_top = 56
	_sub.offset_bottom = 84
	_sub.add_theme_color_override("font_color", INK)
	add_child(_sub)

	_bar_p = _make_bar(true)
	_name_p = _make_bar_label(true, PlayerState.player_name if "player_name" in PlayerState else "Tu")
	_bar_o = _make_bar(false)
	_name_o = _make_bar_label(false, system.opponent_name())
	_bar_p.max_value = system.player_max
	_bar_p.value = system.player_max
	_bar_o.max_value = system.opp_max
	_bar_o.value = system.opp_max

	_big = Label.new()
	_big.text = DuelDB.text("cue")
	_big.theme_type_variation = "TitleLabel"
	_big.add_theme_font_size_override("font_size", 96)
	_big.add_theme_color_override("font_color", Color(0.75, 0.10, 0.05))
	_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_big.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_big.anchor_left = 0.0
	_big.anchor_right = 1.0
	_big.anchor_top = 0.0
	_big.anchor_bottom = 0.0
	_big.offset_left = 0
	_big.offset_right = 0
	_big.offset_top = 150
	_big.offset_bottom = 270
	_big.visible = false
	add_child(_big)

	var card := PanelContainer.new()
	card.theme_type_variation = "PaperPanel"
	card.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	card.anchor_left = 0.12
	card.anchor_right = 0.88
	card.offset_left = 0
	card.offset_right = 0
	card.offset_top = -190
	card.offset_bottom = -20
	add_child(card)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	card.add_child(box)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_color_override("font_color", INK)
	box.add_child(_text)

	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	box.add_child(_buttons)


func _make_bar(left: bool) -> ProgressBar:
	var b := ProgressBar.new()
	b.show_percentage = false
	b.custom_minimum_size = Vector2(240, 18)
	b.set_anchors_preset(Control.PRESET_TOP_LEFT if left else Control.PRESET_TOP_RIGHT)
	if left:
		b.offset_left = 24
		b.offset_right = 264
	else:
		b.offset_left = -264
		b.offset_right = -24
	b.offset_top = 104
	b.offset_bottom = 122
	add_child(b)
	return b


func _make_bar_label(left: bool, txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_color_override("font_color", INK)
	l.set_anchors_preset(Control.PRESET_TOP_LEFT if left else Control.PRESET_TOP_RIGHT)
	if left:
		l.offset_left = 24
		l.offset_right = 264
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	else:
		l.offset_left = -264
		l.offset_right = -24
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	l.offset_top = 82
	l.offset_bottom = 104
	add_child(l)
	return l


func _set_buttons(defs: Array) -> void:
	for c in _buttons.get_children():
		c.queue_free()
	for d in defs:
		var b := Button.new()
		b.text = d[0]
		b.custom_minimum_size = Vector2(190, 38)
		b.pressed.connect(d[1])
		if d.size() > 2:
			b.disabled = not bool(d[2])
		_buttons.add_child(b)


# ----------------------------------------------------------------------- fasi

func _show_challenge() -> void:
	_stage = Stage.CHALLENGE
	var v := {
		"opp": system.opponent_name(),
		"street": DuelDB.value("street", "strada"),
		"stake": system.stake,
		"audience": system.audience,
	}
	_sub.text = "%s — %d spettatori — posta $%d" % [DuelDB.value("street", "Strada"), system.audience, system.stake]
	var txt := DuelDB.text("challenge", v) + "\n" + DuelDB.text("challenge_info", v)
	if system.sheriff_present:
		txt += "\n" + DuelDB.text("challenge_sheriff")
	if _can_accept:
		txt += "\n" + DuelDB.text("refuse_hint")
	else:
		txt += "\n" + DuelDB.text("no_weapon")
	_text.text = txt
	_set_buttons([
		["1. Accetta", _on_accept, _can_accept],
		["2. Rifiuta", _on_refuse],
	])


func _on_accept() -> void:
	var noon := int(DuelDB.value("noon_hour", 12))
	var before := false
	if "hour" in GameTime and float(GameTime.hour) < float(noon):
		before = true
		if GameTime.has_method("skip_to_hour"):
			GameTime.skip_to_hour(noon)
	_stage = Stage.INTRO
	_t = 0.0
	_accepted = true
	_play_both("walk")
	_text.text = DuelDB.text("intro_before" if before else "intro_after")
	_set_buttons([])


func _on_refuse() -> void:
	system.refuse()
	_show_result()


func _start_standoff() -> void:
	_stage = Stage.STANDOFF
	_t = 0.0
	_play_both("idle")
	_text.text = DuelDB.text("standoff")
	_set_buttons([])


func _begin_resolve(reaction_ms: float, was_foul: bool) -> void:
	_big.visible = false
	system.resolve(reaction_ms, was_foul)
	_stage = Stage.RESOLVE
	_ev_i = 0
	_ev_t = 0.4
	_end_t = 0.0
	_log_lines.clear()
	_text.text = ""
	_start_draws()


func _show_result() -> void:
	_stage = Stage.RESULT
	_big.visible = false
	var r: Dictionary = system.result
	var lines: Array[String] = []
	for l in r.get("lines", []):
		lines.append(str(l))
	var money := int(r.get("money", 0))
	if money > 0:
		lines.append("Incassi la posta: +$%d" % money)
	elif money < 0:
		lines.append("Paghi la posta: -$%d" % -money)
	var dmg := int(r.get("damage", 0))
	if dmg > 0:
		lines.append("Salute persa: %d (controlla le ferite nella scheda)" % dmg)
	var rep: Dictionary = r.get("rep", {})
	var parts: Array[String] = []
	for g in rep:
		var v := int(rep[g])
		parts.append("%s %s%d" % [str(g).capitalize(), "+" if v > 0 else "", v])
	if not parts.is_empty():
		lines.append("Reputazione: " + ", ".join(parts))
	_text.text = "\n".join(lines)
	_set_buttons([["Continua", _on_continue]])
	_end_poses()
	system.apply_results()
	modulate = Color.WHITE


func _on_continue() -> void:
	finished.emit(system.result)


# ----------------------------------------------------------------------- input

func _is_draw_input(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return event.keycode == KEY_SPACE or event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		return true
	return false


func _input(event: InputEvent) -> void:
	match _stage:
		Stage.CHALLENGE:
			if event is InputEventKey and event.pressed and not event.echo:
				if event.keycode == KEY_1 and _can_accept:
					_on_accept()
					accept_event()
				elif event.keycode == KEY_2 or event.keycode == KEY_ESCAPE:
					_on_refuse()
					accept_event()
		Stage.STANDOFF:
			if _is_draw_input(event):
				_begin_resolve(0.0, true)
				accept_event()
		Stage.CUE:
			if _is_draw_input(event):
				_begin_resolve(float(Time.get_ticks_msec() - _cue_tick), false)
				accept_event()
		Stage.RESULT:
			if _is_draw_input(event):
				_on_continue()
				accept_event()


# --------------------------------------------------------------------- aggiorna

func _process(delta: float) -> void:
	_clock += delta
	_cue_flash = maxf(0.0, _cue_flash - delta * 3.0)
	if _fp != null:
		_fp.update(delta)
		_fo.update(delta)
		_update_fx(delta)
	_flash_p = maxf(0.0, _flash_p - delta * 4.0)
	_flash_o = maxf(0.0, _flash_o - delta * 4.0)
	_shake = maxf(0.0, _shake - delta * 30.0)

	match _stage:
		Stage.INTRO:
			_t += delta
			if _t >= float(DuelDB.section("timing").get("intro_seconds", 2.4)):
				_start_standoff()
		Stage.STANDOFF:
			_t += delta
			if _t >= system.cue_delay:
				_stage = Stage.CUE
				_cue_tick = Time.get_ticks_msec()
				_big.visible = true
				_big.text = DuelDB.text("cue")
				_text.text = DuelDB.text("cue_hint")
				_shake = 6.0
				_cue_flash = 1.0
		Stage.CUE:
			var window := float(DuelDB.section("timing").get("react_window_ms", 1400))
			if float(Time.get_ticks_msec() - _cue_tick) >= window:
				_begin_resolve(window, false)
		Stage.RESOLVE:
			_tick_resolve(delta)
	queue_redraw()


func _tick_resolve(delta: float) -> void:
	if _ev_i >= system.events.size():
		_end_t += delta
		if _end_t >= 1.0:
			_show_result()
		return
	_ev_t -= delta
	if _ev_t > 0.0:
		return
	_ev_t = float(DuelDB.section("timing").get("event_seconds", 1.0))
	var e: Dictionary = system.events[_ev_i]
	_ev_i += 1
	_log_lines.append(str(e.get("text", "")))
	while _log_lines.size() > 5:
		_log_lines.pop_front()
	_text.text = "\n".join(_log_lines)
	_bar_p.value = int(e.get("php", system.player_max))
	_bar_o.value = int(e.get("ohp", system.opp_max))

	var who := str(e.get("who", "narr"))
	var kind := str(e.get("kind", "info"))
	if who != "narr" and _pose_p == "ready":
		_pose_p = "draw"
		_pose_o = "draw"
	if who == "player" and kind != "down":
		_flash_p = 1.0
		if kind == "hit":
			_shake = 5.0
	elif who == "opp" and kind != "down":
		_flash_o = 1.0
		if kind == "hit":
			_shake = 9.0
	if kind == "down":
		if who == "opp":
			_pose_o = "down"
		else:
			_pose_p = "down"
	_event_fx(who, kind)


# ---------------------------------------------------------------------- disegno

func _draw() -> void:
	var w := size.x
	var h := size.y
	var off := Vector2.ZERO
	if _shake > 0.0:
		off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	draw_set_transform(off, 0.0, Vector2.ONE)

	var gy := h * 0.60
	# Cielo di mezzogiorno.
	var stripes := 8
	for i in stripes:
		var f := float(i) / float(stripes - 1)
		draw_rect(Rect2(-20, gy * float(i) / float(stripes), w + 40, gy / float(stripes) + 2), SKY_TOP.lerp(SKY_BOTTOM, f))
	# Sole a picco con alone.
	var sun := Vector2(w * 0.5, h * 0.11)
	for i in 4:
		draw_circle(sun, 70.0 - float(i) * 14.0, Color(1.0, 0.97, 0.80, 0.10 + 0.08 * float(i)))
	draw_circle(sun, 26.0, Color(1.0, 0.99, 0.88))
	_draw_backdrop(w, gy)
	# Terra: sfondo e strada.
	draw_rect(Rect2(-20, gy - 6, w + 40, h - gy + 26), GROUND_FAR)
	draw_rect(Rect2(-20, gy + 10, w + 40, h - gy + 10), GROUND)
	for i in 14:
		draw_rect(Rect2(w * (0.04 + 0.07 * float(i)), gy + 28.0 + float(i % 3) * 14.0, 26, 3), GROUND_FAR)

	_draw_buildings(w, gy)
	_draw_audience(w, gy)

	if _fp != null:
		_draw_fighters(off)
	else:
		var s := clampf(h / 560.0, 0.8, 1.7)
		_draw_person(Vector2(w * 0.32, gy + 40.0), 1, _pose_p, _flash_p, Color(0.20, 0.30, 0.45), Color(0.18, 0.12, 0.08), s, off)
		_draw_person(Vector2(w * 0.68, gy + 40.0), -1, _pose_o, _flash_o, Color(0.45, 0.18, 0.15), Color(0.08, 0.06, 0.05), s, off)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Vignettatura leggera in alto e in basso.
	draw_rect(Rect2(0, 0, w, 90), Color(0.1, 0.06, 0.03, 0.25))
	draw_rect(Rect2(0, h - 210, w, 210), Color(0.1, 0.06, 0.03, 0.25))
	if _cue_flash > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(1.0, 0.97, 0.85, _cue_flash * 0.35))


func _draw_buildings(w: float, gy: float) -> void:
	if _fp != null:
		_draw_town(w, gy)
		return
	var bw := w * 0.20
	for side in 2:
		var x0 := 0.0 if side == 0 else w - bw
		draw_rect(Rect2(x0, gy - 180, bw, 190), WOOD)
		draw_rect(Rect2(x0, gy - 180, bw, 14), WOOD_DARK)
		# Tettoia del portico.
		draw_rect(Rect2(x0 - (0.0 if side == 0 else 20.0), gy - 60, bw + 20.0, 8), WOOD_DARK)
		for i in 3:
			draw_rect(Rect2(x0 + 14.0 + float(i) * (bw - 40.0) * 0.5, gy - 56, 8, 62), WOOD_DARK)
		# Finestre.
		for i in 2:
			draw_rect(Rect2(x0 + 20.0 + float(i) * (bw * 0.42), gy - 150, bw * 0.28, 52), Color(0.12, 0.09, 0.07))
			draw_rect(Rect2(x0 + 20.0 + float(i) * (bw * 0.42), gy - 150, bw * 0.28, 52), Color(0.85, 0.7, 0.35, 0.25))


func _draw_audience(w: float, gy: float) -> void:
	if _aud != null:
		_draw_audience_sprites(w, gy)
		return
	var n := mini(system.audience, int(DuelDB.section("audience").get("max_drawn", 16)))
	var s := 0.55
	for i in n:
		var side := i % 2
		var row := i / 2
		var x := w * (0.04 + 0.032 * float(row)) if side == 0 else w * (0.96 - 0.032 * float(row))
		var y := gy + 16.0 + float(row % 3) * 9.0
		var tint := 0.14 + 0.05 * float((i * 7) % 4)
		var col := Color(tint + 0.05, tint, tint - 0.03)
		var star := system.sheriff_present and i == 0
		draw_set_transform(Vector2(x, y), 0.0, Vector2(s, s))
		draw_rect(Rect2(-8, -64, 16, 40), col)
		draw_rect(Rect2(-7, -26, 14, 26), col.darkened(0.2))
		draw_circle(Vector2(0, -74), 8.0, col)
		draw_rect(Rect2(-13, -84, 26, 4), col.darkened(0.3))
		draw_rect(Rect2(-7, -94, 14, 11), col.darkened(0.3))
		if star:
			draw_circle(Vector2(5, -52), 5.0, Color(0.95, 0.8, 0.2))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_person(base: Vector2, facing: int, pose: String, flash: float, shirt: Color, hat: Color, s: float, off: Vector2) -> void:
	# A mezzogiorno l'ombra è quasi sotto i piedi.
	draw_set_transform(off + base, 0.0, Vector2(s, s))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-20, 0), Vector2(-10, -5), Vector2(10, -5), Vector2(20, 0), Vector2(10, 5), Vector2(-10, 5)
	]), SHADOW)

	if pose == "down":
		var f := float(facing)
		draw_rect(Rect2(-30, -16, 60, 16), shirt)
		draw_circle(Vector2(-34.0 * f, -9), 9.0, Color(0.86, 0.68, 0.52))
		draw_rect(Rect2(-46.0 * f - 12.0, -24, 24, 6), hat)
		draw_rect(Rect2(34.0 * f - 10.0, -8, 20, 8), INK)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return

	# Gambe, busto, testa e cappello.
	draw_rect(Rect2(-9, -40, 7, 40), INK)
	draw_rect(Rect2(2, -40, 7, 40), INK)
	draw_rect(Rect2(-12, -80, 24, 42), shirt)
	draw_rect(Rect2(-12, -46, 24, 6), Color(0.35, 0.22, 0.10))
	draw_circle(Vector2(0, -90), 9.5, Color(0.86, 0.68, 0.52))
	draw_rect(Rect2(-16, -98, 32, 4), hat)
	draw_rect(Rect2(-9, -110, 18, 13), hat)

	var f2 := float(facing)
	if pose == "draw":
		var hand := Vector2(f2 * 40.0, -68)
		draw_line(Vector2(f2 * 8.0, -72), hand, shirt.darkened(0.2), 7.0)
		draw_rect(Rect2(min(hand.x, hand.x + f2 * 16.0), hand.y - 5.0, 16, 8), INK)
		if flash > 0.0:
			var tip := hand + Vector2(f2 * 20.0, -1)
			draw_circle(tip, 16.0 * flash + 3.0, Color(1.0, 0.85, 0.25, 0.9 * flash))
			draw_circle(tip, 8.0 * flash + 1.0, Color(1.0, 1.0, 0.85, flash))
	else:
		draw_line(Vector2(f2 * 10.0, -76), Vector2(f2 * 16.0, -52), shirt.darkened(0.2), 7.0)
		draw_rect(Rect2(f2 * 12.0 - 4.0, -54, 8, 8), INK)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ------------------------------------------------------------- restyle a sprite

func _sprite_scale() -> float:
	return clampf(roundf(size.y / 150.0), 3.0, 8.0)


func _walk_k() -> float:
	if not _accepted:
		return 0.0
	if _stage == Stage.INTRO:
		var dur := maxf(0.1, float(DuelDB.section("timing").get("intro_seconds", 2.4)))
		var k := clampf(_t / dur, 0.0, 1.0)
		return 1.0 - (1.0 - k) * (1.0 - k)
	return 1.0


## Piedi del duellante: 0 = giocatore (a sinistra), 1 = avversario (a destra).
func _fpos(side: int) -> Vector2:
	var x0 := size.x * (0.17 if side == 0 else 0.83)
	var x1 := size.x * (0.37 if side == 0 else 0.63)
	return Vector2(lerpf(x0, x1, _walk_k()), size.y * 0.60 + 40.0)


func _play_both(anim: String) -> void:
	if _fp != null:
		_fp.play(anim)
		_fo.play(anim)


## Chi spara per primo estrae con la sequenza rapida, l'altro con l'estrazione normale.
func _start_draws() -> void:
	if _fp == null:
		return
	_first_shooter = ""
	_first_shot_done = false
	for e in system.events:
		var who := str(e.get("who", "narr"))
		if who == "player" or who == "opp":
			_first_shooter = who
			break
	if _first_shooter == "":
		return
	var player_first := _first_shooter == "player"
	(_fp if player_first else _fo).play("quick")
	(_fo if player_first else _fp).play("draw")


func _end_poses() -> void:
	if _fp == null:
		return
	for f in [_fp, _fo]:
		var fighter: DuelFighter = f
		if not fighter.down and (fighter.anim == "draw" or fighter.anim == "shoot" or fighter.anim == "quick"):
			fighter.play("holster")


## Effetti dell'evento di scambio: sparo, ferita, caduta.
func _event_fx(who: String, kind: String) -> void:
	if _fp == null or (who != "player" and who != "opp"):
		return
	var s := _sprite_scale()
	var side := 0 if who == "player" else 1
	var me := _fp if side == 0 else _fo
	var foe := _fo if side == 0 else _fp
	if kind == "down":
		me.fall()
		_burst(_fpos(side) + Vector2(0.0, -4.0), 9, Color(0.85, 0.70, 0.50, 0.8), 70.0, false)
		return
	var face := 1 if side == 0 else -1
	var mz := me.muzzle(_fpos(side), face, s)
	if _first_shot_done or who != _first_shooter:
		me.play("shoot")
	_first_shot_done = true
	var target := foe.chest(_fpos(1 - side), s)
	if kind == "hit":
		foe.hit()
		_tracers.append({"a": mz, "b": target, "t": 0.14})
		_burst(target, 8, Color(0.75, 0.15, 0.10, 0.9), 100.0, false)
	else:
		var away := target + Vector2(float(face) * 280.0, randf_range(-40.0, 30.0))
		_tracers.append({"a": mz, "b": away, "t": 0.14})
		_burst(Vector2(away.x, _fpos(1 - side).y), 6, Color(0.85, 0.70, 0.50, 0.8), 80.0, false)
	_burst(mz, 5, Color(0.9, 0.9, 0.9, 0.7), 30.0, true)


func _burst(pos: Vector2, n: int, col: Color, speed: float, smoke: bool) -> void:
	for i in n:
		var a := randf() * TAU
		var v := Vector2(cos(a), sin(a) * 0.6) * speed * randf_range(0.3, 1.0)
		if smoke:
			v = Vector2(randf_range(-10.0, 10.0), randf_range(-35.0, -15.0))
		_parts.append({
			"p": pos, "v": v, "t": 0.0, "c": col, "smoke": smoke,
			"life": randf_range(0.6, 1.2) if smoke else randf_range(0.3, 0.7),
			"r": randf_range(3.0, 7.0) if smoke else randf_range(2.0, 4.0),
		})


func _update_fx(delta: float) -> void:
	for i in range(_parts.size() - 1, -1, -1):
		var p: Dictionary = _parts[i]
		p["t"] = float(p["t"]) + delta
		p["p"] = Vector2(p["p"]) + Vector2(p["v"]) * delta
		p["v"] = Vector2(p["v"]) * (1.0 - minf(1.0, delta * 2.0))
		if float(p["t"]) >= float(p["life"]):
			_parts.remove_at(i)
	for i in range(_tracers.size() - 1, -1, -1):
		_tracers[i]["t"] = float(_tracers[i]["t"]) - delta
		if float(_tracers[i]["t"]) <= 0.0:
			_tracers.remove_at(i)
	if _stage == Stage.INTRO and _accepted and _walk_k() < 0.98:
		_walk_dust -= delta
		if _walk_dust <= 0.0:
			_walk_dust = 0.12
			for side in 2:
				_burst(_fpos(side) + Vector2(0.0, -2.0), 2, Color(0.85, 0.72, 0.50, 0.6), 30.0, false)


func _draw_fighters(off: Vector2) -> void:
	var s := _sprite_scale()
	_fo.draw(self, _fpos(1) + off, -1, s, Color(1.0, 0.74, 0.64))
	_fp.draw(self, _fpos(0) + off, 1, s, Color.WHITE)
	# Bagliore alla bocca della canna.
	var glows := [[_fp, 0, 1, _flash_p], [_fo, 1, -1, _flash_o]]
	for g in glows:
		if float(g[3]) > 0.0:
			var fighter: DuelFighter = g[0]
			var mz := fighter.muzzle(_fpos(int(g[1])) + off, int(g[2]), s)
			draw_circle(mz, (6.0 + 3.0 * s) * float(g[3]), Color(1.0, 0.85, 0.30, 0.45 * float(g[3])))
	for t in _tracers:
		var a := float(t["t"]) / 0.14
		draw_line(Vector2(t["a"]) + off, Vector2(t["b"]) + off, Color(1.0, 0.92, 0.55, a), 4.0)
		draw_line(Vector2(t["a"]) + off, Vector2(t["b"]) + off, Color(1.0, 1.0, 1.0, a), 1.5)
	for p in _parts:
		var k := float(p["t"]) / float(p["life"])
		var col: Color = p["c"]
		col.a *= 1.0 - k
		var r := float(p["r"]) * (1.0 + (k * 1.5 if bool(p["smoke"]) else 0.0))
		draw_circle(Vector2(p["p"]) + off, r, col)


func _draw_audience_sprites(w: float, gy: float) -> void:
	var n := mini(system.audience, int(DuelDB.section("audience").get("max_drawn", 16)))
	var s := maxf(2.0, _sprite_scale() - 2.0)
	for i in n:
		var side := i % 2
		var row := i / 2
		var x := w * (0.035 + 0.034 * float(row)) if side == 0 else w * (0.965 - 0.034 * float(row))
		var y := gy + 14.0 + float(row % 3) * 10.0
		var tone := 0.55 + 0.06 * float((i * 7) % 5)
		var face := 1 if side == 0 else -1
		_aud.draw_still(self, "idle", int(_clock * 6.0 + float(i) * 2.3), Vector2(x, y), face, s, Color(tone, tone * 0.92, tone * 0.85))
		if system.sheriff_present and i == 0:
			draw_circle(Vector2(x, y - 24.0 * s), 1.6 * s, Color(0.95, 0.80, 0.20))


func _draw_backdrop(w: float, gy: float) -> void:
	if _fp == null:
		return
	# Nuvole lente.
	for i in 3:
		var cx := fmod(w * (0.15 + 0.33 * float(i)) + _clock * (6.0 + 3.0 * float(i)), w + 300.0) - 150.0
		var cy := 64.0 + 40.0 * float(i)
		for j in 4:
			draw_circle(Vector2(cx + float(j) * 26.0, cy + float(j % 2) * 6.0), 18.0 - float(j % 3) * 3.0, Color(1.0, 0.98, 0.90, 0.35))
	# Mesa lontane.
	_mesa(w * 0.18, w * 0.40, 54.0, gy - 6.0, Color(0.74, 0.55, 0.40))
	_mesa(w * 0.55, w * 0.84, 78.0, gy - 6.0, Color(0.80, 0.62, 0.46))


func _mesa(x0: float, x1: float, h: float, base: float, col: Color) -> void:
	var d := x1 - x0
	draw_colored_polygon(PackedVector2Array([
		Vector2(x0, base), Vector2(x0 + d * 0.08, base - h * 0.7), Vector2(x0 + d * 0.14, base - h),
		Vector2(x1 - d * 0.18, base - h), Vector2(x1 - d * 0.08, base - h * 0.8), Vector2(x1, base)
	]), col)
	draw_rect(Rect2(x0 + d * 0.14, base - h, d * 0.68, 5.0), col.lightened(0.12))


func _draw_town(w: float, gy: float) -> void:
	var font := get_theme_default_font()
	var bw := w * 0.21
	var signs := ["SALOON", "BANCA"]
	for side in 2:
		var x0 := 0.0 if side == 0 else w - bw
		var wall := WOOD.lerp(Color(0.62, 0.42, 0.24), 0.35 if side == 0 else 0.15)
		# Corpo, falso frontone e cornicione.
		draw_rect(Rect2(x0, gy - 175.0, bw, 185.0), wall)
		draw_rect(Rect2(x0, gy - 224.0, bw, 52.0), wall.lightened(0.06))
		draw_rect(Rect2(x0 - 4.0, gy - 230.0, bw + 8.0, 8.0), WOOD_DARK)
		for i in int(bw / 16.0):
			draw_line(Vector2(x0 + 8.0 + float(i) * 16.0, gy - 222.0), Vector2(x0 + 8.0 + float(i) * 16.0, gy + 10.0), Color(WOOD_DARK, 0.35), 2.0)
		# Insegna.
		var sr := Rect2(x0 + bw * 0.10, gy - 216.0, bw * 0.80, 36.0)
		draw_rect(sr.grow(3.0), WOOD_DARK)
		draw_rect(sr, Color(0.88, 0.74, 0.46))
		draw_string(font, Vector2(sr.position.x, sr.position.y + 26.0), signs[side], HORIZONTAL_ALIGNMENT_CENTER, sr.size.x, 22, INK)
		# Finestre con riflesso.
		for i in 2:
			var wr := Rect2(x0 + 18.0 + float(i) * bw * 0.44, gy - 146.0, bw * 0.30, 56.0)
			draw_rect(wr.grow(4.0), WOOD_DARK)
			draw_rect(wr, Color(0.16, 0.12, 0.09))
			draw_colored_polygon(PackedVector2Array([
				wr.position + Vector2(6, 0), wr.position + Vector2(20, 0),
				wr.position + Vector2(4, wr.size.y), wr.position + Vector2(0, wr.size.y)
			]), Color(1.0, 0.95, 0.80, 0.16))
			draw_line(Vector2(wr.position.x + wr.size.x * 0.5, wr.position.y), Vector2(wr.position.x + wr.size.x * 0.5, wr.end.y), WOOD_DARK, 3.0)
		# Portico: ombra, tettoia, pali.
		draw_rect(Rect2(x0, gy - 62.0, bw, 70.0), Color(0.0, 0.0, 0.0, 0.18))
		draw_rect(Rect2(x0 - (0.0 if side == 0 else 22.0), gy - 70.0, bw + 22.0, 9.0), WOOD_DARK)
		for i in 3:
			draw_rect(Rect2(x0 + 14.0 + float(i) * (bw - 40.0) * 0.5, gy - 61.0, 8.0, 68.0), WOOD_DARK)
		# Staccionata per i cavalli e botte.
		var rx := x0 + bw - 105.0 if side == 0 else x0 + 15.0
		draw_rect(Rect2(rx, gy - 16.0, 90.0, 6.0), WOOD_DARK)
		draw_rect(Rect2(rx + 4.0, gy - 16.0, 6.0, 26.0), WOOD_DARK)
		draw_rect(Rect2(rx + 80.0, gy - 16.0, 6.0, 26.0), WOOD_DARK)
		var bx := x0 + bw * 0.06 if side == 0 else x0 + bw * 0.94 - 26.0
		draw_rect(Rect2(bx, gy - 30.0, 26.0, 38.0), WOOD)
		draw_rect(Rect2(bx - 1.0, gy - 22.0, 28.0, 3.0), WOOD_DARK)
		draw_rect(Rect2(bx - 1.0, gy - 6.0, 28.0, 3.0), WOOD_DARK)
	# Erba rotolante mentre cala la tensione.
	if _stage >= Stage.INTRO and _stage <= Stage.CUE:
		var tp := Vector2(fmod(_clock * 70.0, w + 160.0) - 80.0, gy + 84.0 - absf(sin(_clock * 3.2)) * 22.0)
		draw_arc(tp, 13.0, 0.0, TAU, 16, Color(0.45, 0.32, 0.18), 2.0)
		for k in 4:
			var a := _clock * 5.0 + float(k) * PI * 0.5
			draw_line(tp - Vector2(cos(a), sin(a)) * 12.0, tp + Vector2(cos(a), sin(a)) * 12.0, Color(0.45, 0.32, 0.18), 1.5)
