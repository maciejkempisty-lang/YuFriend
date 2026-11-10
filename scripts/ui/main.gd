extends Control

const INK := Color("24483d")
const MUTED := Color("6b7663")
const GREEN := Color("315d49")
const CREAM := Color("fff9ed")
const NEED_LABELS := {"fullness": "Sytość", "energy": "Energia", "hygiene": "Czystość", "play": "Zabawa", "contact": "Bliskość"}
const REWARD_LABELS := {"treat": "Smakołyk", "praise": "Pochwała", "play": "Zabawa"}
const NEED_ICONS := {"fullness": "bowl", "energy": "moon", "hygiene": "brush", "play": "ball", "contact": "heart"}
var session := GameSession.new()
var room := RoomView.new()
var needs_ui: Dictionary = {}
var care_buttons: Dictionary = {}
var reward_buttons: Dictionary = {}
var trick_buttons: Dictionary = {}
var tab_buttons: Dictionary = {}
var panels: Dictionary = {}
var name_label: Label
var bond_label: Label
var message_label: Label
var footer_label: Label
var mastery_label: Label
var mastery_bar: ProgressBar
var reward_bar: ProgressBar
var training_hint: Label
var training_footer: Label
var guided_button: Button
var command_button: Button
var journal_list: VBoxContainer
var selected_trick: String = "come"
var selected_tab: String = "care"
var applied_skin: String = ""
var journal_count: int = -1
var profile_dialog: AcceptDialog
var name_edit: LineEdit
var skin_choice: OptionButton
var profile_traits: Label
var text_dialog: AcceptDialog
var command_edit: LineEdit
var save_path_override: String = ""
var journal_signature: String = ""
var header: HBoxContainer
var needs_row: HBoxContainer
var sheet: PanelContainer
var navigation: PanelContainer
var bubble: PanelContainer
var training_actions: HBoxContainer
var rewards_row: HBoxContainer
var training_stage: VBoxContainer
var care_title: Label
var suggestion_title: Label
var suggestion_detail: Label
var album_count: Label
var bold_font: FontVariation
var layout_wide: bool = false

func _ready() -> void:
	get_tree().auto_accept_quit = false
	_build_theme()
	_build_ui()
	resized.connect(_fit_room)
	_fit_room()
	add_child(session)
	session.changed.connect(_refresh)
	session.feedback.connect(func(text: String): message_label.text = text)
	session.clip_requested.connect(room.play_clip)
	session.destination_requested.connect(room.move_to)
	session.performance_requested.connect(room.play_performance)
	room.destination_reached.connect(session.destination_reached)
	room.performance_finished.connect(session.performance_finished)
	session.save_status.connect(func(_ok: bool): _refresh())
	room.floor_tapped.connect(session.move_to)
	room.care_requested.connect(_care_action)
	var path := "user://pet.json"
	if OS.get_cmdline_user_args().has("--qa"): path = "user://qa-ui/pet.json"
	if not save_path_override.is_empty(): path = save_path_override
	session.start(path)
	_refresh()

func _build_theme() -> void:
	var app_theme := Theme.new()
	var regular := FontVariation.new()
	regular.base_font = preload("res://assets/fonts/Nunito.ttf")
	var weight_axis := TextServerManager.get_primary_interface().name_to_tag("wght")
	regular.variation_opentype = {weight_axis: 600.0}
	bold_font = FontVariation.new()
	bold_font.base_font = regular.base_font
	bold_font.variation_opentype = {weight_axis: 800.0}
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
	for type in ["Button", "OptionButton"]:
		app_theme.set_stylebox("normal", type, _style(Color("efeeda"), 12, 10))
		app_theme.set_stylebox("hover", type, _style(Color("e1e7d2"), 12, 10))
		app_theme.set_stylebox("pressed", type, _style(GREEN, 12, 10))
		app_theme.set_color("font_color", type, INK)
		app_theme.set_color("font_hover_color", type, INK)
		app_theme.set_color("font_pressed_color", type, CREAM)
	var focus := _style(Color.TRANSPARENT, 12, 0)
	focus.set_border_width_all(2)
	focus.border_color = Color("879d69")
	app_theme.set_stylebox("focus", "Button", focus)
	app_theme.set_stylebox("focus", "OptionButton", focus)
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
	theme = app_theme

