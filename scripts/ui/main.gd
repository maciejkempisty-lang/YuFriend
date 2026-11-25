class_name GameUI
extends Control

const INK := Color("24483d")
const MUTED := Color("6b7663")
const GREEN := Color("315d49")
const CREAM := Color("fff9ed")
const NEED_LABELS := {"fullness": "Sytość", "energy": "Energia", "hygiene": "Czystość", "play": "Zabawa", "contact": "Bliskość"}
const REWARD_LABELS := {"treat": "Smakołyk", "praise": "Pochwała", "play": "Zabawa"}
const NEED_ICONS := {"fullness": "bowl", "energy": "moon", "hygiene": "brush", "play": "ball", "contact": "heart"}
var first_meeting: AcceptDialog
var first_name: LineEdit
var first_error: Label
# While true the puppy has no chosen name yet; the header avoids the default one.
var naming_pending := false
var enable_test_onboarding := false
var potty_action: Button
var care_actions: HBoxContainer
var _yard_layout_key := ""
var session := GameSession.new()
var music := BackgroundMusic.new()
var music_toggle: CheckButton
var effects := SoundEffects.new()
var effects_toggle: CheckButton
var haptics := HapticFeedback.new()
var haptics_toggle: CheckButton
var reminders := LocalReminders.new()
var reminders_toggle: CheckButton
var reminders_status: Label
var reminder_poll := 0.0
var room := RoomView.new()
var needs_ui: Dictionary = {}
var care_buttons: Dictionary = {}
var photos_list: VBoxContainer
var photo_signature := ""
var taking_photo := false
var bath_dialog: AcceptDialog
var yard_toolbar: HBoxContainer
var yard_menu := YardActionMenu.new()
var yard_transition := YardTransition.new()
var yard_command_button: Button
var water_splash_button: Button
var yard_rest_stop: Button
var course_action: Button
var course_stop: Button
var water_shake_button: Button
var yard_invite_accept: Button
var yard_invite_later: Button
var visitor_toolbar: HBoxContainer
var today_button: Button
var visitor_soothe_button: Button
var visitor_recall_button: Button
var visitor_interact_button: Button
var visitor_dialog: AcceptDialog
var visitor_dialog_kind := ""
var yard_bath_button: Button
var yard_button: Button
var sniff_button: Button
var reward_buttons: Dictionary = {}
var trick_buttons: Dictionary = {}
var gesture_dialog: AcceptDialog
var tab_buttons: Dictionary = {}
var panels: Dictionary = {}
var name_label: Button
var wellbeing_dialog: AcceptDialog
var wellbeing_button: WellbeingButton
var cuddle_dialog: AcceptDialog
var cuddle_view: CuddleView
var cuddle_hint: Label
var bond_label: Label
var bond_detail: Label
var message_label: Label
var footer_label: Label
var practice_label: Label
var mastery_label: Label
var mastery_bar: ProgressBar
var training_hint: Label
var training_footer: Label
var sit_tutorial_seen := false
var sit_help_button: Button
var marker_button: Button
var marker_gentle: CheckButton
var guided_button: Button
var today_home: HBoxContainer
var album_actions: HBoxContainer
var keyboard_height_override := -1.0
var visitor_album_status: Label
var journal_list: VBoxContainer
var selected_trick: String = "come"
var selected_tab: String = "care"
var journal_count: int = -1
var profile_dialog: AcceptDialog
var name_edit: LineEdit
var profile_traits: Label
var profile_bars: VBoxContainer
var profile_badges: HFlowContainer
var modal_shade: ColorRect
var settings_dialog: PanelContainer
var settings_close: Button
var settings_close_top: Button
var settings_scroll: ScrollContainer
var profile_life: Label
var profile_social: Label
var reunion_dialog: AcceptDialog
var reunion_text: Label
var text_dialog: AcceptDialog
var command_edit: LineEdit
var save_path_override: String = ""
var journal_signature: String = ""
var header: PanelContainer
var sheet: PanelContainer
var navigation: PanelContainer
var bubble: PanelContainer
var training_actions: HBoxContainer
var rewards_row: HBoxContainer
var album_count: Label
var bold_font: FontVariation
var layout_wide: bool = false
var bond_bar: ProgressBar
var care_status: Label
var guidance_toggle: CheckButton
var training_steps: Array[IconActionButton] = []
var bubble_icon: TextureRect
var gain_label: Label
var bubble_left := 0.0
var gain_left := 0.0
var training_feedback := ""
var training_feedback_left := 0.0
var safe_rect := Rect2()
# Physical window coordinates; used by device-layout regression tests.
var safe_area_override := Rect2()
var ui_settings_path := ""
var companion_voice := CompanionVoice.new()
var companion_card: PanelContainer
var companion_title: Label
var companion_label: Label
var companion_action: Button
var companion_later: Button
var companion_tail: Polygon2D
var companion_data: Dictionary = {}
var play_menu: AcceptDialog
var play_dialog: AcceptDialog
var play_view: TouchPlayView
var play_hint: Label
var play_cue: Button
var play_again: Button
var app_foreground := true
const ACTION_NEEDS := {"feed": "fullness", "rest": "energy", "clean": "hygiene", "play": "play", "pet": "contact"}
const ACTION_LABELS := {"feed": "Nakarm", "rest": "Drzemka", "clean": "Wyczesz", "play": "Pobaw się", "pet": "Przytul"}
const LOW_LABELS := {"feed": "Głód", "rest": "Senność", "clean": "Czesanie", "play": "Nuda", "pet": "Bliskość"}

func _ready() -> void:
	get_tree().auto_accept_quit = false
	process_priority = 10 # Follow the room's updated camera in the same frame.
	_build_theme()
	_build_ui()
	add_child(yard_transition)
	yard_transition.setup(self)
	resized.connect(_fit_room)
	sheet.minimum_size_changed.connect(func(): _fit_room.call_deferred())
	_fit_room()
	add_child(session)
	session.changed.connect(_refresh)
	session.visitor_appeared.connect(func(): room.look_at_world(Vector2(940, 300)))
	session.feedback.connect(_show_feedback)
	session.care_completed.connect(_show_gain)
	session.clip_requested.connect(room.play_clip)
	session.destination_requested.connect(room.move_to)
	session.course_jump_requested.connect(room.start_course_jump)
	session.performance_requested.connect(room.play_performance)
	session.approach_requested.connect(room.approach_station)
	session.place_requested.connect(room.place_at_station)
	session.activity_cancelled.connect(room.cancel_activity)
	session.attention_requested.connect(room.focus_pet)
	room.station_reached.connect(session.arrive_at)
	room.destination_reached.connect(session.destination_reached)
	room.performance_finished.connect(session.performance_finished)
	room.animator.sitting_contact.connect(session.training.sitting_contact)
	session.save_status.connect(func(_ok: bool): _refresh())
	room.floor_tapped.connect(func(_point: Vector2): yard_menu.close())
	room.floor_tapped.connect(session.move_to)
	room.room_viewed.connect(func(_point: Vector2): yard_menu.close())
	room.room_viewed.connect(session.follow_room)
	room.return_button.pressed.connect(session.player_activity)
	room.care_requested.connect(_on_room_care_requested)
	room.ball_thrown.connect(func(target: Vector2): session.throw_ball(target, room.ball_world))
	session.ball_throw_requested.connect(room.throw_ball)
	session.ball_caught.connect(room.animate_ball_catch)
	session.home_drink_started.connect(func(): room.animator.facing_left = true)
	session.hide_revealed.connect(room.reveal_hide)
	session.initiative_requested.connect(room.present_invitation)
	session.ball_aim_requested.connect(_aim_ball)
	session.touch_game_opened.connect(_show_touch_game)
	session.touch_game_closed.connect(func(): play_dialog.hide())
	session.cuddle_opened.connect(_show_cuddle)
	session.cuddle_closed.connect(func(): cuddle_dialog.hide())
	var path := "user://pet.json"
	if OS.get_cmdline_user_args().has("--qa"): path = "user://qa-ui/pet.json"
	if not save_path_override.is_empty(): path = save_path_override
	ui_settings_path = path.get_base_dir().path_join("ui.cfg")
	_load_ui_preferences()
	room.first_pan.connect(_remember_pan)
	room.yard_place_used.connect(_remember_yard_place)
	add_child(music)
	music.start(path.get_base_dir().path_join("audio.cfg"))
	music_toggle.set_pressed_no_signal(music.enabled)
	add_child(effects)
	effects.start(path.get_base_dir().path_join("audio.cfg"))
	effects_toggle.set_pressed_no_signal(effects.enabled)
	haptics.start(ui_settings_path)
	haptics_toggle.set_pressed_no_signal(haptics.enabled)
	haptics_toggle.disabled = not haptics.supported
	session.sound_requested.connect(haptics.play_event)
	session.sound_requested.connect(effects.play_effect)
	session.away_report_ready.connect(_show_reunion)
	room.sound_requested.connect(effects.play_effect)
	session.start(path)
	reminders.start(path)
	reminders_toggle.set_pressed_no_signal(reminders.enabled)
	reminders_toggle.disabled = not reminders.supported
	reminders_status.text = reminders.status_text()
	_refresh()
	_show_feedback(session.last_message)
	if save_path_override.is_empty() or enable_test_onboarding: _first_meeting_if_needed()

func _first_meeting_if_needed() -> void:
	if not session.writable: return
	var config := ConfigFile.new()
	config.load(ui_settings_path)
	if session.newly_created:
		config.set_value("tutorial", "naming_pending", true)
		config.save(ui_settings_path)
	if not config.get_value("tutorial", "naming_pending", false): return
	first_meeting = AcceptDialog.new()
	first_meeting.title = "Pierwsze spotkanie"
	first_meeting.exclusive = true
	first_meeting.dialog_hide_on_ok = false
	first_meeting.get_ok_button().text = "Poznajmy się"
	# Naming is the one required step: Escape or the title-bar close cannot skip it.
	first_meeting.dialog_close_on_escape = false
	first_meeting.canceled.connect(func():
		if naming_pending: _reopen_first_meeting.call_deferred())
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	box.custom_minimum_size.x = 240
	box.size.x = 260
	var greeting := _label("Mały przyjaciel czeka na Ciebie. Jak ma na imię?", 18)
	greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	greeting.custom_minimum_size.x = 240
	box.add_child(greeting)
	first_name = LineEdit.new()
	first_name.placeholder_text = "Imię pieska"
	first_name.max_length = 24
	first_name.custom_minimum_size = Vector2(240, 48)
	box.add_child(first_name)
	first_error = _label("Możesz później zmienić imię w karcie pieska.", 13, MUTED)
	first_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	first_error.custom_minimum_size.x = 240
	box.add_child(first_error)
	first_meeting.add_child(box)
	add_child(first_meeting)
	first_meeting.confirmed.connect(_finish_first_meeting)
	first_name.text_submitted.connect(func(_text): _finish_first_meeting())
	first_meeting.visibility_changed.connect(_update_attention)
	naming_pending = true
	name_label.text = "Piesek"
	_position_dialog(first_meeting, Vector2i(340, 290))
	first_meeting.popup()
	bubble_left = 0
	_update_attention()

func _reopen_first_meeting() -> void:
	if not naming_pending or not is_instance_valid(first_meeting) or first_meeting.visible: return
	first_meeting.popup()
	_position_dialog(first_meeting, Vector2i(340, 290))
	first_name.grab_focus()

func _finish_first_meeting() -> void:
	var value := first_name.text.strip_edges()
	if value.is_empty():
		first_error.text = "Wpisz imię, żebyśmy mogli się poznać."
		return
	var previous := session.pet.pet_name
	if not session.rename_pet(value) or not session.save_ok:
		session.pet.pet_name = previous
		first_error.text = "Nie udało się zapisać imienia. Spróbuj ponownie."
		return
	var config := ConfigFile.new()
	config.load(ui_settings_path)
	config.set_value("tutorial", "naming_pending", false)
	if config.save(ui_settings_path) != OK:
		first_error.text = "Nie udało się zakończyć spotkania. Spróbuj ponownie."
		return
	naming_pending = false
	first_meeting.hide()
	session.say("Dobrze, że jesteś. Dotknij pieska, żeby się przywitać.")
	_refresh()

