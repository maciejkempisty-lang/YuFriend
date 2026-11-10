extends Control

const INK := Color("394a40")
const MUTED := Color("687661")
const GREEN := Color("68856d")
const CREAM := Color("fffaf0")
const NEED_LABELS := {"fullness": "Sytość", "energy": "Energia", "hygiene": "Czystość", "play": "Zabawa", "contact": "Bliskość"}
const REWARD_LABELS := {"treat": "Smakołyk", "praise": "Pochwała", "play": "Zabawa"}
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

func _ready() -> void:
	get_tree().auto_accept_quit = false
	var app_theme := Theme.new()
	app_theme.default_font_size = 18
	app_theme.set_color("font_color", "Label", INK)
	app_theme.set_color("font_color", "Button", INK)
	# Dialogs inherit the same light palette as the room and action panels.
	app_theme.set_stylebox("panel", "AcceptDialog", _style(CREAM, 14, 14))
	var window_border := _style(GREEN, 14, 8)
	window_border.content_margin_top = 32
	window_border.expand_margin_top = 32
	window_border.expand_margin_left = 5
	window_border.expand_margin_right = 5
	window_border.expand_margin_bottom = 5
	app_theme.set_stylebox("embedded_border", "Window", window_border)
	app_theme.set_stylebox("embedded_unfocused_border", "Window", window_border)
	app_theme.set_color("title_color", "Window", CREAM)
	for type in ["Button", "OptionButton"]:
		app_theme.set_stylebox("normal", type, _style(Color("f2ecdf"), 10, 10))
		app_theme.set_stylebox("hover", type, _style(Color("e8e3d4"), 10, 10))
		app_theme.set_stylebox("pressed", type, _style(GREEN, 10, 10))
		app_theme.set_color("font_color", type, INK)
		app_theme.set_color("font_hover_color", type, INK)
		app_theme.set_color("font_pressed_color", type, CREAM)
	app_theme.set_stylebox("normal", "LineEdit", _style(Color("f2ecdf"), 10, 10))
	app_theme.set_color("font_color", "LineEdit", INK)
	app_theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	app_theme.set_color("caret_color", "LineEdit", INK)
	var focus_style := _style(Color.TRANSPARENT, 10, 10)
	focus_style.set_border_width_all(2)
	focus_style.border_color = GREEN
	app_theme.set_stylebox("focus", "LineEdit", focus_style)
	app_theme.set_stylebox("panel", "PopupMenu", _style(CREAM, 10, 8))
	app_theme.set_stylebox("hover", "PopupMenu", _style(GREEN, 8, 8))
	app_theme.set_color("font_color", "PopupMenu", INK)
	app_theme.set_color("font_hover_color", "PopupMenu", CREAM)
	theme = app_theme
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
	var path := "user://pet.json"
	if OS.get_cmdline_user_args().has("--qa"): path = "user://qa-ui/pet.json"
	if not save_path_override.is_empty(): path = save_path_override
	session.start(path)
	_refresh()

