class_name WesternTheme
extends RefCounted
## Costruisce il Theme western da data/ui_theme.json.
## Uso: WesternTheme.apply(mio_control)  -> tutti i figli ereditano lo stile.

const CONFIG_PATH := "res://data/ui_theme.json"

const DEFAULTS := {
	"palette": {
		"wood_dark": "#2b1b10", "wood": "#4a2f1a", "wood_light": "#6b4527",
		"parchment": "#e6d3a3", "parchment_dark": "#c9b078", "ink": "#2a1a0e",
		"gold": "#d4a53a", "gold_dark": "#8a6a1f", "blood": "#8c1c13",
		"health_bg": "#3a1410", "ok": "#5a7a2e"
	},
	"font": {
		"file": "", "fallback_names": ["Georgia", "serif"], "size": 18, "title_size": 26
	},
	"panel": {"border": 4, "radius": 6, "margin": 14, "title_height": 34, "open_time": 0.22},
	"shader": {"grain": 0.07, "vignette": 0.30}
}

static var _cache: Theme
static var _config: Dictionary = {}


static func config() -> Dictionary:
	if _config.is_empty():
		_config = DEFAULTS.duplicate(true)
		if FileAccess.file_exists(CONFIG_PATH):
			var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
			if parsed is Dictionary:
				for section in parsed:
					if _config.has(section) and _config[section] is Dictionary:
						_config[section].merge(parsed[section], true)
					else:
						_config[section] = parsed[section]
	return _config


static func color(key: String) -> Color:
	return Color(config()["palette"].get(key, "#ff00ff"))


static func get_theme() -> Theme:
	if _cache == null:
		_cache = _build()
	return _cache


static func apply(control: Control) -> void:
	control.theme = get_theme()


static func get_font() -> Font:
	var f: Dictionary = config()["font"]
	var path: String = f.get("file", "")
	if path != "" and ResourceLoader.exists(path):
		return load(path)
	var sys := SystemFont.new()
	sys.font_names = PackedStringArray(f.get("fallback_names", ["serif"]))
	sys.font_weight = 700
	return sys


static func box(bg: Color, border: Color, border_w: int = 3, radius: int = 6, margin: int = 10) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0, 3)
	return sb


static func _build() -> Theme:
	var cfg := config()
	var p: Dictionary = cfg["panel"]
	var fnt: Dictionary = cfg["font"]
	var t := Theme.new()
	var font := get_font()
	t.default_font = font
	t.default_font_size = int(fnt["size"])

	var bw := int(p["border"])
	var rad := int(p["radius"])
	var mar := int(p["margin"])

	# Pannelli: legno scuro con bordo oro, interno pergamena per le schede
	var wood := box(color("wood_dark"), color("gold_dark"), bw, rad, mar)
	t.set_stylebox("panel", "Panel", wood)
	t.set_stylebox("panel", "PanelContainer", wood)

	var paper := box(color("parchment"), color("wood"), bw, rad, mar)
	t.set_stylebox("panel", "PaperPanel", paper)
	t.set_type_variation("PaperPanel", "PanelContainer")

	# Label: testo pergamena su legno; variante "Ink" per testo su carta
	t.set_color("font_color", "Label", color("parchment"))
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.6))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_color("font_color", "InkLabel", color("ink"))
	t.set_color("font_shadow_color", "InkLabel", Color(1, 1, 1, 0.0))
	t.set_type_variation("InkLabel", "Label")
	t.set_color("font_color", "TitleLabel", color("gold"))
	t.set_font_size("font_size", "TitleLabel", int(fnt["title_size"]))
	t.set_type_variation("TitleLabel", "Label")

	# Bottoni: tavola di legno, hover oro, pressed incassato
	var b_n := box(color("wood"), color("gold_dark"), 3, 4, 10)
	var b_h := box(color("wood_light"), color("gold"), 3, 4, 10)
	var b_p := box(color("wood_dark"), color("gold"), 3, 4, 10)
	b_p.content_margin_top += 2
	b_p.shadow_size = 1
	var b_d := box(Color(0.2, 0.15, 0.1), Color(0.35, 0.3, 0.2), 3, 4, 10)
	var b_f := box(Color(0, 0, 0, 0), color("gold"), 2, 4, 10)
	b_f.shadow_size = 0
	t.set_stylebox("normal", "Button", b_n)
	t.set_stylebox("hover", "Button", b_h)
	t.set_stylebox("pressed", "Button", b_p)
	t.set_stylebox("disabled", "Button", b_d)
	t.set_stylebox("focus", "Button", b_f)
	t.set_color("font_color", "Button", color("parchment"))
	t.set_color("font_hover_color", "Button", color("gold"))
	t.set_color("font_pressed_color", "Button", color("gold"))
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.45, 0.35))

	# Barre (salute ecc.)
	var bar_bg := box(color("health_bg"), color("wood_dark"), 2, 3, 0)
	bar_bg.shadow_size = 0
	var bar_fill := box(color("blood"), color("blood").lightened(0.25), 1, 3, 0)
	bar_fill.shadow_size = 0
	t.set_stylebox("background", "ProgressBar", bar_bg)
	t.set_stylebox("fill", "ProgressBar", bar_fill)
	t.set_color("font_color", "ProgressBar", color("parchment"))
	t.set_color("font_outline_color", "ProgressBar", Color(0, 0, 0, 0.8))
	t.set_constant("outline_size", "ProgressBar", 3)

	# Separatori e tooltip
	var sep := StyleBoxLine.new()
	sep.color = color("gold_dark")
	sep.thickness = 2
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_stylebox("panel", "TooltipPanel", box(color("parchment"), color("wood"), 2, 3, 6))
	t.set_color("font_color", "TooltipLabel", color("ink"))

	# Liste (zaino)
	t.set_stylebox("panel", "ItemList", box(color("wood_dark").darkened(0.25), color("wood"), 2, 3, 6))
	t.set_stylebox("selected", "ItemList", box(color("wood_light"), color("gold"), 2, 2, 4))
	t.set_stylebox("selected_focus", "ItemList", box(color("wood_light"), color("gold"), 2, 2, 4))
	t.set_color("font_color", "ItemList", color("parchment"))
	t.set_color("font_selected_color", "ItemList", color("gold"))
	return t