func _sync_yard_actions() -> void:
	var camera_parent: Node = room if session.in_yard else yard_toolbar
	if room.overview_button.get_parent() != camera_parent:
		room.overview_button.reparent(camera_parent)
	var container: Node = panels.care
	if yard_toolbar.get_parent() != container:
		yard_toolbar.reparent(container)
		visitor_toolbar.reparent(container)
		container.move_child(yard_toolbar, 1)
		container.move_child(visitor_toolbar, 2)
		_fit_room()
	var occupied := session.in_yard and (session.busy() or not session.invitation.is_empty() or session.visitors.active() or YardRoutines.has_mess(session))
	care_actions.visible = not occupied and not yard_menu.visible
	care_status.visible = not yard_menu.visible
	var layout_key := "%s|%s|%s" % [care_actions.visible, session.in_yard and session.visitors.active(), yard_menu.visible]
	if layout_key != _yard_layout_key:
		_yard_layout_key = layout_key
		_fit_room()
	for key in care_buttons:
		care_buttons[key].visible = not session.in_yard or key in ["pet", "play", "rest"]

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
		app_theme.set_color("font_focus_color", type, INK)
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
	header = PanelContainer.new()
	header.add_theme_stylebox_override("panel", _style(Color("fff9edf2"), 22, 12))
	add_child(header)
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	header.add_child(header_row)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 2)
	header_row.add_child(identity)
	name_label = _button("Biszkopt", _show_profile)
	name_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.add_theme_font_size_override("font_size", 27)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.tooltip_text = "Otwórz kartę pieska"
	for state in ["normal", "hover"]: name_label.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	identity.add_child(name_label)
	bond_label = _label("Poznajecie się · 0%", 12, MUTED)
	identity.add_child(bond_label)
	bond_bar = _bar(Color("779565"), 6)
	identity.add_child(bond_bar)
	bond_detail = _label("", 10, MUTED)
	bond_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	identity.add_child(bond_detail)
	wellbeing_button = WellbeingButton.new()
	wellbeing_button.text = "Radosna"
	wellbeing_button.pressed.connect(_show_wellbeing)
	var header_actions := VBoxContainer.new()
	header_actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_actions.add_theme_constant_override("separation", 0)
	header_row.add_child(header_actions)
	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 8)
	header_actions.add_child(action_row)
	var settings := _icon_button("settings", "Ustawienia", _show_settings)
	settings.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	today_button = _button("Dziś", func(): AdventurePanel.show_plan(self))
	today_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	today_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	today_button.custom_minimum_size.x = 54
	action_row.add_child(today_button)
	today_home = action_row
	action_row.add_child(settings)
	header_actions.add_child(wellbeing_button)
	bubble = PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _style(Color("fff9edf2"), 18, 10))
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bubble)
	var bubble_row := HBoxContainer.new()
	bubble_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_row.add_theme_constant_override("separation", 8)
	bubble.add_child(bubble_row)
	bubble_icon = TextureRect.new()
	bubble_icon.texture = GameIcons.texture("heart")
	bubble_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bubble_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	bubble_icon.custom_minimum_size = Vector2(24, 24)
	bubble_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble_row.add_child(bubble_icon)
	message_label = _label("", 14)
	message_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble_row.add_child(message_label)
	bubble.hide()
	gain_label = _label("", 21, GREEN, true)
	gain_label.add_theme_stylebox_override("normal", _style(CREAM, 14, 8))
	gain_label.hide()
	add_child(gain_label)
	sheet = PanelContainer.new()
	var sheet_style := _style(Color("fff9edf5"), 24, 12)
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
	_build_companion_card()
	_build_dialogs()

func _build_companion_card() -> void:
	companion_card = PanelContainer.new()
	companion_card.add_theme_stylebox_override("panel", _style(CREAM, 18, 12))
	add_child(companion_card)
	companion_tail = Polygon2D.new()
	companion_tail.color = CREAM
	companion_tail.polygon = PackedVector2Array([Vector2(0, -1), Vector2(18, -1), Vector2(6, 9)])
	companion_card.add_child(companion_tail)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	companion_card.add_child(row)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	words.add_theme_constant_override("separation", 3)
	row.add_child(words)
	companion_title = _label("", 11, MUTED, true)
	companion_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	words.add_child(companion_title)
	companion_label = _label("", 14, INK, true)
	companion_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	words.add_child(companion_label)
	var actions := VBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("separation", 2)
	row.add_child(actions)
	companion_action = _button("", _companion_act, true)
	companion_action.add_theme_font_size_override("font_size", 13)
	actions.add_child(companion_action)
	companion_later = _button("Później", session.decline_invitation)
	companion_later.add_theme_font_size_override("font_size", 12)
	actions.add_child(companion_later)
	companion_card.hide()

func _refresh_companion(delta: float = 0.0) -> void:
	if companion_card == null or session.pet == null: return
	companion_card.visible = not session.home_drink.active() and not session.yard_rest.active() and not session.course.active() and not str(session.invitation.get("kind", "")).begins_with("yard_") and not session.portal_active and not session.visitors.active() and not session.water.active() and session.attention_available and not session.suspended and not session.hide_game.active() and not room.overview
	var data := companion_voice.describe(session, delta if companion_card.visible and companion_card.modulate.a > 0 else 0.0)
	if data != companion_data:
		companion_data = data
		companion_label.text = data.text
		companion_action.text = data.label
		companion_action.visible = not str(data.action).is_empty()
		companion_action.disabled = not data.enabled
		companion_action.accessibility_name = "%s. %s" % [data.text, data.label]
		companion_later.visible = data.kind == "invitation"
	# Renaming the dog also updates the bubble without restarting its quiet timer.
	companion_title.text = "%s · %s" % [session.pet.pet_name, {"need": "potrzebuje", "invitation": "ma ochotę", "thought": "myśli", "memory": "wspomina", "activity": "teraz", "wake": "po pobudce"}[data.kind]]
	_position_companion()
	session.invitation_presented = session.attention_available and (str(session.invitation.get("kind", "")).begins_with("yard_") or (companion_card.visible and companion_card.modulate.a > 0 and data.get("kind") == "invitation"))

func _companion_act() -> void:
	if not companion_card.visible or companion_data.is_empty(): return
	# Recheck the current state: the need or invitation may have changed since touch-down.
	var current := companion_voice.describe(session)
	if current.action != companion_data.action or not current.enabled:
		_refresh_companion()
		return
	var action: String = current.action
	if action.begins_with("invite:"): session.accept_invitation()
	elif action == "album": _select_tab("journal")
	elif action == "yard": _toggle_yard()
	elif action == "outing": YardRoutines.start_outing(session)
	elif action == "play": _show_play_menu()
	elif action == "cuddle": session.start_cuddle()
	elif not action.is_empty(): session.act(action)
	_update_attention()
	_refresh_companion()

func _build_care() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	var outdoors := HBoxContainer.new()
	yard_toolbar = outdoors
	add_child(outdoors)
	potty_action = _button("Na potrzebę", func():
		if YardRoutines.has_mess(session): YardRoutines.clean_up(session)
		else: YardRoutines.start_outing(session))
	outdoors.add_child(potty_action)
	potty_action.hide()
	yard_button = _button("Podwórko", _toggle_yard)
	outdoors.add_child(yard_button)
	sniff_button = _button("Chowany", _show_yard_games)
	outdoors.add_child(sniff_button)
	yard_bath_button = _button("Kąpiel", _show_bath)
	outdoors.add_child(yard_bath_button)
	yard_command_button = _button("Komenda", func(): OutdoorPanels.command(self))
	outdoors.add_child(yard_command_button)
	yard_command_button.hide()
	water_splash_button = _button("Plusk!", func(): session.water.splash(session))
	water_shake_button = _button("Otrzep się", func(): session.water.shake(session))
	outdoors.add_child(water_splash_button)
	outdoors.add_child(water_shake_button)
	yard_invite_accept = _button("Zabawmy się", session.accept_invitation)
	yard_invite_later = _button("Później", session.decline_invitation)
	outdoors.add_child(yard_invite_accept)
	outdoors.add_child(yard_invite_later)
	yard_invite_accept.hide()
	yard_invite_later.hide()
	course_action = _button("Skacz", _course_action)
	course_stop = _button("Przerwij", func(): session.course.finish(session, "Tor poczeka. Chwila odpoczynku."))
	outdoors.add_child(course_action)
	outdoors.add_child(course_stop)
	yard_rest_stop = _button("Przerwij", func(): session.yard_rest.finish(session))
	outdoors.add_child(yard_rest_stop)
	yard_rest_stop.hide()
	course_action.hide()
	course_stop.hide()
	water_splash_button.hide()
	water_shake_button.hide()
	visitor_toolbar = HBoxContainer.new()
	add_child(visitor_toolbar)
	visitor_soothe_button = _button("Spokojnie", func(): session.visitors.respond(session, "soothe"))
	visitor_recall_button = _button("Przyjdź", func(): session.visitors.respond(session, "recall"))
	visitor_interact_button = _button("Gość", _show_visitor_interactions)
	visitor_toolbar.add_child(visitor_interact_button)
	visitor_toolbar.add_child(visitor_soothe_button)
	visitor_toolbar.add_child(visitor_recall_button)
	visitor_soothe_button.hide()
	visitor_recall_button.hide()
	care_status = _label("Małe rytuały, wspólny dzień", 12, MUTED)
	care_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	care_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	care_status.max_lines_visible = 2
	care_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(care_status)
	var actions := HBoxContainer.new()
	care_actions = actions
	actions.add_theme_constant_override("separation", 2)
	box.add_child(actions)
	var colors := {"feed": Color("f6ddb0"), "pet": Color("f3d7c8"), "play": Color("e2e9bd"), "clean": Color("d5e6dc"), "rest": Color("e0def0")}
	for key in ACTION_NEEDS:
		var need: String = ACTION_NEEDS[key]
		var button := _action(NEED_ICONS[need], ACTION_LABELS[key], colors[key], _care_action.bind(key))
		button.need_value = 100
		actions.add_child(button)
		care_buttons[key] = button
		needs_ui[need] = button
	yard_menu.setup(self)
	box.add_child(yard_menu)
	return box

