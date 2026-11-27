class_name GameTheme
extends RefCounted
## Shared theme for every YuFriend shell (Main.tscn + LevelRoom). Mirrors what
## scripts/ui/main.gd#_build_theme ships; one source of truth so the editor-driven
## LevelRoom matches the handcrafted game's look (Nunito, cream buttons, ink text).

const INK := Color("24483d")
const MUTED := Color("6b7663")
const GREEN := Color("315d49")
const CREAM := Color("fff9ed")

static func build() -> Theme:
	var app_theme := Theme.new()
	var regular := FontVariation.new()
	regular.base_font = load("res://assets/fonts/Nunito.ttf")
	var weight_axis := TextServerManager.get_primary_interface().name_to_tag("wght")
	regular.variation_opentype = {weight_axis: 600.0}
	app_theme.default_font = regular
	app_theme.default_font_size = 16
	app_theme.set_color("font_color", "Label", INK)
	app_theme.set_stylebox("panel", "AcceptDialog", _style(CREAM, 18, 18))
	var window_border := _style(GREEN, 18, 8)
	window_border.content_margin_top = 34
	window_border.expand_margin_top = 34
	window_border.expand_margin_left = 5
	window_border.expand_margin_right = 5
	window_border.expand_margin_bottom = 5
	app_theme.set_stylebox("embedded_border", "Window", window_border)
	app_theme.set_stylebox("embedded_unfocused_border", "Window", window_border)
	app_theme.set_color("title_color", "Window", CREAM)
	for type in ["Button", "OptionButton", "CheckBox"]:
		app_theme.set_stylebox("normal", type, _style(Color("efeeda"), 12, 10))
		app_theme.set_stylebox("hover", type, _style(Color("e1e7d2"), 12, 10))
		app_theme.set_stylebox("pressed", type, _style(GREEN, 12, 10))
		app_theme.set_color("font_color", type, INK)
		app_theme.set_color("font_hover_color", type, INK)
		app_theme.set_color("font_focus_color", type, INK)
		app_theme.set_color("font_pressed_color", type, CREAM)
	var focus := _style(Color.TRANSPARENT, 12, 0)
	focus.set_border_width_all(2)
	focus.border_color = Color("879d69")
	app_theme.set_stylebox("focus", "Button", focus)
	app_theme.set_stylebox("focus", "OptionButton", focus)
	app_theme.set_stylebox("focus", "CheckBox", focus)
	app_theme.set_stylebox("normal", "LineEdit", _style(Color("f0efdf"), 12, 10))
	app_theme.set_stylebox("focus", "LineEdit", focus)
	app_theme.set_color("font_color", "LineEdit", INK)
	app_theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	app_theme.set_color("caret_color", "LineEdit", INK)
	app_theme.set_stylebox("panel", "PopupMenu", _style(CREAM, 12, 8))
	app_theme.set_stylebox("hover", "PopupMenu", _style(GREEN, 8, 8))
	app_theme.set_color("font_color", "PopupMenu", INK)
	app_theme.set_color("font_hover_color", "PopupMenu", CREAM)
	app_theme.set_stylebox("panel", "TooltipPanel", _style(INK, 10, 8))
	app_theme.set_color("font_color", "TooltipLabel", CREAM)
	# ProgressBar: cream track, green fill matches the home palette.
	app_theme.set_stylebox("background", "ProgressBar", _style(Color("efeeda"), 8, 2))
	app_theme.set_stylebox("fill", "ProgressBar", _style(Color("879d69"), 8, 2))
	app_theme.set_color("font_color", "ProgressBar", INK)
	return app_theme

static func _style(color: Color, radius: int = 14, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding - 2
	style.content_margin_bottom = padding - 2
	return style
