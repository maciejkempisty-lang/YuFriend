class_name OutdoorPanels
extends RefCounted

static func _show_bath(app: GameUI) -> void:
	if is_instance_valid(app.bath_dialog) and app.bath_dialog.visible: return
	if not LevelActions.run(app.session, "bath"): return
	app.room.set_yard(false)
	app.bath_dialog = AcceptDialog.new()
	var dialog := app.bath_dialog
	dialog.title = "Łazienka"
	dialog.get_ok_button().text = "Wróć do domu"
	var view := BathView.new()
	view.bath = app.session.bath
	view.initial_dirt = clampf((80.0 - float(app.session.pet.needs.hygiene)) / 60.0, 0, 1)
	dialog.add_child(view)
	view.finished.connect(func():
		if app.session.finish_bath(): view.celebrate())
	app.add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible:
			app.session.cancel_bath()
			dialog.queue_free())
	app._position_dialog(dialog, Vector2i(340, 430))
	dialog.popup()


static func _show_yard_games(app: GameUI) -> void:
	if app.session.hide_game.active():
		app.session.cancel_hide()
		app.session.say("Chowany przerwany. Możecie spróbować ponownie.")
		return
	if not app.session.in_yard: return
	var reason := app.session.play_readiness()
	if not reason.is_empty():
		app.session.say(reason)
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Zabawy w krzakach"
	dialog.get_ok_button().text = "Wróć"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	dialog.add_child(box)
	for entry in [["sniff", "Węsz i szukaj skarbów"], ["treat", "Schowaj smakołyk"], ["dog", "Znajdź pieska po ogonie"]]:
		var mode: String = entry[0]
		if not RoomLayoutLoader.allows("sniff" if mode == "sniff" else "hide", "yard"): continue
		box.add_child(app._button(entry[1], func():
			dialog.hide()
			LevelActions.run(app.session, "sniff" if mode == "sniff" else "hide", {"kind": mode})))
	app.add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	app._position_dialog(dialog, Vector2i(300, 240))
	dialog.popup()


static func _show_garden(app: GameUI) -> void:
	if not RoomLayoutLoader.allows("garden", "yard"): return
	if not YardRoutines.available(app.session):
		app.session.say("Ogródek poczeka. Najpierw zakończmy obecną czynność.")
		return
	var dialog := AcceptDialog.new()
	dialog.title = "Ogródek"
	dialog.get_ok_button().text = "Wróć"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 230)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	app.session.weather.water_garden(app.session)
	var description := app._label(YardRoutines.describe(app.session.pet.yard_routines, Time.get_unix_time_from_system()), 15, app.MUTED)
	description.custom_minimum_size.x = 260
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(description)
	var state := app.session.pet.yard_routines.duplicate(true)
	YardRoutines.update(state, Time.get_unix_time_from_system())
	var choices: Dictionary = YardRoutines.PLANTS if state.plant == "" else ({"harvest": "Zbierz kwiat"} if state.growth >= YardRoutines.GROW_TIME else ({"water": "Podlej"} if YardRoutines.can_water(app.session) else {"observe": "Obejrzyj grządkę"}))
	for key in choices:
		var action: String = key
		var button := app._button(("Posadź: " if state.plant == "" else "") + choices[key], func():
			LevelActions.run(app.session, "garden", {"action": action})
			dialog.hide()
			app._show_garden())
		button.disabled = action == "water" and not YardRoutines.can_water(app.session)
		box.add_child(button)
	var collection := app._label("Kolekcja kwiatów: %d/3. Wzrost trwa 3 podlane doby." % state.flowers.size(), 12, app.MUTED)
	collection.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(collection)
	app.add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	var weak_dialog: WeakRef = weakref(dialog)
	var close_if_away := func():
		var current: AcceptDialog = weak_dialog.get_ref()
		if current != null and (not app.session.in_yard or app.session.suspended): current.hide()
	app.session.changed.connect(close_if_away)
	dialog.tree_exiting.connect(func():
		if app.session.changed.is_connected(close_if_away): app.session.changed.disconnect(close_if_away))
	app._position_dialog(dialog, Vector2i(300, 340))
	dialog.popup()

static func command(app: GameUI) -> void:
	var commands := app.session.outdoor_commands
	if commands.phase == "praise":
		LevelActions.run(app.session, "outdoor_commands")
		return
	var key := commands.available_key(app.session)
	if key.is_empty() or commands.running(): return
	var reason := app.session.training.readiness(app.session.pet, key)
	if not reason.is_empty():
		app.session.say(reason)
		return
	var dialog := AcceptDialog.new()
	dialog.title = TrainingSystem.LABELS[key] + " w zabawie"
	dialog.get_ok_button().text = "Pomiń"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	dialog.add_child(box)
	for guided in [false, true]:
		box.add_child(app._button("Komenda z gestem" if guided else "Sama komenda", func():
			dialog.hide()
			if commands.available_key(app.session) == key: LevelActions.run(app.session, "outdoor_commands", {"guided": guided})))
	app.add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	app._position_dialog(dialog, Vector2i(290, 210))
	dialog.popup()