func _build_training() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 4)
	box.add_child(choices)
	choices.add_child(_button("Lista sztuczek", _show_tricks))
	sit_help_button = _button("Jak ćwiczyć?", _show_sit_tutorial)
	sit_help_button.add_theme_font_size_override("font_size", 12)
	choices.add_child(sit_help_button)
	choices.add_child(_icon_button("keyboard", "Wpisz komendę", _show_command))
	var progress_row := HBoxContainer.new()
	box.add_child(progress_row)
	mastery_label = _label("", 12, MUTED)
	mastery_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_row.add_child(mastery_label)
	training_footer = _label("", 12, MUTED)
	progress_row.add_child(training_footer)
	mastery_bar = _bar(Color("91a871"), 5)
	box.add_child(mastery_bar)
	practice_label = _label("", 12, MUTED)
	box.add_child(practice_label)
	var steps := HBoxContainer.new()
	box.add_child(steps)
	for entry in [["gesture", "1. Gest"], ["clock", "2. Czekaj"], ["heart", "3. Nagroda"]]:
		var step := _action(entry[0], entry[1], Color.TRANSPARENT, func(): pass)
		step.navigation = true
		step.compact = true
		step.mouse_filter = Control.MOUSE_FILTER_IGNORE
		step.focus_mode = Control.FOCUS_NONE
		steps.add_child(step)
		training_steps.append(step)
	training_hint = _label("", 13)
	training_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	training_hint.custom_minimum_size.y = 32
	training_hint.max_lines_visible = 2
	training_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	box.add_child(training_hint)
	training_actions = HBoxContainer.new()
	training_actions.custom_minimum_size.y = 88
	training_actions.add_theme_constant_override("separation", 6)
	box.add_child(training_actions)
	guidance_toggle = CheckButton.new()
	guidance_toggle.text = "Z podpowiedzią"
	guidance_toggle.button_pressed = true
	guidance_toggle.add_theme_font_size_override("font_size", 13)
	guidance_toggle.custom_minimum_size.y = 44
	guidance_toggle.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	guidance_toggle.toggled.connect(func(value: bool):
		guidance_toggle.text = "Z podpowiedzią" if value else "Bez podpowiedzi"
		training_feedback_left = 0
		_refresh())
	var guidance_options := VBoxContainer.new()
	training_actions.add_child(guidance_options)
	guidance_options.add_child(guidance_toggle)
	marker_gentle = CheckButton.new()
	marker_gentle.text = "Łagodny czas"
	marker_gentle.add_theme_font_size_override("font_size", 12)
	marker_gentle.custom_minimum_size.y = 40
	guidance_options.add_child(marker_gentle)
	guided_button = _button("Pokaż gest", func(): _train(guidance_toggle.button_pressed), true)
	guided_button.add_theme_font_size_override("font_size", 13)
	guided_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	training_actions.add_child(guided_button)
	marker_button = _button("Klik! — oznacz siad", func(): pass, true)
	marker_button.custom_minimum_size.y = 88
	marker_button.button_down.connect(func(): session.mark_sit())
	box.add_child(marker_button)
	rewards_row = HBoxContainer.new()
	rewards_row.add_theme_constant_override("separation", 8)
	box.add_child(rewards_row)
	for key in TrainingSystem.REWARDS:
		var button := _action({"treat": "treat", "praise": "heart", "play": "ball"}[key], REWARD_LABELS[key], Color("ecebd7"), _reward.bind(key))
		rewards_row.add_child(button)
		reward_buttons[key] = button
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
	album_actions = HBoxContainer.new()
	box.add_child(album_actions)
	album_actions.add_child(_button("Zrób zdjęcie", func():
		_select_tab("care")
		_take_photo()))
	album_actions.add_child(_button("Dekoracje", _show_decor))
	box.add_child(_button("Kolekcja wykopanych skarbów", func(): ProgressionPanels.collection(self)))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	photos_list = VBoxContainer.new()
	photos_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(photos_list)
	var visitors_art := TextureRect.new()
	visitors_art.texture = load("res://assets/art/visitors/fence-friends-v1.png")
	visitors_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	visitors_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	visitors_art.custom_minimum_size = Vector2(0, 160)
	content.add_child(visitors_art)
	content.add_child(_label("Znajomi przy płocie", 18, INK, true))
	visitor_album_status = _label("", 13, MUTED)
	visitor_album_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(visitor_album_status)
	journal_list = VBoxContainer.new()
	journal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_list.add_theme_constant_override("separation", 10)
	content.add_child(journal_list)
	return box

func _build_dialogs() -> void:
	var shade := ColorRect.new()
	modal_shade = shade
	shade.color = Color(0.15, 0.20, 0.16, 0.22)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.z_index = 100
	shade.hide()
	add_child(shade)
	profile_dialog = AcceptDialog.new()
	profile_dialog.title = "Twój mały przyjaciel"
	profile_dialog.ok_button_text = "Zapisz"
	profile_dialog.min_size = Vector2i(280, 340)
	profile_dialog.ok_button_text = "Zapisz imię"
	add_child(profile_dialog)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	profile_dialog.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 12)
	scroll.add_child(box)
	box.add_child(_label("Imię pieska", 16, INK, true))
	name_edit = LineEdit.new()
	name_edit.max_length = 24
	name_edit.custom_minimum_size.y = 44
	box.add_child(name_edit)
	box.add_child(_button("Poziomy więzi", func():
		profile_dialog.hide()
		ProgressionPanels.bond(self)))
	profile_bars = VBoxContainer.new()
	profile_bars.add_theme_constant_override("separation", 9)
	box.add_child(profile_bars)
	profile_traits = _label("", 13, MUTED)
	profile_traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(profile_traits)
	box.add_child(_label("Nasze nawyki", 16, INK, true))
	profile_badges = HFlowContainer.new()
	profile_badges.add_theme_constant_override("h_separation", 6)
	profile_badges.add_theme_constant_override("v_separation", 6)
	box.add_child(profile_badges)
	profile_life = _label("", 13, MUTED)
	profile_life.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(profile_life)
	profile_social = _label("", 13, MUTED)
	profile_social.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(profile_social)
	profile_dialog.confirmed.connect(func(): session.rename_pet(name_edit.text))
	# Use the same canvas and safe-area coordinates as the room. A separate
	# Window adds another coordinate space on scaled mobile displays.
	settings_dialog = PanelContainer.new()
	settings_dialog.add_theme_stylebox_override("panel", _style(CREAM, 18, 18))
	settings_dialog.z_index = 101
	settings_dialog.hide()
	add_child(settings_dialog)
	var settings_layout := VBoxContainer.new()
	settings_layout.add_theme_constant_override("separation", 12)
	settings_dialog.add_child(settings_layout)
	var settings_header := HBoxContainer.new()
	settings_header.add_theme_constant_override("separation", 8)
	settings_layout.add_child(settings_header)
	var settings_title := _label("Ustawienia", 20, INK, true)
	settings_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_header.add_child(settings_title)
	settings_close_top = _button("Zamknij", _hide_settings)
	settings_close_top.custom_minimum_size.y = 44
	settings_header.add_child(settings_close_top)
	settings_scroll = ScrollContainer.new()
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_layout.add_child(settings_scroll)
	var settings_box := VBoxContainer.new()
	settings_box.add_theme_constant_override("separation", 12)
	settings_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	settings_scroll.add_child(settings_box)
	settings_box.add_child(_button("Dekoracje pokoju", func():
		_hide_settings()
		_show_decor()))
	music_toggle = CheckButton.new()
	music_toggle.text = "Muzyka w tle"
	music_toggle.custom_minimum_size.y = 44
	music_toggle.toggled.connect(music.set_enabled)
	settings_box.add_child(music_toggle)
	effects_toggle = CheckButton.new()
	effects_toggle.text = "Efekty dźwiękowe"
	effects_toggle.custom_minimum_size.y = 44
	effects_toggle.toggled.connect(effects.set_enabled)
	settings_box.add_child(effects_toggle)
	haptics_toggle = CheckButton.new()
	haptics_toggle.text = "Wibracje"
	haptics_toggle.custom_minimum_size.y = 44
	haptics_toggle.toggled.connect(func(value: bool):
		haptics.set_enabled(value)
		haptics_toggle.set_pressed_no_signal(haptics.enabled))
	settings_box.add_child(haptics_toggle)
	reminders_toggle = CheckButton.new()
	reminders_toggle.text = "Przypomnienia od pieska"
	reminders_toggle.custom_minimum_size.y = 44
	reminders_toggle.toggled.connect(func(value: bool):
		reminders.set_enabled(value)
		reminders_toggle.set_pressed_no_signal(reminders.enabled)
		reminders_status.text = reminders.status_text())
	settings_box.add_child(reminders_toggle)
	reminders_status = _label("", 12, MUTED)
	reminders_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settings_box.add_child(reminders_status)
	settings_box.add_child(_label("Zmiany zapisują się od razu.", 12, MUTED))
	settings_close = _button("Wróć do pokoju", _hide_settings)
	settings_close.custom_minimum_size.y = 48
	settings_layout.add_child(settings_close)
	reunion_dialog = AcceptDialog.new()
	reunion_dialog.title = "Znów razem"
	reunion_dialog.ok_button_text = "Miło wrócić"
	reunion_dialog.min_size = Vector2i(280, 220)
	add_child(reunion_dialog)
	var reunion_scroll := ScrollContainer.new()
	reunion_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	reunion_dialog.add_child(reunion_scroll)
	var reunion_box := VBoxContainer.new()
	reunion_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reunion_scroll.add_child(reunion_box)
	reunion_text = _label("", 15)
	reunion_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reunion_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	reunion_box.add_child(reunion_text)
	text_dialog = AcceptDialog.new()
	text_dialog.title = "Napisz komendę"
	text_dialog.ok_button_text = "Poproś"
	text_dialog.min_size = Vector2i(280, 150)
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
	_build_play_dialogs()
	_build_cuddle_dialog()
	var update_shade := func():
		shade.visible = _dialog_open()
		_update_attention()
	settings_dialog.visibility_changed.connect(update_shade)
	profile_dialog.visibility_changed.connect(update_shade)
	text_dialog.visibility_changed.connect(update_shade)
	reunion_dialog.visibility_changed.connect(update_shade)
	play_menu.visibility_changed.connect(update_shade)
	play_dialog.visibility_changed.connect(update_shade)
	cuddle_dialog.visibility_changed.connect(update_shade)
	wellbeing_dialog.visibility_changed.connect(update_shade)

func _build_play_dialogs() -> void:
	play_menu = AcceptDialog.new()
	play_menu.title = "Pobawmy się"
	play_menu.ok_button_text = "Zamknij"
	play_menu.min_size = Vector2i(280, 300)
	add_child(play_menu)
	var choices := VBoxContainer.new()
	choices.add_theme_constant_override("separation", 12)
	var choices_scroll := ScrollContainer.new()
	choices_scroll.custom_minimum_size.y = 220
	choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_menu.add_child(choices_scroll)
	choices_scroll.add_child(choices)
	choices.add_child(_label("Na co macie ochotę?", 18, INK, true))
	for entry in [["ball", "Piłka · przeciągnij i rzuć"], ["tug", "Lina · ciągnij i odpuszczaj"], ["cups", "Kubki · schowaj smakołyk"], ["tag", "Berek · na podwórku"], ["cups2", "Kubki · śledź smakołyk"], ["frisbee", "Frisbee · na podwórku"]]:
		choices.add_child(_button(entry[1], _choose_play.bind(entry[0])))
	play_dialog = AcceptDialog.new()
	play_dialog.title = "Wspólna zabawa"
	play_dialog.ok_button_text = "Zakończ"
	for state in ["normal", "hover", "pressed", "disabled"]:
		play_dialog.get_ok_button().add_theme_stylebox_override(state, _style(Color("efeeda"), 12, 14))
	play_dialog.min_size = Vector2i(280, 350)
	add_child(play_dialog)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	play_dialog.add_child(content)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	play_hint = _label("", 15, INK, true)
	play_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(play_hint)
	play_view = TouchPlayView.new()
	play_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	play_view.model = session.play
	box.add_child(play_view)
	play_view.pressed_at.connect(session.play_press)
	play_view.moved_to.connect(session.play_move)
	play_view.released_at.connect(session.play_release)
	play_cue = _button("Szukaj!", session.play_cue)
	content.add_child(play_cue)
	play_again = _button("Jeszcze raz", func(): session.start_touch_game(session.play.kind))
	content.add_child(play_again)
	box.add_child(_label("Możesz zakończyć w dowolnej chwili.", 12, MUTED))
	play_dialog.visibility_changed.connect(func():
		if not play_dialog.visible: session.cancel_touch_game())

func _dialog_open() -> bool:
	if is_instance_valid(settings_dialog) and settings_dialog.visible: return true
	for dialog in get_children():
		if dialog is Window and dialog.visible: return true
	return false

func _update_attention() -> void:
	if is_instance_valid(modal_shade): modal_shade.visible = _dialog_open()
	session.set_training_view(selected_tab == "training")
	session.emotional_foreground = app_foreground
	session.attention_available = app_foreground and selected_tab == "care" and not _dialog_open() and not room.overview and not yard_menu.visible
	if room.ambient_life.is_node_ready() and session.pet != null:
		room.ambient_life.sync(room, session, app_foreground and selected_tab == "care" and room.visible and not _dialog_open())
	if companion_card != null and not session.attention_available:
		companion_card.hide()
		session.invitation_presented = false

func _show_play_menu() -> void:
	var reason := session.play_readiness()
	if not reason.is_empty():
		session.say(reason)
		return
	play_menu.popup()
	_position_dialog(play_menu, Vector2i(336, 310))

func _choose_play(kind: String) -> void:
	play_menu.hide()
	if kind == "ball": _aim_ball()
	else: session.start_touch_game(kind)

func _aim_ball() -> void:
	_select_tab("care")
	room.focus_left = 0
	room.look_at_world(room.ball_world)
	session.say("Przeciągnij piłkę w lewo lub w prawo i puść. Linia pokaże rzut.")

