class_name AdventurePanel
extends RefCounted

static func show_plan(app: GameUI) -> void:
	var ui := ProgressionPanels.panel(app, "Mała przygoda dnia")
	var title := app._label("", 18, app.INK, true)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.box.add_child(title)
	var intro := app._label("Dwa małe pomysły, jeśli masz ochotę. Zaliczą się podczas zwykłej gry. Pominięcie dnia niczego nie odbiera.", 13, app.MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.box.add_child(intro)
	var labels: Array[Label] = []
	var buttons: Array[Button] = []
	for i in 2:
		var label := app._label("", 14, app.INK)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ui.box.add_child(label)
		labels.append(label)
		var button := app._button("", func():
			var state := DailyAdventure.view(app.session.pet, app.session._local_now())
			var task: String = DailyAdventure.PLANS[int(state.day) % 3][i]
			ui.dialog.hide()
			app._select_tab("training" if task == "trick" else "care")
			if task != "trick" and not app.session.in_yard: app._toggle_yard())
		ui.box.add_child(button)
		buttons.append(button)
	var reward := app._label("", 13, app.MUTED)
	reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.box.add_child(reward)
	var refresh := func():
		var state := DailyAdventure.view(app.session.pet, app.session._local_now())
		var index := int(state.day) % 3
		title.text = DailyAdventure.TITLES[index]
		for i in 2:
			var task: String = DailyAdventure.PLANS[index][i]
			labels[i].text = "%s %s\n%s" % ["✓" if task in state.done else "○", DailyAdventure.TASKS[task], DailyAdventure.HINTS[task]]
			buttons[i].text = "Do treningu" if task == "trick" else "Na podwórko"
		reward.text = "Pamiątka jest w Albumie. Możecie odpocząć!" if state.rewarded else "Nagroda: pamiątka „%s”. Bez dodatkowej więzi i serii dni." % DailyAdventure.TITLES[index]
		if PersonalitySystem.day_of(app.session._local_now()) < int(state.day): reward.text = "Pokazujemy ostatni zapisany plan. Nowa przygoda pojawi się, gdy data go wyprzedzi."
		for n in 3:
			reward.text += "\n%s %s" % ["✓" if app.session.pet.milestones.has("adventure_%d" % n) else "○", DailyAdventure.TITLES[n]]
	var timer := Timer.new()
	timer.wait_time = 1
	ui.dialog.add_child(timer)
	timer.timeout.connect(refresh)
	timer.start()
	refresh.call()
	ui.dialog.popup()