func _style(color: Color, radius: int = 14, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _label(text: String, font_size: int = 16, color: Color = INK, bold: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold: label.add_theme_font_override("font", bold_font)
	return label

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 44)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_font_override("font", bold_font)
	button.add_theme_stylebox_override("normal", _style(GREEN if primary else Color("eeeede"), 14, 10))
	button.add_theme_stylebox_override("hover", _style(Color("43715a") if primary else Color("e1e7d2"), 14, 10))
	button.add_theme_stylebox_override("pressed", _style(Color("234936"), 14, 10))
	button.add_theme_stylebox_override("disabled", _style(Color("edece1"), 14, 10))
	button.add_theme_color_override("font_color", CREAM if primary else INK)
	button.add_theme_color_override("font_hover_color", CREAM if primary else INK)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", Color("999d8d"))
	button.pressed.connect(callback)
	return button

func _icon_button(icon: String, hint: String, callback: Callable) -> Button:
	var button := _button("", callback)
	button.icon = GameIcons.texture(icon)
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 22)
	button.tooltip_text = hint
	button.accessibility_name = hint
	button.custom_minimum_size = Vector2(44, 44)
	button.size_flags_horizontal = Control.SIZE_SHRINK_END
	return button

func _action(icon: String, caption: String, color: Color, callback: Callable) -> IconActionButton:
	var button := IconActionButton.new()
	button.icon_name = icon
	button.caption = caption
	button.accent = color
	button.pressed.connect(callback)
	return button

func _bar(color: Color, height: int = 6) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = height
	progress.add_theme_stylebox_override("background", _style(Color("e7e8d8"), height, 0))
	progress.add_theme_stylebox_override("fill", _style(color, height, 0))
	return progress

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("f3efdf")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	add_child(room)
	header = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", -2)
	header.add_child(identity)
	identity.add_child(_label("yufriend.", 17, GREEN, true))
	name_label = _label("Biszkopt", 34, INK, true)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	identity.add_child(name_label)
	bond_label = _label("Szczeniak · Poznajecie się", 13, MUTED)
	identity.add_child(bond_label)
	var profile := _icon_button("settings", "Profil pieska", _show_profile)
	profile.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header.add_child(profile)
	needs_row = HBoxContainer.new()
	needs_row.add_theme_constant_override("separation", 8)
	add_child(needs_row)
	for key in PetState.NEED_KEYS:
		var need := NeedIndicator.new()
		need.caption = NEED_LABELS[key]
		need.icon_name = NEED_ICONS[key]
		needs_row.add_child(need)
		needs_ui[key] = need
	bubble = PanelContainer.new()
	var bubble_style := _style(Color("fff9edee"), 17, 10)
	bubble_style.content_margin_top = 6
	bubble_style.content_margin_bottom = 6
	bubble_style.shadow_color = Color(0.25, 0.30, 0.17, 0.06)
	bubble_style.shadow_size = 10
	bubble.add_theme_stylebox_override("panel", bubble_style)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	message_label = _label("Witaj w Waszym małym domu.", 14)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.max_lines_visible = 2
	message_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.add_child(message_label)
	sheet = PanelContainer.new()
	var sheet_style := _style(CREAM, 26, 18)
	sheet_style.shadow_color = Color(0.25, 0.30, 0.17, 0.07)
	sheet_style.shadow_size = 16
	sheet_style.shadow_offset = Vector2(0, -3)
	sheet.add_theme_stylebox_override("panel", sheet_style)
	add_child(sheet)
	panels.care = _build_care()
	panels.training = _build_training()
	panels.journal = _build_journal()
	for key in panels:
		sheet.add_child(panels[key])
		panels[key].visible = key == selected_tab
	navigation = PanelContainer.new()
	navigation.add_theme_stylebox_override("panel", _style(CREAM, 23, 3))
	add_child(navigation)
	var nav_row := HBoxContainer.new()
	navigation.add_child(nav_row)
	for key in ["care", "training", "journal"]:
		var button := _action({"care": "home", "training": "spark", "journal": "book"}[key], {"care": "Dom", "training": "Trening", "journal": "Album"}[key], Color.TRANSPARENT, _select_tab.bind(key))
		button.navigation = true
		button.selected = key == selected_tab
		nav_row.add_child(button)
		tab_buttons[key] = button
	footer_label = _label("", 12, Color("a2553b"))
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	footer_label.hide()
	add_child(footer_label)
	_build_dialogs()