func _show_touch_game(kind: String) -> void:
	play_menu.hide()
	play_dialog.title = SkillPlaySystem.label(kind)
	play_hint.text = session.play.hint()
	play_dialog.popup()
	play_dialog.get_ok_button().custom_minimum_size.y = 48
	_position_dialog(play_dialog, Vector2i(350, 500))

func _select_tab(key: String) -> void:
	yard_menu.close()
	if key != "care" and session.in_yard:
		if not session.change_yard(false): return
		if room.in_yard: room.set_yard(false)
	if key != selected_tab:
		effects.play_effect("ui")
		bubble_left = 0
		training_feedback_left = 0
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
	safe_rect = _safe_content_rect()
	layout_wide = safe_rect.size.x >= 760 and safe_rect.size.x > safe_rect.size.y * 1.2
	var rail := clampf(safe_rect.size.x * 0.36, 350, 420) if layout_wide else safe_rect.size.x
	var panel_width := minf(rail - 24, 540)
	var panel_x := safe_rect.end.x - rail + (rail - panel_width) / 2
	var nav_y := safe_rect.end.y - 68
	var warning_space := 46.0 if footer_label.visible else 0.0
	# Outdoors the panel holds instructions and context actions; it shrinks when
	# an activity hides the care buttons instead of leaving an empty card.
	var yard_height := 192.0 if care_actions.visible or yard_menu.visible else (160.0 if session.visitors.active() else 112.0)
	var panel_height := (yard_height if session.in_yard else 192.0) if selected_tab == "care" else 274.0
	var panel_top := nav_y - panel_height - 8 - warning_space
	if selected_tab == "journal":
		panel_x = safe_rect.position.x + 12
		panel_width = safe_rect.size.x - 24
		panel_top = safe_rect.position.y + 8
		panel_height = nav_y - panel_top - 8 - warning_space
	yard_toolbar.visible = selected_tab == "care"
	visitor_toolbar.visible = selected_tab == "care" and session.visitors.active()
	room.yard_controls_bottom = header.get_rect().end.y + 64
	_place(sheet, Rect2(panel_x, panel_top, panel_width, panel_height))
	_place(navigation, Rect2(safe_rect.end.x - rail + (rail - minf(rail - 24, 540)) / 2, nav_y, minf(rail - 24, 540), 60))
	var scene_width := safe_rect.end.x - rail if layout_wide else size.x
	_place(room, Rect2(0, 0, scene_width, size.y))
	var header_x := safe_rect.position.x + 12
	var header_width := minf(minf(scene_width, safe_rect.end.x) - header_x - 12, 420)
	var training_open := selected_tab == "training"
	var header_style := header.get_theme_stylebox("panel") as StyleBoxFlat
	header_style.content_margin_top = 12 if training_open else 4
	header_style.content_margin_bottom = 12 if training_open else 4
	bond_label.visible = not training_open
	bond_bar.visible = not training_open
	bond_detail.visible = not training_open
	wellbeing_button.visible = not training_open
	name_label.add_theme_font_size_override("font_size", 22 if training_open else 27)
	_place(header, Rect2(header_x, safe_rect.position.y + 8, header_width, 68 if training_open else 100))
	header.visible = selected_tab != "journal"
	room.visible = selected_tab != "journal"
	room.hud_bottom = header.get_rect().end.y + 10
	room.content_bottom = safe_rect.end.y - 16 if layout_wide else panel_top
	room.overlay_left = header_x
	room.overlay_right = minf(scene_width - 12, safe_rect.end.x - 12)
	_place(footer_label, Rect2(panel_x + 8, nav_y - 44, panel_width - 16, 42))
	room.update_placement()
	_position_feedback()
	_position_companion()
	for dialog in [profile_dialog, text_dialog, reunion_dialog, play_menu, play_dialog, cuddle_dialog, wellbeing_dialog]:
		if dialog != null and dialog.visible: _position_dialog(dialog, dialog.size)
	if first_meeting != null and first_meeting.visible: _position_dialog(first_meeting, Vector2i(340, 290))
	if settings_dialog != null and settings_dialog.visible: _fit_settings()
	if is_instance_valid(visitor_dialog) and visitor_dialog.visible: _position_dialog(visitor_dialog, Vector2i(320, 330))

func _safe_content_rect() -> Rect2:
	var full := Rect2(Vector2.ZERO, size)
	var physical := safe_area_override
	if not physical.has_area():
		if not OS.has_feature("mobile"): return full
		physical = Rect2(DisplayServer.get_display_safe_area())
		physical.position -= Vector2(DisplayServer.window_get_position() - DisplayServer.screen_get_position())
	if not physical.has_area(): return full
	var inverse := (get_viewport().get_final_transform() * get_global_transform_with_canvas()).affine_inverse()
	var local := Rect2(inverse * physical.position, inverse.basis_xform(physical.size))
	return full.intersection(local) if full.intersects(local) else full

func _prepare_card_dialog(dialog: AcceptDialog) -> void:
	if dialog.has_meta("card_title"): return
	dialog.borderless = true
	dialog.transparent_bg = true
	dialog.transparent = true
	var children := dialog.get_children()
	var wrapper := VBoxContainer.new()
	wrapper.custom_minimum_size.x = 240
	wrapper.add_theme_constant_override("separation", 12)
	var title := _label(dialog.title, 20, INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 240
	wrapper.add_child(title)
	dialog.set_meta("card_title", title)
	for child in children:
		if child is Control:
			child.reparent(wrapper)
			if child is ScrollContainer:
				child.custom_minimum_size.y = 0
				child.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.add_child(wrapper)
	dialog.get_ok_button().custom_minimum_size.y = 48

func _position_dialog(dialog: AcceptDialog, wanted: Vector2i) -> void:
	if dialog == first_meeting or dialog == play_menu or dialog.title == "Sztuczki pieska":
		_prepare_card_dialog(dialog)
	var area := safe_rect
	if dialog == first_meeting:
		var keyboard := 0.0
		if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
			keyboard = float(DisplayServer.virtual_keyboard_get_height()) / get_viewport().get_final_transform().get_scale().y
		if keyboard_height_override >= 0: keyboard = keyboard_height_override
		if keyboard > 0: area.size.y = maxf(280, minf(area.end.y, size.y - keyboard) - area.position.y)
	var available := Vector2i(area.size - Vector2(24, 32))
	dialog.size = wanted.min(available)
	dialog.position = Vector2i(area.position + (area.size - Vector2(dialog.size)) / 2)

func _show_tricks(daily: bool = false) -> void:
	if daily:
		AdventurePanel.show_plan(self)
		return
	if session.training.phase != "idle": return
	var dialog := AcceptDialog.new()
	dialog.title = "Sztuczki pieska"
	var list := VBoxContainer.new()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 320)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	var keys := PetState.TRICK_KEYS.duplicate()
	var explanation := _label("Wybierz sztuczkę, na którą macie ochotę. Opanowanie zostaje na zawsze; gest pomoże przypomnieć sobie ćwiczenie.", 13, MUTED)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(explanation)
	for key in keys:
		var value := roundi(float(session.pet.skills[key].mastery))
		var reason := TrainingSystem.unlock_reason(session.pet, key)
		var status := "Umiem! Forma %d%%" % roundi(PracticeSystem.form(session.pet, key)) if value >= 100 else "%d%%" % value
		if not reason.is_empty(): status = reason
		var button := _button("%s · %s" % [TrainingSystem.LABELS[key], status], func():
			_choose_trick(key)
			dialog.hide())
		button.disabled = not reason.is_empty()
		list.add_child(button)
	add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	_position_dialog(dialog, Vector2i(320, 400))
	dialog.popup()

func _celebrate_mastery() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Umiem!"
	var next: Array[String] = []
	for key in TrainingSystem.PREREQUISITES:
		if TrainingSystem.PREREQUISITES[key] == selected_trick:
			next.append(TrainingSystem.LABELS[key])
	dialog.dialog_text = "%s opanowuje „%s” na 100%%!\nWspomnienie czeka w Albumie." % [session.pet.pet_name, TrainingSystem.LABELS[selected_trick]]
	dialog.dialog_text += "\nOdblokowane: " + ", ".join(next) if not next.is_empty() else "\nSprawdź kolejne cele na liście sztuczek."
	add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	_position_dialog(dialog, Vector2i(320, 220))
	dialog.popup()

func _choose_trick(key: String) -> void:
	if session.training.phase != "idle": return
	selected_trick = key
	if key == "sit": guidance_toggle.set_pressed_no_signal(false)
	training_feedback_left = 0
	_refresh()

func _care_action(key: String) -> void:
	if session.in_yard and key == "play":
		session.throw_ball(YardFetch.target(room.ball_world, Vector2(100 if room.ball_world.x < 720 else -100, 0)), room.ball_world)
		return
	if session.in_yard and key not in ["pet", "play", "rest"]:
		if not session.change_yard(false): return
		if room.in_yard: room.set_yard(false)
	if key == "train": _select_tab("training")
	elif key == "play": _show_play_menu()
	elif key == "pet" and not session.is_sleeping(): session.start_cuddle()
	else: session.act(key)

func _train(guided: bool) -> void:
	if selected_trick == "sit":
		_train_sit(guided)
		return
	if not guided or selected_trick not in ["lie", "stay"]:
		session.begin_training(selected_trick, guided)
		return
	if is_instance_valid(gesture_dialog) and gesture_dialog.visible: return
	var reason := session.training.readiness(session.pet, selected_trick)
	if not session.writable: return
	# The button is normally disabled here; a typed command still deserves an answer.
	if not reason.is_empty():
		session.say(reason)
		return
	if session.busy(false):
		session.say("Poczekaj, aż piesek skończy tę czynność.")
		return
	var key := selected_trick
	gesture_dialog = AcceptDialog.new()
	var dialog := gesture_dialog
	dialog.title = "Gest: " + TrainingSystem.LABELS[key]
	dialog.get_ok_button().text = "Wróć"
	var gesture := TrainingGesture.new()
	gesture.hold_mode = key == "stay"
	dialog.add_child(gesture)
	gesture.completed.connect(func():
		dialog.hide()
		if not session.suspended and selected_tab == "training" and selected_trick == key:
			session.begin_training(key, true))
	add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			if gesture_dialog == dialog: gesture_dialog = null
			dialog.queue_free())
	_position_dialog(dialog, Vector2i(320, 330))
	dialog.popup()

func _sit_explanation() -> String:
	var mastery := float(session.pet.skills.sit.mastery)
	if mastery >= 80:
		return "%s zna Siad (%d%%). Gest nie jest potrzebny — wystarczy komenda." % [session.pet.pet_name, roundi(mastery)]
	if mastery >= 40: return "Siad jest już znajome. Wystarczy krótki gest ręką."
	return "Najpierw poprowadź smakołyk w górę i za głowę pieska."

func _show_sit_tutorial() -> void:
	if session.suspended or session.training.phase != "idle": return
	if is_instance_valid(gesture_dialog) and gesture_dialog.visible: return
	var dialog := AcceptDialog.new()
	gesture_dialog = dialog
	dialog.title = "Siad · próba pokazowa"
	dialog.ok_button_text = "Wróć"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var lead := _label(_sit_explanation() + "\nPokaz nie zużywa energii ani nie zmienia postępów.", 13)
	lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lead.custom_minimum_size.x = 240
	box.add_child(lead)
	var demo := SitTutorial.new()
	box.add_child(demo)
	dialog.add_child(box)
	demo.completed.connect(func():
		sit_tutorial_seen = true
		var config := ConfigFile.new()
		config.load(ui_settings_path)
		config.set_value("tutorial", "sit_marker_demo", true)
		if config.save(ui_settings_path) != OK: push_warning("Could not save sit tutorial preference.")
		dialog.ok_button_text = "Do treningu"
		_refresh())
	add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			if gesture_dialog == dialog: gesture_dialog = null
			dialog.queue_free())
	_prepare_card_dialog(dialog)
	_position_dialog(dialog, Vector2i(340, 510))
	dialog.popup()

