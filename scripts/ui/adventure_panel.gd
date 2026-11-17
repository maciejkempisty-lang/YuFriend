class_name AdventurePanel
extends RefCounted

# All entry points open this same optional Today panel.
static func show_plan(app: GameUI) -> void:
	for child in app.get_children():
		if child is AcceptDialog and child.title == "Dziś" and child.visible: return
	var ui := ProgressionPanels.panel(app, "Dziś")
	var intro := app._label("Wybierz coś, jeśli masz ochotę. Niczego nie trzeba nadrabiać.", 14, app.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.box.add_child(intro)
	var cards := VBoxContainer.new()
	cards.add_theme_constant_override("separation", 12)
	ui.box.add_child(cards)
	var last_view: Array = []
	var refresh := func():
		var suggestions := TodayPlan.suggestions(app.session.pet, app.session._local_now())
		if suggestions == last_view: return
		last_view.assign(suggestions.duplicate(true))
		for child in cards.get_children():
			cards.remove_child(child)
			child.queue_free()
		for suggestion in suggestions:
			var title := app._label(suggestion.title, 16, app.INK, true)
			title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cards.add_child(title)
			var detail := app._label(suggestion.detail, 13, app.MUTED)
			detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			cards.add_child(detail)
			var task: String = suggestion.id
			cards.add_child(app._button(suggestion.button, func():
				ui.dialog.hide()
				open_activity(app, task)))
	var timer := Timer.new()
	timer.wait_time = 1
	ui.dialog.add_child(timer)
	timer.timeout.connect(refresh)
	timer.start()
	refresh.call()
	ui.dialog.visibility_changed.connect(app._update_attention)
	app._position_dialog(ui.dialog, Vector2i(360, 560))
	ui.dialog.popup()
	app._update_attention()

static func open_activity(app: GameUI, task: String) -> void:
	if task == "album":
		app._select_tab("journal")
	elif task == "trick":
		app._select_tab("training")
	else:
		app._select_tab("care")
		if task in ["garden", "treasure"]:
			if not app.session.in_yard:
				# The normal doorway animation remains the route outside.
				app._toggle_yard()
			elif task == "garden": app._show_garden()
			else: app._show_yard_games()
		elif task == "rest":
			if app.session.in_yard: app._toggle_yard()
			elif not app.session.is_sleeping(): app.session.act("rest")
		else:
			app.room.focus_pet(false)
