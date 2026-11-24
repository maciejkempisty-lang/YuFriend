class_name YardActionMenu
extends VBoxContainer

# Context choices reuse existing actions. Opening this panel does not start
# movement, grant rewards, or change the autonomous behaviour timer.
var app: GameUI
var station_id := ""
var title: Label
var back: Button
var primary: Button
var secondary: Button

func setup(owner_app: GameUI) -> void:
	app = owner_app
	add_theme_constant_override("separation", 5)
	var heading := HBoxContainer.new()
	heading.add_theme_constant_override("separation", 8)
	add_child(heading)
	title = app._label("", 16, app.INK, true)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	heading.add_child(title)
	back = app._button("Wróć", close)
	back.size_flags_horizontal = Control.SIZE_SHRINK_END
	back.accessibility_name = "Zamknij wybór czynności"
	heading.add_child(back)
	var choices := HBoxContainer.new()
	choices.add_theme_constant_override("separation", 6)
	add_child(choices)
	primary = app._button("", _activate.bind(false), true)
	secondary = app._button("", _activate.bind(true))
	choices.add_child(primary)
	choices.add_child(secondary)
	hide()

func _available(id: String) -> bool:
	var s := app.session
	if not s.active or not s.in_yard or not s.writable or s.suspended or s.is_sleeping(): return false
	if not app.app_foreground or app.selected_tab != "care" or app.room.overview or app._dialog_open(): return false
	if s.busy() or not s.invitation.is_empty() or YardRoutines.has_mess(s): return false
	if id.begins_with("bush_"): return RoomLayout.YARD_STATIONS.has(id)
	if id in ["puddle", "sprinkler"]: return true
	return id == "fetch" and not s.outdoor_commands.available_key(s).is_empty()

func offer(id: String) -> bool:
	if not _available(id): return false
	station_id = id
	title.text = RoomLayout.YARD_STATIONS[id].label
	if id.begins_with("bush_"):
		primary.text = "Szukaj"
		secondary.text = "Chowanka"
	elif id in ["puddle", "sprinkler"]:
		primary.text = "Pluskaj" if id == "puddle" else "Zraszaj"
		secondary.text = "Kąpiel"
	else:
		primary.text = "Rzuć piłkę"
		secondary.text = TrainingSystem.LABELS[app.session.outdoor_commands.available_key(app.session)]
	for button in [primary, secondary]:
		button.accessibility_name = title.text + ". " + button.text
	app.session.player_activity()
	show()
	app._sync_yard_actions()
	app._update_attention()
	return true

func sync() -> void:
	if visible and not _available(station_id): close()

func close() -> void:
	if not visible: return
	station_id = ""
	hide()
	app._sync_yard_actions()
	app._update_attention()

func _activate(use_secondary: bool) -> void:
	if not visible: return
	var id := station_id
	var accepted := _available(id)
	close()
	if not accepted: return
	if not use_secondary: app._room_care_action("yard_" + id)
	elif id.begins_with("bush_"): app._show_yard_games()
	elif id in ["puddle", "sprinkler"]: app._show_bath()
	elif id == "fetch": OutdoorPanels.command(app)

func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