func _train_sit(full_gesture: bool) -> void:
	if is_instance_valid(gesture_dialog) and gesture_dialog.visible: return
	if not sit_tutorial_seen:
		_show_sit_tutorial()
		return
	var mastery := float(session.pet.skills.sit.mastery)
	if mastery >= 80 and not full_gesture:
		session.begin_training("sit", false, true, marker_gentle.button_pressed)
		return
	if is_instance_valid(gesture_dialog) and gesture_dialog.visible: return
	var reason := session.training.readiness(session.pet, "sit")
	if not session.writable or session.busy(false) or not reason.is_empty():
		session.say(reason if not reason.is_empty() else "Dokończmy bieżącą czynność.")
		return
	var dialog := AcceptDialog.new()
	gesture_dialog = dialog
	dialog.title = "Siad · naprowadzenie"
	dialog.ok_button_text = "Przerwij"
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 240
	var hint := _label("Prowadź smakołyk w górę i za głowę.", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 240
	box.add_child(hint)
	var lure := SitLure.new()
	lure.short_signal = mastery >= 40 and not full_gesture
	box.add_child(lure)
	dialog.add_child(box)
	var timer := Timer.new()
	timer.wait_time = 0.1
	dialog.add_child(timer)
	timer.timeout.connect(func(): hint.text = lure.message)
	lure.completed.connect(func():
		dialog.hide()
		if not session.suspended and selected_tab == "training" and selected_trick == "sit":
			session.begin_training("sit", true, true, marker_gentle.button_pressed))
	add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			if gesture_dialog == dialog: gesture_dialog = null
			dialog.queue_free())
	timer.start()
	_prepare_card_dialog(dialog)
	_position_dialog(dialog, Vector2i(340, 380))
	dialog.popup()

func _reward(kind: String) -> void:
	var before: float = session.pet.skills[selected_trick].mastery
	var form_before := PracticeSystem.form(session.pet, selected_trick)
	if session.give_reward(kind):
		gain_label.text = "+%d  %s" % [roundi(session.pet.skills[selected_trick].mastery - before), TrainingSystem.LABELS[selected_trick]]
		if before >= 100:
			var form_after := PracticeSystem.form(session.pet, selected_trick)
			gain_label.text = "Forma +%d → %d%%" % [roundi(form_after - form_before), roundi(form_after)] if form_after > form_before else "Forma %d%% · przećwiczone" % roundi(form_after)
		gain_left = 1.8
		if selected_tab == "training":
			training_feedback = gain_label.text + " · " + session.last_message
			training_feedback_left = 8.0 if session.training.marker_mode and session.training.marker_grade in ["early", "late", "missed"] else 4.0
			_refresh()
		_position_feedback()
		if before < 100 and float(session.pet.skills[selected_trick].mastery) >= 100:
			_celebrate_mastery()

func _show_profile() -> void:
	if session.pet == null: return
	name_edit.text = session.pet.pet_name
	for container in [profile_bars, profile_badges]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	var labels := {"curiosity": "Ciekawość", "patience": "Cierpliwość", "sociability": "Towarzyskość", "sensitivity": "Wrażliwość"}
	for key in labels:
		var value := roundi(float(session.pet.traits[key]) * 100)
		profile_bars.add_child(_label("%s · %d%%" % [labels[key], value], 13))
		var bar := _bar(Color("8ea273"), 8)
		bar.value = value
		profile_bars.add_child(bar)
	profile_traits.text = "Ulubiona nagroda: " + (REWARD_LABELS[session.pet.favorite_reward] if session.pet.milestones.has("favorite_reward") else "odkryjecie ją podczas ćwiczeń")
	profile_life.text = "Charakter dnia: %s\n%s\n\nMałe dziwactwa\n%s" % [LifeSystem.mood_label(session.pet), session.pet.life.mood_reason, "\n".join(PackedStringArray(LifeSystem.quirk_lines(session.pet)))]
	profile_life.text += "\n\nUlubione głaski: " + (WellbeingSystem.favorite_label(session.pet) if session.pet.milestones.has("cuddle_favorite") else "odkryjecie podczas przytulania")
	profile_social.text = "Wasz rytm\n" + DailyRhythm.schedule_label(session.pet) + "\n" + InitiativeSystem.profile_text(session.pet)
	var habits := PersonalitySystem.habit_labels(session.pet)
	if habits.is_empty(): habits.append("Dopiero się poznajemy")
	for habit in habits:
		var badge := _label("♥ " + habit, 12, GREEN)
		badge.add_theme_stylebox_override("normal", _style(Color("e3ead6"), 12, 8))
		profile_badges.add_child(badge)
	profile_dialog.popup()
	_position_dialog(profile_dialog, Vector2i(350, 520))
	profile_dialog.get_ok_button().grab_focus()

func _show_settings() -> void:
	reminders_status.text = reminders.status_text()
	settings_dialog.show()
	settings_dialog.move_to_front()
	settings_scroll.scroll_vertical = 0
	_fit_settings()
	settings_close.grab_focus()

func _fit_settings() -> void:
	safe_rect = _safe_content_rect()
	var panel_size := Vector2(minf(370, safe_rect.size.x - 24), minf(440, safe_rect.size.y - 24))
	_place(settings_dialog, Rect2(safe_rect.position + (safe_rect.size - panel_size) / 2, panel_size))

func _hide_settings() -> void:
	settings_dialog.hide()

func _unhandled_key_input(event: InputEvent) -> void:
	if settings_dialog.visible and event.is_action_pressed("ui_cancel"):
		_hide_settings()
		get_viewport().set_input_as_handled()

func _show_reunion() -> void:
	var report: Dictionary = session.pet.life.away_report
	if report.is_empty(): return
	reunion_text.text = session.last_message + "\n\n" + "\n\n".join(PackedStringArray(report.events)) + "\n\nTa chwila zostaje w Albumie."
	reunion_dialog.popup()
	_position_dialog(reunion_dialog, Vector2i(336, 440))

func _show_command() -> void:
	text_dialog.popup()
	_position_dialog(text_dialog, Vector2i(336, 180))
	command_edit.grab_focus()

func _submit_command() -> void:
	if session.busy(false):
		session.say("Dokończmy najpierw tę czynność.")
		return
	var key := LocalCommands.interpret(command_edit.text)
	if key.is_empty():
		session.say("Wybierz nazwę komendy z listy sztuczek.")
		return
	_choose_trick(key)
	_train(false)

