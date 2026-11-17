class_name ProgressionPanels
extends RefCounted

static func panel(app: GameUI, title: String) -> Dictionary:
	var dialog := AcceptDialog.new()
	dialog.title = title
	dialog.get_ok_button().text = "Wróć"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(260, 300)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialog.add_child(scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(box)
	app.add_child(dialog)
	dialog.visibility_changed.connect(func():
		if not dialog.visible: dialog.queue_free())
	app._position_dialog(dialog, Vector2i(300, 420))
	return {"dialog": dialog, "box": box}

static func bond(app: GameUI) -> void:
	var ui := panel(app, "Nasza więź")
	ui.box.add_child(app._label(BondLevels.summary(app.session.pet), 18, app.INK, true))
	var rewards := ["Poznawanie pieska i wszystkie dotychczasowe zabawy", "Poduszka przyjaźni do pokoju", "Girlanda łapek do pokoju", "Spokojna chwila razem", "Tytuł: Nierozłączni"]
	for i in BondLevels.THRESHOLDS.size():
		var label := app._label("%s %d · %s\n%s" % ["✓" if app.session.pet.bond >= BondLevels.THRESHOLDS[i] else "○", BondLevels.THRESHOLDS[i], BondLevels.NAMES[i], rewards[i]], 14, app.MUTED)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui.box.add_child(label)
	var ritual := app._button("Spokojna chwila", func():
		if BondLevels.ritual(app.session):
			ui.dialog.hide()
			bond(app))
	ritual.disabled = app.session.pet.bond < 75 or app.session.busy(false) or app.session.is_sleeping() or PersonalitySystem.day_of(app.session._local_now()) <= int(app.session.pet.exploration.ritual_day)
	ui.box.add_child(ritual)
	ui.box.add_child(app._button("Dekoracje", func():
		ui.dialog.hide()
		app._show_decor()))
	ui.dialog.popup()

static func collection(app: GameUI) -> void:
	var ui := panel(app, "Odkopane skarby")
	var state := app.session.pet.exploration
	ui.box.add_child(app._label("Kolekcja %d/12 · wymiany: %d" % [state.items.size(), int(state.tokens)], 14, app.MUTED))
	var hint := app._label("Trzy duplikaty pozwalają wybrać brakujący skarb. Szukajcie wtedy, gdy macie ochotę.", 13, app.MUTED)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.box.add_child(hint)
	for id in DiggingSystem.ITEMS:
		var item: Array = DiggingSystem.ITEMS[id]
		var rarity: String = "pospolity" if item[1] == 6 else ("niezwykły" if item[1] == 3 else "rzadki")
		var count := int(state.items.get(id, 0))
		var label := app._label("%s · %s%s" % [item[0], rarity, " · ×%d" % count if count > 0 else " · brak"], 14, app.INK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui.box.add_child(label)
		if count == 0:
			var button := app._button("Wymień 3 duplikaty", func():
				if DiggingSystem.exchange(app.session, id):
					ui.dialog.hide()
					collection(app))
			button.disabled = state.tokens < 3 or not app.session.writable
			ui.box.add_child(button)
	ui.dialog.popup()
