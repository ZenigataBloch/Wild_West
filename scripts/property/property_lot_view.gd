class_name PropertyLotView
extends Node2D
## Aspetto di un lotto libero della città (disegnato da codice, sostituibile con sprite):
## cartello "IN VENDITA", terreno recintato con il tuo nome, cantiere con ponteggi e, a lavori finiti,
## la facciata di casa o negozio (BuildingFacade, come gli altri edifici).
## PropertyManager chiama refresh() quando lo stato delle proprietà cambia.

var lot_id := -1

var _rect := Rect2()
var _size := Vector2(240, 220)
var _door_bottom := true
var _state := "free"
var _facade: BuildingFacade = null
var _facade_kind := ""


func setup(id: int, rect: Rect2, door_bottom: bool) -> void:
	lot_id = id
	_rect = rect
	_size = rect.size
	_door_bottom = door_bottom
	position = rect.position
	z_index = 1
	refresh()


func refresh() -> void:
	_state = PropertySystem.state_of(lot_id)
	var built := _state == "casa" or _state == "negozio"
	if _facade != null and (not built or _facade_kind != _state):
		_facade.queue_free()
		_facade = null
		_facade_kind = ""
	if built and _facade == null:
		_facade = BuildingFacade.new()
		add_child(_facade)
		_facade.setup(_rect, PropertySystem.type_def(_state).duplicate(), _door_bottom)
		_facade.position = Vector2.ZERO   # la facciata sta già nel sistema di coordinate di questo nodo
		_facade_kind = _state
	queue_redraw()


func _draw() -> void:
	var edge := WesternTheme.color("wood_dark")
	var wood := WesternTheme.color("wood")
	var gold := WesternTheme.color("gold")
	var board_y := _size.y - 64.0 if _door_bottom else 40.0
	var center_x := _size.x * 0.5
	match _state:
		"free":
			_board(Vector2(center_x, board_y), str(PropertySystem.section("signs").get("free", "IN VENDITA")), edge, wood, gold)
		"terreno":
			_fence(12.0, wood)
			_board(Vector2(center_x, board_y), "PROPRIETÀ DI %s" % PlayerState.player_name.to_upper(), edge, wood, gold)
		"building":
			_fence(12.0, wood)
			# Ponteggi: pali e diagonali al centro del lotto
			var r := Rect2(_size * 0.2, _size * 0.6)
			draw_rect(r, wood, false, 3.0)
			draw_line(r.position, r.end, wood, 2.0)
			draw_line(Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.end.y), wood, 2.0)
			_board(Vector2(center_x, board_y), str(PropertySystem.section("signs").get("building", "CANTIERE")), edge, wood, gold)
		_:
			pass   # casa e negozio: ci pensa la facciata


func _fence(inset: float, color: Color) -> void:
	var r := Rect2(Vector2(inset, inset), _size - Vector2(inset * 2.0, inset * 2.0))
	draw_rect(r, color, false, 3.0)
	var x := r.position.x
	while x <= r.end.x:
		draw_line(Vector2(x, r.position.y - 5.0), Vector2(x, r.position.y + 5.0), color, 4.0)
		draw_line(Vector2(x, r.end.y - 5.0), Vector2(x, r.end.y + 5.0), color, 4.0)
		x += 30.0
	var y := r.position.y
	while y <= r.end.y:
		draw_line(Vector2(r.position.x - 5.0, y), Vector2(r.position.x + 5.0, y), color, 4.0)
		draw_line(Vector2(r.end.x - 5.0, y), Vector2(r.end.x + 5.0, y), color, 4.0)
		y += 30.0


## Cartello su due pali, centrato in `center`.
func _board(center: Vector2, label: String, edge: Color, wood: Color, gold: Color) -> void:
	var font := WesternTheme.get_font()
	var fs := 14
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var bw := minf(tw + 20.0, _size.x - 24.0)
	var r := Rect2(center.x - bw * 0.5, center.y - 12.0, bw, 24.0)
	draw_line(Vector2(r.position.x + bw * 0.2, r.end.y), Vector2(r.position.x + bw * 0.2, r.end.y + 22.0), edge, 3.0)
	draw_line(Vector2(r.end.x - bw * 0.2, r.end.y), Vector2(r.end.x - bw * 0.2, r.end.y + 22.0), edge, 3.0)
	draw_rect(r, wood)
	draw_rect(r, gold, false, 2.0)
	draw_string(font, Vector2(r.position.x, r.position.y + 17.0), label, HORIZONTAL_ALIGNMENT_CENTER, bw, fs, gold)