func _refresh() -> void:
	if session.pet == null or name_label == null: return
	var pet := session.pet
	yard_menu.sync()
	_sync_yard_actions()
	if room.in_yard != session.in_yard: room.set_yard(session.in_yard)
	if room.backdrop.decor != pet.decor:
		room.backdrop.decor = pet.decor.duplicate()
		room.backdrop.queue_redraw()
	_refresh_photos()
	if room.animator.sprite.material is ShaderMaterial:
		room.animator.sprite.material.set_shader_parameter("dirt", clampf((80.0 - float(pet.needs.hygiene)) / 60.0, 0, 1))
	_update_attention()
	room.present_hide(session.hide_game.phase, session.hide_game.hiding_spot if session.hide_game.kind == "dog" else -1)
	room.catch_active = session.fetch.catching
	room.ball_throw_enabled = session.play_readiness().is_empty()
	_refresh_companion()
	play_hint.text = session.play.hint()
	play_cue.visible = (session.play.kind == "cups" and session.play.phase in ["ready", "found"]) or (session.play.kind == "tug" and session.play.phase == "demo_done")
	play_cue.text = "Zagraj rundę" if session.play.kind == "tug" else ("Brawo!" if session.play.phase == "found" else "Szukaj!")
	if session.play.kind in SkillPlaySystem.EXTRA:
		play_cue.visible = (session.play.kind == "cups2" and session.play.phase == "guess" and not session.play.assisted) or (session.play.kind == "frisbee" and session.play.phase == "flight" and not session.play.jumped)
		play_cue.text = "Pomóż, Gloria" if session.play.kind == "cups2" else "Skacz!"
	play_again.visible = session.play.phase == "result"
	play_again.disabled = session.play.phase != "result" or (session.busy() and session.activity != "happy")
	room.mood_walk_speed = session.walk_speed()
	room.set_interaction_focus(session.training.phase != "idle" or session.activity == "happy")
	name_label.text = "Piesek" if naming_pending else pet.pet_name
	wellbeing_button.text = "Śpi spokojnie" if session.is_sleeping() else session.wellbeing.label()
	wellbeing_button.feeling = WellbeingSystem.state(session.wellbeing.score())
	wellbeing_button.sleeping = session.is_sleeping()
	wellbeing_button.tooltip_text = "Samopoczucie · dotknij, żeby dowiedzieć się, co pomoże"
	wellbeing_button.accessibility_name = "Samopoczucie: " + wellbeing_button.text
	wellbeing_button.queue_redraw()
	cuddle_hint.text = session.cuddle.feedback
	bond_label.text = BondLevels.summary(pet)
	bond_bar.value = BondLevels.progress(pet)
	bond_detail.text = BondLevels.detail(pet, session._local_now())
	for key in care_buttons:
		var button: IconActionButton = care_buttons[key]
		var need: String = ACTION_NEEDS[key]
		button.need_value = float(pet.needs[need])
		button.caption = LOW_LABELS[key] if button.need_value < 30 else ACTION_LABELS[key]
		# An unavailable action stays tappable so the session can explain why.
		button.disabled = not session.writable
		button.cooldown_left = float(session.cooldowns.get(key, 0))
		button.cooldown_ratio = clampf(button.cooldown_left / float(GameSession.CARE_COOLDOWNS.get(key, 1)), 0, 1)
		button.accessibility_name = "%s. %s %d procent.%s" % [ACTION_LABELS[key], NEED_LABELS[need], roundi(button.need_value), " Kolejny przyrost za %d sekund." % ceili(button.cooldown_left) if button.cooldown_left > 0 else ""]
		button.queue_redraw()
	care_buttons.rest.caption = "Obudź" if session.is_sleeping() else ("Senność" if float(pet.needs.energy) < 30 else "Drzemka")
	care_buttons.rest.icon_name = "sun" if session.is_sleeping() else "moon"
	room.carrying_ball = session.outdoor_commands.key == "come" and session.outdoor_commands.phase == "perform" and session.outdoor_commands.trial.will_succeed
	var command := session.outdoor_commands.available_key(session)
	yard_command_button.visible = not command.is_empty()
	yard_bath_button.visible = command.is_empty()
	yard_command_button.text = "Pochwal" if session.outdoor_commands.phase == "praise" else TrainingSystem.LABELS.get(command, "Komenda")
	yard_command_button.disabled = session.outdoor_commands.phase == "perform" or (command == "come" and session.busy() and not session.outdoor_commands.running())
	# "Dom" is the navigation tab; the yard exit says where it leads.
	yard_button.text = "Do domu" if session.in_yard else "Podwórko"
	sniff_button.visible = session.in_yard
	sniff_button.text = "Przerwij" if session.hide_game.active() else "Chowany"
	sniff_button.disabled = (session.busy(false) and not session.hide_game.active()) or not session.writable
	care_status.text = ("Teraz! Dotknij pieska · premia za chwyt" if session.fetch.catching else fetch_hint(pet.yard_record)) if session.in_yard else _activity_status()
	if session.activity in ["dig_walk", "digging"]: care_status.text = "Idzie do piaskownicy…" if session.activity == "dig_walk" else "Kopie… jeszcze %d s" % ceili(session.activity_left)
	if session.activity == "outing_walk": care_status.text = "Idzie w spokojne miejsce…"
	if session.activity == "outing_pause": care_status.text = "Chwila prywatności…"
	var garden_view := pet.yard_routines.duplicate(true)
	YardRoutines.update(garden_view, Time.get_unix_time_from_system())
	var garden_key := "%s:%d" % [garden_view.plant, int(garden_view.growth / 3600)]
	if room.backdrop.garden_key != garden_key:
		room.backdrop.garden_key = garden_key
		room.backdrop.garden_state = garden_view
		if session.in_yard: room.backdrop.queue_redraw()
	if session.hide_game.active(): care_status.text = session.hide_game.hint()
	if session.outdoor_commands.phase == "praise": care_status.text = "Udało się! Pochwal, aby zaliczyć trening."
	elif session.outdoor_commands.phase == "perform": care_status.text = "Wraca z piłką…" if command == "come" else "Zostań… spokojnie czekamy."
	var visiting := session.visitors.active() and session.in_yard
	room.fence_visitor.present(session.visitors.kind if visiting else "")
	visitor_toolbar.visible = visiting and selected_tab == "care"
	room.yard_controls_bottom = header.get_rect().end.y + 64
	visitor_soothe_button.visible = visiting
	visitor_recall_button.visible = visiting
	visitor_interact_button.visible = visiting
	visitor_soothe_button.disabled = session.visitors.phase in ["recall", "soothe", "greet", "together"]
	visitor_interact_button.disabled = visitor_soothe_button.disabled
	if is_instance_valid(visitor_dialog) and visitor_dialog.visible and (not visiting or session.visitors.kind != visitor_dialog_kind): visitor_dialog.hide()
	visitor_recall_button.disabled = visitor_soothe_button.disabled
	if visiting:
		care_status.text = session.visitors.hint()
	if room.yard_weather.kind != session.weather.kind(session):
		room.yard_weather.kind = session.weather.kind(session)
		room.yard_weather.queue_redraw()
		room.update_placement()
	room.yard_weather.night = DailyRhythm.phase(pet, session._local_now()) == "night"
	room.yard_weather.animate = app_foreground and selected_tab == "care" and not _dialog_open()
	var water_play := session.water.active() and session.in_yard
	room.yard_water.kind = session.water.kind if water_play else ""
	room.yard_water.phase = session.water.phase if water_play else ""
	water_splash_button.visible = water_play
	water_shake_button.visible = water_play
	water_splash_button.disabled = session.water.phase != "ready"
	water_shake_button.disabled = session.water.phase == "shake"
	if water_play:
		sniff_button.hide()
		yard_bath_button.hide()
		yard_command_button.hide()
		care_status.text = session.water.hint()
	var yard_offer := session.in_yard and str(session.invitation.get("kind", "")).begins_with("yard_")
	yard_invite_accept.text = YardInvitations.WORDS[session.invitation.kind][1] if yard_offer else "Zabawmy się"
	yard_invite_accept.visible = yard_offer
	yard_invite_later.visible = yard_offer
	if yard_offer:
		sniff_button.hide()
		yard_bath_button.hide()
		yard_command_button.hide()
		care_status.text = YardInvitations.WORDS[session.invitation.kind][0]
		yard_invite_accept.disabled = not YardInvitations.options(session).has(session.invitation.kind)
	var on_course := session.in_yard and session.course.active()
	room.yard_course.playing = on_course
	room.yard_course.queue_redraw()
	course_action.visible = on_course
	course_stop.visible = on_course
	if on_course:
		sniff_button.hide()
		yard_bath_button.hide()
		yard_command_button.hide()
		care_status.text = session.course.hint()
		course_action.text = "Pochwal" if session.course.phase == "praise" else ("Zostań" if session.course.phase in ["stay_ready", "stay"] else "Skacz")
		course_action.disabled = session.course.phase not in ["jump_ready", "stay_ready", "praise"]
	var resting_outside := session.in_yard and session.yard_rest.active()
	if session.yard_rest.phase == "drink": room.animator.facing_left = false
	room.yard_rest.drinking = session.yard_rest.phase == "drink" and session.yard_rest.drink_stage == 1
	room.yard_rest.animate = app_foreground and selected_tab == "care" and not _dialog_open()
	room.yard_rest.queue_redraw()
	yard_rest_stop.visible = resting_outside
	yard_rest_stop.text = "Obudź" if pet.resting else "Przerwij"
	if resting_outside:
		sniff_button.hide()
		yard_bath_button.hide()
		yard_command_button.hide()
		care_status.text = session.yard_rest.hint(session)
	var potty_busy := session.activity in ["outing_walk", "outing_pause", "outing_praise"]
	var cleanup_ready := not session.visitors.active() and session.invitation.is_empty() and YardRoutines.has_mess(session) and (not session.busy(false) or session.activity == "outing_praise")
	var potty_ready := not session.visitors.active() and session.invitation.is_empty() and YardRoutines.due(session) and YardRoutines.available(session)
	potty_action.visible = session.in_yard and (potty_busy or cleanup_ready or potty_ready)
	potty_action.text = "Sprzątnij" if cleanup_ready else "Na potrzebę"
	potty_action.disabled = not (cleanup_ready or potty_ready) or not session.writable
	if potty_action.visible:
		sniff_button.hide()
		if potty_busy or cleanup_ready:
			yard_bath_button.hide()
			yard_command_button.hide()
		if potty_ready: care_status.text = "Chcę się załatwić · wybierz Na potrzebę"
		if cleanup_ready: care_status.text = "Zbierz kupę do woreczka · Sprzątnij"
	room.yard_potty.present(YardRoutines.has_mess(session), 1.0 - session.activity_left / 4.0 if session.activity == "outing_pause" else 0.0)
	room.yard_potty.animate = app_foreground and not _dialog_open()
	var mastery: float = pet.skills[selected_trick].mastery
	mastery_label.text = "%s · %s" % [TrainingSystem.LABELS[selected_trick], "Umiem! 100%" if mastery >= 100 else "%d%%" % roundi(mastery)]
	mastery_bar.value = mastery
	practice_label.text = "Forma %d%% · ćwiczcie we własnym rytmie" % roundi(PracticeSystem.form(pet, selected_trick))
	var reason := session.training.readiness(pet, selected_trick)
	guided_button.disabled = not session.writable or session.busy(false) or not reason.is_empty()
	guidance_toggle.disabled = session.training.phase != "idle"
	guided_button.text = "Pokaż gest" if guidance_toggle.button_pressed else "Powiedz komendę"
	for key in trick_buttons:
		trick_buttons[key].disabled = session.training.phase != "idle"
		trick_buttons[key].add_theme_stylebox_override("normal", _style(Color("e0e9cf") if key == selected_trick else Color("f1efe2"), 13, 10))
		trick_buttons[key].add_theme_stylebox_override("disabled", _style(Color("e0e9cf") if key == selected_trick else Color("f1efe2"), 13, 10))
		trick_buttons[key].add_theme_color_override("font_disabled_color", INK if key == selected_trick else Color("9b9e8c"))
	sit_help_button.visible = selected_trick == "sit"
	sit_help_button.disabled = session.training.phase != "idle"
	marker_gentle.visible = selected_trick == "sit"
	guidance_toggle.text = ("Pełny gest" if guidance_toggle.button_pressed else "Według nauki") if selected_trick == "sit" else ("Z podpowiedzią" if guidance_toggle.button_pressed else "Bez podpowiedzi")
	if selected_trick == "sit":
		guided_button.text = "Ćwicz Siad" if sit_tutorial_seen else "Zacznij od pokazu"
		if not sit_tutorial_seen: guided_button.disabled = session.suspended or not session.writable
	var marking := session.training.marker_mode and session.training.phase == "attempt"
	marker_button.visible = marking
	marker_button.disabled = not session.writable or session.suspended or session.training.marker_prepare_left > 0
	marker_button.text = "Przygotuj się…" if session.training.marker_prepare_left > 0 else "Klik! — oznacz siad"
	var rewarding := session.training.phase == "reward"
	var attempting := session.training.phase == "attempt"
	training_actions.visible = not rewarding and not attempting
	rewards_row.visible = rewarding or (attempting and not marking)
	for index in training_steps.size():
		training_steps[index].selected = index == (2 if rewarding else (1 if attempting else 0))
	training_steps[1].caption = "2. Klik" if selected_trick == "sit" else "2. Czekaj"
	training_steps[0].caption = "1. Gest" if guidance_toggle.button_pressed or (selected_trick == "sit" and float(pet.skills.sit.mastery) < 80) else "1. Komenda"
	for key in reward_buttons:
		var button: IconActionButton = reward_buttons[key]
		button.disabled = not rewarding or not session.writable
		button.reward_ratio = clampf(session.training.time_left / session.training.reward_duration, 0, 1) if rewarding and not session.training.marker_mode else 0.0
		button.favorite = pet.milestones.has("favorite_reward") and pet.favorite_reward == key
		button.accent = Color("dce8cb") if button.favorite else Color("ecebd7")
		button.accessibility_name = REWARD_LABELS[key] + (", ulubiona nagroda" if button.favorite else "") + (", nagródź teraz" if rewarding else ", czekaj na wykonanie")
		button.queue_redraw()
	if rewarding: training_hint.text = session.last_message if session.training.marker_mode else "Udało się! Wybierz nagrodę, zanim zniknie obwódka."
	elif attempting:
		training_hint.text = "Kliknij, gdy pupa dotknie podłogi." if marking else "Poczekaj, aż piesek skończy ruch."
		if marking and session.training.marker_prepare_left > 0: training_hint.text = "Obserwuj pupę pieska. Ruch zacznie się za chwilę."
	elif training_feedback_left > 0: training_hint.text = training_feedback
	elif not reason.is_empty(): training_hint.text = reason
	elif session.busy(): training_hint.text = _activity_status()
	else: training_hint.text = _sit_explanation() if selected_trick == "sit" else ("Gest pomaga się uczyć." if guidance_toggle.button_pressed else "Sama komenda sprawdza, co już pamięta.")
	training_hint.add_theme_color_override("font_color", Color("8a5f24") if rewarding else INK)
	training_footer.text = "Skupienie %d%%" % roundi(100 - pet.fatigue)
	var had_warning := footer_label.visible
	footer_label.visible = not session.writable or not session.save_ok
	if had_warning != footer_label.visible: _fit_room()
	if not session.writable: footer_label.text = "Nie udało się odczytać postępu. Zapis zachowano."
	elif not session.save_ok: footer_label.text = "Postęp czeka na zapis. Sprawdź wolne miejsce."
	var today_parent: Node = album_actions if selected_tab == "journal" else today_home
	if today_button.get_parent() != today_parent:
		today_button.reparent(today_parent)
	var visitor_lines: PackedStringArray = []
	for guest in YardVisitors.KINDS:
		visitor_lines.append("%s\n%s" % [YardVisitors.LABELS[guest], VisitorMemory.describe(pet, guest)])
	visitor_album_status.text = "\n\n".join(visitor_lines)
	var signature := JSON.stringify(pet.journal)
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
			mark.texture = GameIcons.texture(_journal_icon(str(entry.key)), Color("779265"))
			mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			mark.custom_minimum_size = Vector2(38, 38)
			mark.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			item.add_child(mark)
			var words := VBoxContainer.new()
			words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			words.add_theme_constant_override("separation", 2)
			item.add_child(words)
			var date := Time.get_datetime_dict_from_unix_time(int(entry.at) + int(Time.get_time_zone_from_system().bias) * 60)
			words.add_child(_label("%02d.%02d · %02d:%02d" % [date.day, date.month, date.hour, date.minute], 11, MUTED))
			var entry_title: String = entry.title
			if str(entry.key).begins_with("visitor_") and str(entry.key).contains("_calm_"):
				for count in [1, 2, 3]: entry_title = entry_title.trim_suffix(" %d/3" % count)
			var title := _label(entry_title, 16, INK, true)
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
		yard_menu.close()
		yard_transition.cancel()
		music.set_backgrounded(true)
		effects.set_backgrounded(true)
		haptics.backgrounded = true
		if is_instance_valid(bath_dialog): bath_dialog.hide()
		if is_instance_valid(gesture_dialog): gesture_dialog.hide()
		session.suspend_session()
		play_menu.hide()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		session.resume_session()
		music.set_backgrounded(false)
		effects.set_backgrounded(false)
		haptics.backgrounded = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		haptics.backgrounded = true
		yard_menu.close()
		if session.training.marker_mode and session.training.phase != "idle":
			session.training.cancel()
			session.say("Próba przerwana. Opanowanie pozostaje bez zmian.")
		if is_instance_valid(bath_dialog): bath_dialog.hide()
		if is_instance_valid(gesture_dialog): gesture_dialog.hide()
		session.cancel_cuddle()
		app_foreground = false
		_update_attention()
		session.flush()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		haptics.backgrounded = false
		app_foreground = true
		_update_attention()