func _style(color: Color, radius: int = 14, padding: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

func _label(text: String, font_size: int = 18, color: Color = INK) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(text: String, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 43)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_stylebox_override("normal", _style(GREEN if primary else Color("f2ecdf"), 12, 8))
	button.add_theme_stylebox_override("hover", _style(Color("7d977d") if primary else Color("e8e3d4"), 12, 8))
	button.add_theme_stylebox_override("pressed", _style(Color("58745e"), 12, 8))
	button.add_theme_stylebox_override("disabled", _style(Color("edeae1"), 12, 8))
	button.add_theme_color_override("font_color", CREAM if primary else INK)
	button.add_theme_color_override("font_hover_color", CREAM if primary else INK)
	button.add_theme_color_override("font_pressed_color", CREAM)
	button.add_theme_color_override("font_disabled_color", Color("9c9e91"))
	button.pressed.connect(callback)
	return button

func _bar(color: Color, height: int = 7) -> ProgressBar:
	var progress := ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = height
	progress.add_theme_stylebox_override("background", _style(Color("e6e3d8"), height, 0))
	progress.add_theme_stylebox_override("fill", _style(color, height, 0))
	return progress

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color("f6f2e9")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margins := MarginContainer.new()
	margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		margins.add_theme_constant_override("margin_" + side, 20)
	scroll.add_child(margins)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margins.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var identity := VBoxContainer.new()
	identity.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity.add_theme_constant_override("separation", 0)
	header.add_child(identity)
	identity.add_child(_label("YuFriend  ·  WASZ MAŁY DOM", 13, GREEN))
	name_label = _label("Biszkopt", 32)
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	identity.add_child(name_label)
	bond_label = _label("Szczeniak · Poznajecie się", 14, MUTED)
	identity.add_child(bond_label)
	var profile_button := _button("Profil", _show_profile)
	profile_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	profile_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	profile_button.custom_minimum_size.x = 78
	header.add_child(profile_button)
	var needs_row := HBoxContainer.new()
	needs_row.add_theme_constant_override("separation", 10)
	content.add_child(needs_row)
	for key in PetState.NEED_KEYS:
		var column := VBoxContainer.new()
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_theme_constant_override("separation", 5)
		needs_row.add_child(column)
		column.add_child(_label(NEED_LABELS[key], 13, MUTED))
		var bar := _bar(GREEN)
		column.add_child(bar)
		var value := _label("80", 14)
		column.add_child(value)
		needs_ui[key] = {"bar": bar, "value": value}
	content.add_child(room)
	var bubble := PanelContainer.new()
	bubble.add_theme_stylebox_override("panel", _style(Color("ece9dd"), 15, 12))
	bubble.custom_minimum_size.y = 58
	content.add_child(bubble)
	message_label = _label("Witaj w Waszym małym domu.", 16)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bubble.add_child(message_label)
	var navigation := HBoxContainer.new()
	navigation.add_theme_constant_override("separation", 7)
	content.add_child(navigation)
	for key in ["care", "training", "journal"]:
		var button := _button({"care": "Opieka", "training": "Trening", "journal": "Wspomnienia"}[key], _select_tab.bind(key))
		button.add_theme_font_size_override("font_size", 16)
		navigation.add_child(button)
		tab_buttons[key] = button
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(CREAM, 20, 15))
	panel.custom_minimum_size.y = 250
	content.add_child(panel)
	panels.care = _build_care()
	panels.training = _build_training()
	panels.journal = _build_journal()
	for key in panels:
		panel.add_child(panels[key])
	footer_label = _label("Wasz postęp zapisuje się automatycznie", 12, MUTED)
	footer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(footer_label)
	_build_dialogs()
	_select_tab("care")

func _build_care() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	box.add_child(grid)
	var labels := {"feed": "Jedzenie", "pet": "Głaskanie", "play": "Zabawa", "clean": "Czesanie", "rest": "Odpoczynek", "train": "Poćwiczmy"}
	for key in ["feed", "pet", "play", "clean", "rest", "train"]:
		var button := _button(labels[key], _care_action.bind(key), key == "train")
		button.custom_minimum_size.y = 53
		grid.add_child(button)
		care_buttons[key] = button
	var tip := _label("Małe rytuały, wielka przyjaźń.\nDotknij podłogi, a piesek podejdzie bliżej.", 14, MUTED)
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(tip)
	return box

func _build_training() -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	box.add_child(choices)
	for key in PetState.TRICK_KEYS:
		var button := _button(TrainingSystem.LABELS[key], _choose_trick.bind(key))
		button.add_theme_font_size_override("font_size", 15)
		choices.add_child(button)
		trick_buttons[key] = button
	mastery_label = _label("Poznaje pierwszą komendę", 14, MUTED)
	box.add_child(mastery_label)
	mastery_bar = _bar(GREEN, 6)
	box.add_child(mastery_bar)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	box.add_child(actions)
	guided_button = _button("Pokaż gest", _train.bind(true), true)
	command_button = _button("Poproś samodzielnie", _train.bind(false))
	command_button.add_theme_font_size_override("font_size", 15)
	actions.add_child(guided_button)
	actions.add_child(command_button)
	training_hint = _label("Pokaż gest, poczekaj na wykonanie i nagródź.", 14)
	training_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(training_hint)
	reward_bar = _bar(Color("bd9864"), 7)
	box.add_child(reward_bar)
	var rewards := HBoxContainer.new()
	rewards.add_theme_constant_override("separation", 6)
	box.add_child(rewards)
	for key in TrainingSystem.REWARDS:
		var button := _button(REWARD_LABELS[key], _reward.bind(key))
		button.add_theme_font_size_override("font_size", 15)
		rewards.add_child(button)
		reward_buttons[key] = button
	var bottom := HBoxContainer.new()
	box.add_child(bottom)
	training_footer = _label("", 12, MUTED)
	training_footer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(training_footer)
	var text_button := _button("Wpisz komendę", _show_command)
	text_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	text_button.add_theme_font_size_override("font_size", 12)
	text_button.custom_minimum_size.y = 30
	bottom.add_child(text_button)
	return box