func _build_care() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	care_title = _label("Wasza chwila", 19, INK, true)
	care_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(care_title)
	heading.add_child(_label("MAŁE RYTUAŁY", 10, MUTED, true))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 3)
	box.add_child(actions)
	var labels := {"feed": "Jedzenie", "pet": "Głaskanie", "play": "Zabawa", "clean": "Czesanie", "rest": "Drzemka"}
	var icons := {"feed": "bowl", "pet": "heart", "play": "ball", "clean": "brush", "rest": "moon"}
	var colors := {"feed": Color("f6ddb0"), "pet": Color("f3d7c8"), "play": Color("e2e9bd"), "clean": Color("d5e6dc"), "rest": Color("e0def0")}
	for key in ["feed", "pet", "play", "clean", "rest"]:
		var button := _action(icons[key], labels[key], colors[key], _care_action.bind(key))
		actions.add_child(button)
		care_buttons[key] = button
	var suggestion := _button("", _care_action.bind("train"), true)
	suggestion.custom_minimum_size.y = 58
	box.add_child(suggestion)
	care_buttons.train = suggestion
	suggestion.accessibility_name = "Poćwiczmy razem"
	var content := HBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.offset_left = 14
	content.offset_right = -14
	content.add_theme_constant_override("separation", 12)
	suggestion.add_child(content)
	var icon := TextureRect.new()
	icon.texture = GameIcons.texture("spark", Color("e9d69c"))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size.x = 28
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(icon)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titles.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	titles.add_theme_constant_override("separation", 0)
	titles.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(titles)
	suggestion_title = _label("Nauczmy się czegoś", 16, CREAM, true)
	titles.add_child(suggestion_title)
	suggestion_detail = _label("Mały gest. Pierwszy wspólny sukces.", 11, Color("cfddbf"))
	titles.add_child(suggestion_detail)
	var arrow := _label("→", 24, Color("e9d69c"))
	arrow.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	content.add_child(arrow)
	return box