# No record before the first fetch; distances use the Polish decimal comma.
static func fetch_hint(record: float) -> String:
	if record <= 0: return "Aport · przeciągnij piłkę i puść"
	return ("Aport · rekord %.1f m · przeciągnij piłkę" % record).replace(".", ",")

func _activity_status() -> String:
	if session.home_drink.active(): return "Idzie do wody…" if session.home_drink.phase == "walk" else "Pije wodę · dotknij miski, aby przerwać"
	if session.cuddle.running(): return "Spokojne chwile · przytulanie"
	if session.activity == "sniff_walk": return "Podąża za zapachem…"
	if session.activity == "sniff": return "Węszy… jeszcze %d s" % ceili(session.activity_left)
	if session.play.running(): return "Wspólna zabawa · " + SkillPlaySystem.label(session.play.kind)
	if not session.invitation.is_empty(): return session.pet.pet_name + " zaprasza Cię do wspólnej chwili"
	if session.training.phase == "reward": return "Czeka na nagrodę · otwórz Trening"
	if session.training.phase == "attempt": return "Wykonuje komendę · otwórz Trening"
	if session.is_sleeping(): return "Śpi · pobudka o " + DailyRhythm._time_label(int(DailyRhythm.next_wake(session.pet, session._local_now()) / 60)) if session.scheduled_sleep else "Odpoczywa"
	# Close-ups can leave no safe space for a bubble; the wake report is still
	# visible in the care panel, above the same actionable need buttons.
	if session.wake_report_left > 0 and companion_card.modulate.a == 0 and not session.busy():
		return CompanionVoice.wake_report(session).text
	if session.activity == "approach":
		return {"feed": "Idzie do miski…", "rest": "Idzie do legowiska…", "play": "Łapie piłkę…"}.get(session._pending_action, "Odkrywa pokój…")
	if session.activity_left > 0 and session.activity in ["feed", "clean", "play", "happy"]:
		return "%s · jeszcze %d s" % [{"feed": "Zajada", "clean": "Czesanie", "play": "Bawi się", "happy": "Cieszy się z nagrody"}[session.activity], ceili(session.activity_left)]
	if YardRoutines.has_mess(session): return "Na podwórku czeka kupa do posprzątania"
	if YardRoutines.due(session) and not DailyRhythm.quiet(session.pet, session._local_now()): return "Chcę wyjść na potrzebę · wybierz Podwórko"
	return session.wellbeing.label() + " · dotknij, by zadbać"

func _show_feedback(text: String) -> void:
	if selected_tab == "training":
		# Keep instructions and outcomes in one place, clear of the puppy.
		training_feedback = text
		training_feedback_left = 8.0 if session.training.marker_mode and session.training.marker_grade in ["early", "late", "missed"] else 4.0
		bubble_left = 0
		_refresh()
		_position_feedback()
		return
	var action := session._pending_action if not session._pending_action.is_empty() else session.activity
	var icon: String = NEED_ICONS.get(ACTION_NEEDS.get(action, ""), "heart")
	if action == "sleep": icon = "moon"
	if session.training.phase != "idle": icon = "spark"
	bubble_icon.texture = GameIcons.texture(icon)
	var short := text
	for entry in [
		["Już idzie do miski", "Idę do miski!"], ["Mała porcja", "Mniam!"],
		["Czas na drzemkę", "Czas na sen…"], ["Miękkie legowisko", "Dobranoc…"],
		["Piłka w ruch", "Łapię!"], ["Piłka złapana", "Jeszcze raz!"],
		["Przymyka oczy", "Lubię być blisko"], ["Kilka ruchów szczotką", "Ale przyjemnie!"],
		["Już idę!", "Już idę!"], ["Koniec drzemki", "Czas na nowy dzień!"]]:
		if text.begins_with(entry[0]):
			short = entry[1]
			break
	message_label.text = short
	bubble_left = 3.5 if short.length() < 35 else 6.0
	bubble.size = Vector2(minf(330, room.size.x - 32) if short.length() > 35 else minf(250, maxf(150, short.length() * 7 + 55)), 0)
	_position_feedback()

func _show_gain(action: String, gains: Dictionary) -> void:
	var need: String = ACTION_NEEDS.get(action, "play")
	if not gains.has(need):
		if gains.is_empty(): return
		need = str(gains.keys()[0])
	var amount := float(gains[need])
	var amount_text := str(roundi(amount)) if amount >= 1 else ("<0,1" if amount < 0.1 else ("%.1f" % amount).replace(".", ","))
	gain_label.text = "+%s  %s" % [amount_text, NEED_LABELS[need]]
	gain_left = 1.8
	for key in gains:
		if needs_ui.has(key): needs_ui[key].flash_left = 1.2
	_position_feedback()

func _process(delta: float) -> void:
	yard_menu.sync()
	if first_meeting != null and first_meeting.visible: _position_dialog(first_meeting, Vector2i(340, 330))
	reminder_poll -= delta
	if settings_dialog.visible and reminder_poll <= 0:
		reminder_poll = 0.5
		reminders_status.text = reminders.status_text()
	_update_attention()
	_refresh_companion(delta)
	bubble_left = maxf(0, bubble_left - delta)
	gain_left = maxf(0, gain_left - delta)
	training_feedback_left = maxf(0, training_feedback_left - delta)
	if session.active:
		for key in care_buttons:
			var button: IconActionButton = care_buttons[key]
			var left := float(session.cooldowns.get(key, 0))
			if button.cooldown_left != left:
				button.cooldown_left = left
				button.cooldown_ratio = clampf(left / float(GameSession.CARE_COOLDOWNS.get(key, 1)), 0, 1)
				button.queue_redraw()
		if session.training.phase == "reward" and not session.training.marker_mode:
			for button in reward_buttons.values():
				button.reward_ratio = clampf(session.training.time_left / session.training.reward_duration, 0, 1)
				button.queue_redraw()
	_position_feedback()

func _position_companion() -> void:
	if companion_card == null or header == null: return
	companion_card.size = Vector2(header.size.x, 0)
	var pet_bounds := room.pet_screen_bounds()
	if companion_card.visible:
		_place_pet_overlay(companion_card, Vector2(header.position.x, room.hud_bottom + 52),
			[pet_bounds.grow(20), room.bowl_rect().grow(4), room.ball_touch_rect().grow(4)])
	var below := companion_card.position.y >= pet_bounds.end.y
	companion_tail.position = Vector2(clampf(pet_bounds.get_center().x - companion_card.position.x, 20, companion_card.size.x - 38), 0 if below else companion_card.size.y)
	companion_tail.scale.y = -1 if below else 1
	# Only move this UI hint; room bounds, camera and the approved framing stay intact.
	if companion_card.visible and not room.overview and session.in_yard:
		room.room_hint.position = Vector2(room.overview_button.get_rect().end.x + 12, room.hud_bottom + 14)

func _place_pet_overlay(control: Control, preferred: Vector2, obstacles: Array[Rect2]) -> bool:
	var left := maxf(12, safe_rect.position.x + 8)
	var right := minf(room.size.x - 12, safe_rect.end.x - 8)
	var top := room.overview_button.get_rect().end.y + 8 if session.in_yard else room.hud_bottom + 8
	var bottom := minf(safe_rect.end.y - 12, room.content_bottom - 12)
	var area := Rect2(left, top, maxf(0, right - left), maxf(0, bottom - top))
	var xs: Array[float] = [clampf(preferred.x, left, maxf(left, right - control.size.x)), left, right - control.size.x]
	var ys: Array[float] = [preferred.y, top]
	for obstacle in obstacles:
		ys.append(obstacle.position.y - control.size.y - 10)
		ys.append(obstacle.end.y + 10)
		xs.append(obstacle.position.x - control.size.x - 10)
		xs.append(obstacle.end.x + 10)
	for y in ys:
		for x in xs:
			var candidate := Rect2(Vector2(x, y), control.size)
			if not area.encloses(candidate): continue
			var clear := true
			for obstacle in obstacles:
				if candidate.intersects(obstacle):
					clear = false
					break
			if clear:
				control.position = candidate.position
				control.modulate.a = 1
				return true
	# A close-up can leave no readable space. Wait for room instead of covering
	# the dog or moving the camera to make an optional message fit.
	# Keep containers participating in layout while wrapped text settles. Hiding
	# them here would freeze their first, narrow-width minimum height forever.
	control.position = Vector2(-10000, -10000)
	control.modulate.a = 0
	return false

func _position_feedback() -> void:
	if bubble == null or header == null: return
	# Wrapping is recalculated by the container after its width changes. Shrink
	# again on the next frame instead of retaining the first narrow-width height.
	bubble.size.y = 0
	var pet_point := room.pet_position()
	var on_screen := room.render_rect.has_point(pet_point) and selected_tab == "care" and not room.overview
	var yard_instruction := session.in_yard and (session.activity in ["outing_walk", "outing_pause", "outing_praise"] or session.water.active() or session.course.active() or session.yard_rest.active() or str(session.invitation.get("kind", "")).begins_with("yard_"))
	bubble.visible = not yard_instruction and not _dialog_open() and not session.portal_active and bubble_left > 0 and on_screen and not session.fetch.catching and not session.hide_game.active() and not (companion_card.visible and companion_card.modulate.a > 0 and companion_data.get("kind") == "invitation")
	gain_label.visible = not _dialog_open() and gain_left > 0 and on_screen and not session.hide_game.active()
	var pet_bounds := room.pet_screen_bounds()
	var head := Vector2(pet_bounds.get_center().x, pet_bounds.position.y)
	var obstacles: Array[Rect2] = [pet_bounds.grow(12)]
	if session.in_yard:
		obstacles.append(yard_toolbar.get_global_rect().grow(4))
		for marker in room.yard_markers.values():
			if marker.visible: obstacles.append(marker.get_global_rect().grow(4))
	var fixed_obstacles := obstacles.size()
	if companion_card.visible and companion_card.modulate.a > 0: obstacles.append(companion_card.get_rect().grow(10))
	if bubble.visible and companion_card.modulate.a > 0 and companion_data.get("kind") in ["thought", "memory"]:
		# A passing thought yields to the immediate reply at every screen width instead
		# of stacking two speech overlays above the dog.
		companion_card.position = Vector2(-10000, -10000)
		companion_card.modulate.a = 0
		obstacles.resize(fixed_obstacles)
	if bubble.visible:
		var preferred := Vector2(head.x - bubble.size.x / 2, head.y - bubble.size.y - 24)
		if not _place_pet_overlay(bubble, preferred, obstacles) and obstacles.size() > 1:
			# On a short screen let the immediate response take the thought's place.
			companion_card.position = Vector2(-10000, -10000)
			companion_card.modulate.a = 0
			obstacles.resize(fixed_obstacles)
			_place_pet_overlay(bubble, preferred, obstacles)
	bubble.modulate.a *= minf(1, bubble_left * 3)
	gain_label.reset_size()
	if bubble.visible and bubble.modulate.a > 0: obstacles.append(bubble.get_rect().grow(8))
	if gain_label.visible:
		_place_pet_overlay(gain_label, Vector2(head.x - gain_label.size.x / 2, pet_bounds.end.y + 24 - (1.8 - gain_left) * 10), obstacles)
	gain_label.modulate.a *= minf(1, gain_left * 2)

func _load_ui_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(ui_settings_path) == OK:
		room.pan_hint_dismissed = config.get_value("tutorial", "room_dragged", false) == true
		sit_tutorial_seen = config.get_value("tutorial", "sit_marker_demo", false) == true
		if config.has_section("yard_seen"):
			for id in config.get_section_keys("yard_seen"):
				if config.get_value("yard_seen", id, false) == true: room.yard_seen[id] = true
	room.room_hint.visible = not room.pan_hint_dismissed

func _remember_yard_place(id: String) -> void:
	var config := ConfigFile.new()
	config.load(ui_settings_path)
	config.set_value("yard_seen", id, true)
	if config.save(ui_settings_path) != OK: push_warning("Could not save yard place hint.")

func _remember_pan() -> void:
	var config := ConfigFile.new()
	config.load(ui_settings_path)
	config.set_value("tutorial", "room_dragged", true)
	if config.save(ui_settings_path) != OK: push_warning("Could not save room tutorial preference.")