func _build_journal() -> ScrollContainer:
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 225
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	journal_list = VBoxContainer.new()
	journal_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	journal_list.add_theme_constant_override("separation", 13)
	scroll.add_child(journal_list)
	return scroll

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
		var button: Button = tab_buttons[tab]
		button.add_theme_stylebox_override("normal", _style(GREEN if tab == key else Color("eae6db"), 12, 8))
		button.add_theme_color_override("font_color", CREAM if tab == key else INK)
	_refresh()

func _fit_room() -> void:
	room.custom_minimum_size.y = clampf(size.x * 0.62, 245, 310)

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
	bond_label.text = "Szczeniak · Więź %d%%" % roundi(pet.bond)
	message_label.text = session.last_message
	for key in needs_ui:
		needs_ui[key].bar.value = float(pet.needs[key])
		needs_ui[key].value.text = "%d" % roundi(float(pet.needs[key]))
	if applied_skin != pet.skin:
		applied_skin = pet.skin
		room.animator.set_skin(load("res://data/skins/puppy_%s.tres" % pet.skin))
	for key in care_buttons:
		care_buttons[key].disabled = not session.writable or (key != "train" and (session.busy() or float(session.cooldowns.get(key, 0)) > 0 or (pet.resting and key != "rest")))
	care_buttons.rest.text = "Obudź delikatnie" if pet.resting else "Odpoczynek"
	var mastery: float = pet.skills[selected_trick].mastery
	var level := "Poznaje gest" if mastery < 25 else ("Ćwiczy z Tobą" if mastery < 75 else "Coraz pewniej")
	mastery_label.text = "%s · %s · %d%%" % [TrainingSystem.LABELS[selected_trick], level, roundi(mastery)]
	mastery_bar.value = mastery
	var reason := session.training.readiness(pet, selected_trick)
	guided_button.disabled = not session.writable or session.busy() or not reason.is_empty()
	command_button.disabled = guided_button.disabled
	for key in trick_buttons:
		trick_buttons[key].disabled = session.training.phase != "idle"
		trick_buttons[key].add_theme_stylebox_override("normal", _style(Color("dce7d7") if key == selected_trick else Color("f2ecdf"), 10, 8))
	var rewarding := session.training.phase == "reward"
	reward_bar.value = maxf(0, session.training.time_left / session.training.reward_duration * 100) if rewarding else 0
	for key in reward_buttons: reward_buttons[key].disabled = not rewarding or not session.writable
	if rewarding: training_hint.text = "Teraz! Wybierz nagrodę — %.1f s" % session.training.time_left
	elif session.training.phase == "attempt": training_hint.text = "Piesek próbuje. Poczekaj na dobry moment…"
	elif not reason.is_empty(): training_hint.text = reason
	else: training_hint.text = "Pokaż gest, poczekaj na wykonanie i nagródź."
	training_footer.text = "Skupienie %d%%" % roundi(100 - pet.fatigue)
	if not session.writable:
		footer_label.text = "Zapis wymaga odzyskania. Dotychczasowe pliki zachowano."
	elif not session.save_ok:
		footer_label.text = "Postęp czeka na zapis. Sprawdź wolne miejsce na urządzeniu."
	else:
		footer_label.text = "Wasz postęp zapisuje się automatycznie"
	var signature := str(pet.journal.size()) + (str(pet.journal[0].key) if not pet.journal.is_empty() else "")
	if journal_signature != signature:
		journal_signature = signature
		journal_count = pet.journal.size()
		for child in journal_list.get_children():
			journal_list.remove_child(child)
			child.queue_free()
		for entry in pet.journal:
			var item := VBoxContainer.new()
			item.add_theme_constant_override("separation", 3)
			journal_list.add_child(item)
			var date := Time.get_datetime_dict_from_unix_time(int(entry.at) + int(Time.get_time_zone_from_system().bias) * 60)
			item.add_child(_label("%02d.%02d · %02d:%02d" % [date.day, date.month, date.hour, date.minute], 12, MUTED))
			item.add_child(_label(entry.title, 18))
			var detail := _label(entry.detail, 14, MUTED)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			item.add_child(detail)

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