func _build_training() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title := _label("Wspólne ćwiczenia", 19, INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	var text_button := _icon_button("keyboard", "Wpisz komendę", _show_command)
	text_button.custom_minimum_size = Vector2(36, 30)
	text_button.add_theme_stylebox_override("normal", _style(Color.TRANSPARENT, 8, 4))
	heading.add_child(text_button)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	box.add_child(choices)
	for key in PetState.TRICK_KEYS:
		var button := _button(TrainingSystem.LABELS[key], _choose_trick.bind(key))
		button.add_theme_font_size_override("font_size", 14)
		choices.add_child(button)
		trick_buttons[key] = button
	var progress := VBoxContainer.new()
	progress.add_theme_constant_override("separation", 4)
	box.add_child(progress)
	mastery_label = _label("Poznaje pierwszą komendę", 13, MUTED)
	progress.add_child(mastery_label)
	mastery_bar = _bar(Color("91a871"), 5)
	progress.add_child(mastery_bar)
	training_stage = VBoxContainer.new()
	training_stage.add_theme_constant_override("separation", 6)
	box.add_child(training_stage)
	training_hint = _label("Pokaż gest, poczekaj i nagródź.", 14)
	training_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	training_hint.max_lines_visible = 2
	training_stage.add_child(training_hint)
	reward_bar = _bar(Color("daab59"), 6)
	training_stage.add_child(reward_bar)
	training_actions = HBoxContainer.new()
	training_actions.add_theme_constant_override("separation", 8)
	training_stage.add_child(training_actions)
	guided_button = _button("Pokaż gest", _train.bind(true), true)
	command_button = _button("Samodzielnie", _train.bind(false))
	training_actions.add_child(guided_button)
	training_actions.add_child(command_button)
	rewards_row = HBoxContainer.new()
	rewards_row.add_theme_constant_override("separation", 8)
	training_stage.add_child(rewards_row)
	for key in TrainingSystem.REWARDS:
		var button := _button(REWARD_LABELS[key], _reward.bind(key), key == "treat")
		button.add_theme_font_size_override("font_size", 13)
		rewards_row.add_child(button)
		reward_buttons[key] = button
	training_footer = _label("", 12, MUTED)
	box.add_child(training_footer)
	return box

func _build_journal() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var heading := HBoxContainer.new()
	box.add_child(heading)
	var title := _label("Wasza mała historia", 20, INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	album_count = _label("", 12, MUTED)
	heading.add_child(album_count)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	journal_list = VBoxContainer.new()
	journal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_list.add_theme_constant_override("separation", 10)
	scroll.add_child(journal_list)
	return box

func _build_dialogs() -> void:
	var shade := ColorRect.new()
	shade.color = Color(0.15, 0.20, 0.16, 0.22)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 100
	shade.hide()
	add_child(shade)
	profile_dialog = AcceptDialog.new()
	profile_dialog.title = "Twój mały przyjaciel"
	profile_dialog.ok_button_text = "Zapisz"
	profile_dialog.min_size = Vector2i(320, 300)
	add_child(profile_dialog)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	profile_dialog.add_child(box)
	box.add_child(_label("Jak ma na imię?", 18))
	name_edit = LineEdit.new()
	name_edit.max_length = 24
	name_edit.custom_minimum_size.y = 40
	box.add_child(name_edit)
	box.add_child(_label("Wygląd pieska", 16))
	skin_choice = OptionButton.new()
	skin_choice.add_item("Miękka ilustracja 2D")
	skin_choice.add_item("Pixel art")
	skin_choice.custom_minimum_size.y = 40
	box.add_child(skin_choice)
	profile_traits = _label("", 15, MUTED)
	# Explicit short lines keep the dialog minimum height stable before opening.
	box.add_child(profile_traits)
	profile_dialog.confirmed.connect(func():
		session.rename_pet(name_edit.text)
		session.change_skin("simple" if skin_choice.selected == 0 else "pixel"))
	text_dialog = AcceptDialog.new()
	text_dialog.title = "Napisz komendę"
	text_dialog.ok_button_text = "Poproś"
	text_dialog.min_size = Vector2i(320, 150)
	add_child(text_dialog)
	var command_box := VBoxContainer.new()
	command_box.add_theme_constant_override("separation", 10)
	text_dialog.add_child(command_box)
	command_box.add_child(_label("Przyjdź, usiądź albo podaj łapę.", 16))
	command_edit = LineEdit.new()
	command_edit.placeholder_text = "Na przykład: usiądź"
	command_edit.max_length = 80
	command_edit.custom_minimum_size.y = 40
	command_box.add_child(command_edit)
	text_dialog.confirmed.connect(_submit_command)
	command_edit.text_submitted.connect(func(_text: String):
		text_dialog.hide()
		_submit_command())
	var update_shade := func(): shade.visible = profile_dialog.visible or text_dialog.visible
	profile_dialog.visibility_changed.connect(update_shade)
	text_dialog.visibility_changed.connect(update_shade)

func _select_tab(key: String) -> void:
	selected_tab = key
	for tab in panels:
		panels[tab].visible = tab == key
		tab_buttons[tab].selected = tab == key
	_fit_room()
	_refresh()

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _fit_room() -> void:
	if sheet == null: return
	layout_wide = size.x >= 760 and size.x > size.y * 1.2
	var rail := clampf(size.x * 0.38, 350, 420) if layout_wide else size.x
	var scene_width := size.x - rail if layout_wide else size.x
	var inset := 24.0 if size.x >= 390 else 16.0
	var scene_inset := maxf(inset, (scene_width - 540) / 2)
	var panel_height := 214.0 if selected_tab == "care" else 270.0
	if selected_tab == "journal": panel_height = 284.0
	var panel_x := scene_width + 12 if layout_wide else 12.0
	var panel_width := rail - 24
	var nav_y := size.y - 86
	var warning_space := 44.0 if footer_label.visible else 0.0
	var panel_top := nav_y - panel_height - 12 - warning_space
	var rail_top := maxf(24, (size.y - panel_height - 266 - warning_space) / 2)
	if layout_wide:
		panel_top = rail_top + 182
		nav_y = panel_top + panel_height + 12 + warning_space
	_place(room, Rect2(0, 0, scene_width, size.y if layout_wide else panel_top + 36))
	if layout_wide:
		_place(header, Rect2(panel_x + 12, rail_top, panel_width - 24, 82))
		_place(needs_row, Rect2(panel_x + 8, rail_top + 96, panel_width - 16, 62))
	else:
		_place(header, Rect2(scene_inset, 20, scene_width - scene_inset * 2, 82))
		_place(needs_row, Rect2(scene_inset - 4, 116, scene_width - scene_inset * 2 + 8, 62))
	_place(sheet, Rect2(panel_x, panel_top, panel_width, panel_height))
	_place(navigation, Rect2(panel_x, nav_y, panel_width, 72))
	var bubble_width := minf(scene_width - 48, 410)
	var bubble_y := size.y - 94 if layout_wide else panel_top - 64
	_place(bubble, Rect2((scene_width - bubble_width) / 2, bubble_y, bubble_width, 54))
	_place(footer_label, Rect2(panel_x + 10, nav_y - 42, panel_width - 20, 40))
	room.update_placement()

func _choose_trick(key: String) -> void:
	if session.training.phase != "idle": return
	selected_trick = key
	_refresh()

func _care_action(key: String) -> void:
	if key == "train": _select_tab("training")
	else: session.act(key)

func _train(guided: bool) -> void:
	session.begin_training(selected_trick, guided)

func _reward(kind: String) -> void:
	session.give_reward(kind)

func _show_profile() -> void:
	if session.pet == null: return
	name_edit.text = session.pet.pet_name
	skin_choice.select(0 if session.pet.skin == "simple" else 1)
	profile_traits.text = "Ciekawość %d%% · Cierpliwość %d%%\nTowarzyskość %d%% · Wrażliwość %d%%\nUlubiona nagroda: %s" % [
		roundi(float(session.pet.traits.curiosity) * 100), roundi(float(session.pet.traits.patience) * 100),
		roundi(float(session.pet.traits.sociability) * 100), roundi(float(session.pet.traits.sensitivity) * 100), REWARD_LABELS[session.pet.favorite_reward].to_lower()]
	profile_dialog.popup_centered(Vector2i(336, 340))
	name_edit.grab_focus()

func _show_command() -> void:
	text_dialog.popup_centered(Vector2i(336, 170))
	command_edit.grab_focus()

func _submit_command() -> void:
	if session.busy():
		session.say("Dokończmy najpierw tę czynność.")
		return
	var key := LocalCommands.interpret(command_edit.text)
	if key.is_empty():
		session.say("Ćwiczymy: przyjdź, siad i podaj łapę. Spróbuj jednej z tych komend.")
		return
	_choose_trick(key)
	_train(false)

func _refresh() -> void:
	if session.pet == null or name_label == null: return
	var pet := session.pet
	name_label.text = pet.pet_name
	bond_label.text = "Szczeniak  ·  %s" % ("Poznajecie się" if pet.bond < 25 else ("Coraz bliżej" if pet.bond < 60 else "Najlepsi przyjaciele"))
	bond_label.tooltip_text = "Wasza więź: %d%%" % roundi(pet.bond)
	message_label.text = session.last_message
	for key in needs_ui: needs_ui[key].value = float(pet.needs[key])
	if applied_skin != pet.skin:
		applied_skin = pet.skin
		room.animator.set_skin(load("res://data/skins/puppy_%s.tres" % pet.skin))
	for key in care_buttons:
		care_buttons[key].disabled = not session.writable or (key != "train" and (session.busy() or float(session.cooldowns.get(key, 0)) > 0 or (pet.resting and key != "rest")))
		care_buttons[key].queue_redraw()
	care_buttons.rest.caption = "Obudź" if pet.resting else "Drzemka"
	care_buttons.rest.icon_name = "sun" if pet.resting else "moon"
	care_title.text = "Czas na spokojny sen" if pet.resting else "Wasza chwila"
	suggestion_title.text = "Poćwiczmy razem"
	suggestion_detail.text = "%s · opanowanie %d%%" % [TrainingSystem.LABELS[selected_trick], roundi(pet.skills[selected_trick].mastery)]
	var mastery: float = pet.skills[selected_trick].mastery
	var level := "Poznaje gest" if mastery < 25 else ("Ćwiczy z Tobą" if mastery < 75 else "Coraz pewniej")
	mastery_label.text = "%s   ·   %d%% opanowania" % [level, roundi(mastery)]
	mastery_bar.value = mastery
	var reason := session.training.readiness(pet, selected_trick)
	guided_button.disabled = not session.writable or session.busy() or not reason.is_empty()
	command_button.disabled = guided_button.disabled
	for key in trick_buttons:
		trick_buttons[key].disabled = session.training.phase != "idle"
		trick_buttons[key].add_theme_stylebox_override("normal", _style(Color("e0e9cf") if key == selected_trick else Color("f1efe2"), 13, 10))
		trick_buttons[key].add_theme_stylebox_override("disabled", _style(Color("e0e9cf") if key == selected_trick else Color("f1efe2"), 13, 10))
		trick_buttons[key].add_theme_color_override("font_disabled_color", INK if key == selected_trick else Color("9b9e8c"))
	var rewarding := session.training.phase == "reward"
	var attempting := session.training.phase == "attempt"
	training_actions.visible = not rewarding and not attempting
	rewards_row.visible = rewarding or attempting
	reward_bar.visible = rewarding or attempting
	reward_bar.value = maxf(0, session.training.time_left / session.training.reward_duration * 100) if rewarding else 0
	for key in reward_buttons: reward_buttons[key].disabled = not rewarding or not session.writable
	if rewarding: training_hint.text = "Świetnie! Nagroda teraz — %.1f s" % session.training.time_left
	elif attempting: training_hint.text = "Patrz na pieska… zaraz czas na nagrodę."
	elif not reason.is_empty(): training_hint.text = reason
	else: training_hint.text = "Pokaż gest. Poczekaj na wykonanie. Nagrodź."
	training_hint.add_theme_color_override("font_color", Color("8a5f24") if rewarding else INK)
	training_footer.text = "Skupienie %d%%  ·  Krótkie ćwiczenia, dużo radości" % roundi(100 - pet.fatigue)
	var had_warning := footer_label.visible
	footer_label.visible = not session.writable or not session.save_ok
	if had_warning != footer_label.visible: _fit_room()
	if not session.writable: footer_label.text = "Nie udało się odczytać postępu. Zapis zachowano."
	elif not session.save_ok: footer_label.text = "Postęp czeka na zapis. Sprawdź wolne miejsce."
	var signature := str(pet.journal.size()) + (str(pet.journal[0].key) if not pet.journal.is_empty() else "")
	if journal_signature != signature:
		journal_signature = signature
		journal_count = pet.journal.size()
		var plural := "chwile" if journal_count % 10 in [2, 3, 4] and journal_count % 100 not in [12, 13, 14] else "chwil"
		album_count.text = "%d %s" % [journal_count, "chwila" if journal_count == 1 else plural]
		for child in journal_list.get_children():
			journal_list.remove_child(child)
			child.queue_free()
		if pet.journal.is_empty():
			var empty := _label("Pierwsze głaskanie, wspólna miska, udany siad. Tu zostaną Wasze małe wielkie chwile.", 15, MUTED)
			empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			journal_list.add_child(empty)
		for entry in pet.journal:
			var item := HBoxContainer.new()
			item.add_theme_constant_override("separation", 12)
			journal_list.add_child(item)
			var mark := TextureRect.new()
			mark.texture = GameIcons.texture("paw", Color("9ca97b"))
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.custom_minimum_size = Vector2(25, 25)
			mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			item.add_child(mark)
			var words := VBoxContainer.new()
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			words.add_theme_constant_override("separation", 2)
			item.add_child(words)
			var date := Time.get_datetime_dict_from_unix_time(int(entry.at) + int(Time.get_time_zone_from_system().bias) * 60)
			words.add_child(_label("%02d.%02d · %02d:%02d" % [date.day, date.month, date.hour, date.minute], 11, MUTED))
			var title := _label(entry.title, 16, INK, true)
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			words.add_child(title)
			var detail := _label(entry.detail, 13, MUTED)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			words.add_child(detail)

func _notification(what: int) -> void:
	if not is_instance_valid(session) or not session.active: return
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		session.flush()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		session.suspend_session()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		session.resume_session()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		session.flush()