func _journal_icon(key: String) -> String:
	if key.begins_with("adventure_"): return "spark"
	if key.begins_with("first_") or key.begins_with("learned_"): return "spark"
	if key.begins_with("habit_"): return "paw"
	return {"welcome": "home", "feed": "bowl", "rest": "moon", "play": "ball", "pet": "heart", "clean": "brush", "favorite_reward": "treat"}.get(key, "book")

func _show_yard_rest() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Chwila w cieniu"
	dialog.get_ok_button().text = "Wróć"
	var box := VBoxContainer.new()
	dialog.add_child(box)
	for option in [["bed", "Połóż się w cieniu"], ["drink", "Napij się wody"]]:
		var kind: String = option[0]
		box.add_child(_button(option[1], func():
			dialog.hide()
			session.yard_rest.start(session, kind)))
	add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	_position_dialog(dialog, Vector2i(290, 190))
	dialog.popup()

func _toggle_yard(animated: bool = true) -> void:
	yard_menu.close()
	if session.in_yard and session.yard_rest.phase == "rest":
		session.change_yard(false)
		return
	if animated:
		yard_transition.start(not session.in_yard)
		return
	if session.change_yard(not session.in_yard):
		gain_left = 0
		gain_label.hide()
		if room.in_yard != session.in_yard: room.set_yard(session.in_yard)

func _course_action() -> void:
	match session.course.phase:
		"jump_ready": session.course.jump(session)
		"stay_ready": session.course.stay(session)
		"praise": session.course.praise(session)

func _on_room_care_requested(action: String) -> void:
	if action.begins_with("yard_") and yard_menu.offer(action.trim_prefix("yard_")): return
	yard_menu.close()
	_room_care_action(action)

func _room_care_action(action: String) -> void:
	if action == "drink":
		session.home_drink.start(session)
		return
	if action == "visitor":
		_show_visitor_interactions()
		return
	if action == "catch":
		session.catch_ball()
		return
	if action.begins_with("yard_") and session.in_yard:
		var place := action.trim_prefix("yard_")
		if place == "gate": _toggle_yard()
		elif place == "shade": _show_yard_rest()
		elif place == "course": session.course.start(session)
		elif place == "dig": DiggingSystem.start(session)
		elif place in YardWater.SPOTS: session.water.start(session, place)
		elif place == "garden": _show_garden()
		elif place == "outing":
			if YardRoutines.has_mess(session): YardRoutines.clean_up(session)
			elif not YardRoutines.start_outing(session): session.say("Dziś już byliśmy. Możecie spokojnie pobyć na podwórku." if not YardRoutines.due(session) else "Zakończmy obecną czynność przed wyjściem.")
		elif place == "fetch":
			if session.play_readiness().is_empty(): _aim_ball()
		elif place.begins_with("bush_"):
			var spot := int(place.trim_prefix("bush_"))
			if session.hide_game.active(): session.choose_hide_bush(spot)
			else: session.start_sniff(spot)
		return
	if action == "door": _toggle_yard()
	elif session.in_yard and action == "play":
		session.throw_ball(YardFetch.target(room.ball_world, Vector2(100 if room.ball_world.x < 720 else -100, 0)), room.ball_world)
	else: session.act(action)

func _show_bath() -> void:
	OutdoorPanels._show_bath(self)

func _take_photo() -> void:
	if taking_photo or not session.writable or session.suspended or session.in_bath: return
	if BondLevels.heart(session.pet) < 4:
		await _capture_photo(false)
		return
	var ui := ProgressionPanels.panel(self, "Zdjęcie razem")
	for framed in [false, true]:
		ui.box.add_child(_button("Z ramką: Nasze serca" if framed else "Bez ramki", func():
			ui.dialog.hide()
			_capture_photo(framed)))
	ui.dialog.popup()

func _capture_photo(heart_frame: bool) -> void:
	if taking_photo or not session.writable or session.suspended or session.in_bath: return
	if session.pet.photos.size() >= KeepsakeSystem.MAX_PHOTOS:
		session.say("Album mieści 24 zdjęcia. Twoje fotografie pozostają zachowane.")
		return
	taking_photo = true
	var outside := session.in_yard
	await RenderingServer.frame_post_draw
	if session.suspended or session.in_bath or not room.visible or outside != session.in_yard:
		taking_photo = false
		return
	var picture := room.viewport.get_texture().get_image()
	KeepsakeSystem.save_photo(session, picture, "%s · %s" % [session.pet.pet_name, "Podwórko" if outside else "Dom"], heart_frame)
	taking_photo = false

func _refresh_photos() -> void:
	if photos_list == null: return
	var signature := JSON.stringify(session.pet.photos)
	if photo_signature == signature: return
	photo_signature = signature
	for child in photos_list.get_children():
		photos_list.remove_child(child)
		child.queue_free()
	for photo in session.pet.photos:
		var box := VBoxContainer.new()
		photos_list.add_child(box)
		box.add_child(_label(photo.caption, 15, INK, true))
		var date := Time.get_datetime_dict_from_unix_time(int(photo.at) + int(Time.get_time_zone_from_system().bias) * 60)
		box.add_child(_label("%02d.%02d · %02d:%02d" % [date.day, date.month, date.hour, date.minute], 11, MUTED))
		box.add_child(_button("Usuń z Albumu", func(): _confirm_remove_photo(photo.id)))
		var path := KeepsakeSystem.photo_path(session.storage.path, photo.id)
		var picture := Image.new()
		if not FileAccess.file_exists(path) or picture.load(path) != OK:
			box.add_child(_label("Plik zdjęcia jest niedostępny.", 13, MUTED))
			continue
		var texture := ImageTexture.create_from_image(picture)
		var preview := TextureRect.new()
		preview.texture = texture
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.custom_minimum_size = Vector2(0, 160)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		box.add_child(preview)
		box.add_child(_button("Otwórz zdjęcie", func(): _show_photo(texture, photo.caption)))

func _show_photo(texture: Texture2D, caption: String) -> void:
	var dialog := AcceptDialog.new()
	dialog.title = caption
	var preview := TextureRect.new()
	preview.texture = texture
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.custom_minimum_size = Vector2(250, 300)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialog.add_child(preview)
	add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	_position_dialog(dialog, Vector2i(340, 420))
	dialog.popup()

func _show_decor() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Dekoracje pokoju"
	var list := VBoxContainer.new()
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	for key in KeepsakeSystem.DECOR:
		var reason := KeepsakeSystem.unlock_reason(session.pet, key)
		var preview := TextureRect.new()
		if RoomArtwork.DECOR_REGIONS.has(key):
			var atlas := AtlasTexture.new()
			atlas.atlas = RoomArtwork.DECOR_ATLAS
			atlas.region = RoomArtwork.DECOR_REGIONS[key]
			preview.texture = atlas
		else: preview.texture = GameIcons.texture("flower" if YardRoutines.PLANTS.has(key) else ("heart" if key == "cushion" else "paw"))
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.custom_minimum_size = Vector2(0, 62)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		list.add_child(preview)
		var button := _button(("Schowaj: " if session.pet.decor.has(key) else "Ustaw: ") + KeepsakeSystem.DECOR[key], func():
			if KeepsakeSystem.toggle_decor(session, key):
				dialog.hide()
				_show_decor())
		button.disabled = not reason.is_empty() or not session.writable
		list.add_child(button)
		if not reason.is_empty():
			var hint := _label(reason, 12, MUTED)
			hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			list.add_child(hint)
	add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	_position_dialog(dialog, Vector2i(330, 480))
	dialog.popup()

func _show_yard_games() -> void:
	OutdoorPanels._show_yard_games(self)

func _confirm_remove_photo(id: String) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.title = "Usunąć zdjęcie z Albumu?"
	dialog.dialog_autowrap = true
	dialog.dialog_text = "Zwolnisz jedno miejsce w Albumie. Pozostałe zdjęcia i postępy pieska zostaną zachowane. Plik pozostanie w danych aplikacji dla starszych kopii zapisu."
	dialog.get_ok_button().text = "Usuń z Albumu"
	dialog.get_cancel_button().text = "Zachowaj"
	dialog.confirmed.connect(func(): KeepsakeSystem.remove_photo(session, id))
	add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	_position_dialog(dialog, Vector2i(300, 260))
	dialog.popup()

func _show_garden() -> void:
	OutdoorPanels._show_garden(self)

func _build_cuddle_dialog() -> void:
	wellbeing_dialog = AcceptDialog.new()
	wellbeing_dialog.ok_button_text = "Zamknij"
	wellbeing_dialog.min_size = Vector2i(280, 150)
	add_child(wellbeing_dialog)
	cuddle_dialog = AcceptDialog.new()
	cuddle_dialog.title = "Chwila bliskości"
	cuddle_dialog.ok_button_text = "Zakończ"
	cuddle_dialog.min_size = Vector2i(280, 350)
	add_child(cuddle_dialog)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	cuddle_dialog.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	scroll.add_child(box)
	cuddle_hint = _label("Powoli głaszcz grzbiet w obie strony.", 15, INK, true)
	cuddle_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(cuddle_hint)
	cuddle_view = CuddleView.new()
	cuddle_view.model = session.cuddle
	cuddle_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cuddle_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(cuddle_view)
	cuddle_view.pressed_at.connect(session.cuddle_press)
	cuddle_view.moved_to.connect(session.cuddle_move)
	cuddle_view.released_at.connect(session.cuddle_release)
	cuddle_dialog.visibility_changed.connect(func():
		if not cuddle_dialog.visible: session.cancel_cuddle())

func _show_cuddle() -> void:
	cuddle_hint.text = session.cuddle.feedback
	cuddle_dialog.popup()
	_position_dialog(cuddle_dialog, Vector2i(350, 430))

func _show_wellbeing() -> void:
	var need := session.wellbeing.lowest_part()
	var explanation := "Miło mi z Tobą. Możemy się przytulić albo pobawić."
	if WellbeingSystem.state(session.wellbeing.score()) <= 1:
		explanation = str(CompanionVoice.NEEDS[need][0])
	if session.wellbeing.reunion_left > 0: explanation = "Miło Cię znowu widzieć! Posiedzisz ze mną?"
	if session.is_sleeping(): explanation = "Śpię spokojnie. Przytulimy się po pobudce."
	wellbeing_dialog.title = "Samopoczucie · " + wellbeing_button.text
	wellbeing_dialog.dialog_text = explanation
	wellbeing_dialog.popup()
	_position_dialog(wellbeing_dialog, Vector2i(320, 200))

func _show_visitor_interactions() -> void:
	if not session.visitors.active() or not session.in_yard: return
	if session.visitors.phase in ["soothe", "recall", "greet", "together"]: return
	if is_instance_valid(visitor_dialog):
		visitor_dialog.hide()
		visitor_dialog.queue_free()
	visitor_dialog_kind = session.visitors.kind
	var guest := visitor_dialog_kind
	visitor_dialog = AcceptDialog.new()
	var dialog := visitor_dialog
	dialog.title = YardVisitors.LABELS[guest]
	dialog.ok_button_text = "Wróć"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	dialog.add_child(box)
	var status := _label(VisitorMemory.describe(session.pet, guest), 16, INK, true)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size.x = 240
	box.add_child(status)
	var explanation := _label("Przyjaźń rośnie po spokojnych spotkaniach w trzech różnych dniach. Przerwa jej nie osłabia.", 14, MUTED)
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation.custom_minimum_size.x = 240
	box.add_child(explanation)
	for entry in [["greet", "Przywitaj się spokojnie"], ["together", "Pobądźcie razem"]]:
		var choice: String = entry[0]
		var button := _button(entry[1], func():
			dialog.hide()
			if session.visitors.kind == guest: session.visitors.respond(session, choice))
		button.disabled = choice == "together" and VisitorMemory.level(session.pet, guest) < 1
		box.add_child(button)
	add_child(dialog)
	for state in ["normal", "hover", "pressed", "disabled"]:
		dialog.get_ok_button().add_theme_stylebox_override(state, _style(Color("efeeda"), 12, 14))
	_position_dialog(dialog, Vector2i(320, 330))
	dialog.popup()
