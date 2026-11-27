class_name LevelRoom
extends Control
## Game shell that drives YuFriend from a LevelProject on disk. Boots a
## GameSession (loads the real save), renders the world via LevelPreview,
## and forwards script interactions to session.act(). Yard-specific
## features (bath, invite, visitor, cuddle, hide, fetch, timed course, drink)
## have NOT been ported yet — they stay in scripts/ui/main.gd (Main.tscn).
## When a project script fires here that session.act() cannot handle, we log
## it to room_state so follow-up work can wire the matching system.

signal unhandled_script(script_id: String, element_id: String)

@export var project_path: String = "res://level-editor/projects/starter.json"
@export var save_path: String = "user://pet.json"

var session := GameSession.new()
var preview := LevelPreview.new()
var hud := VBoxContainer.new()
var top_row := HBoxContainer.new()
var name_label := Label.new()
var wellbeing_label := Label.new()
var tabs := HBoxContainer.new()
var needs_row := HBoxContainer.new()
var needs_bars: Dictionary = {}
var status_label := Label.new()
var unhandled: PackedStringArray = []
var music := BackgroundMusic.new()
var effects := SoundEffects.new()
var haptics := HapticFeedback.new()
var settings_bar := HBoxContainer.new()
var bath_finish := Button.new()
var fade := ColorRect.new()
var naming_dialog: AcceptDialog
var naming_input: LineEdit
var naming_error: Label
var naming_pending := false
const _NEEDS := ["fullness", "energy", "hygiene", "contact", "play"]
const _NEED_NAMES := {"fullness":"Sytość","energy":"Energia","hygiene":"Higiena","contact":"Kontakt","play":"Zabawa"}
const _NEED_COLORS := {"fullness":"#d9a86c","energy":"#b2c58d","hygiene":"#9ec5d9","contact":"#e2a1b8","play":"#ccdf9c"}

const _CARE := {
	"feed": "feed", "pet": "pet", "clean": "clean", "rest": "rest", "ball": "play",
	"greet": "pet"
}
# Scripts that start a self-contained GameSession subsystem (no act() shortcut).
const _SPECIAL := ["bath", "cuddle", "drink", "sniff"]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = (preload("res://scripts/ui/game_theme.gd") as GDScript).call("build")
	add_child(session)
	add_child(music); music.start("user://music.cfg")
	add_child(effects); effects.start("user://effects.cfg")
	haptics.start("user://haptics.cfg")
	session.sound_requested.connect(func(id: String): effects.play_effect(id))
	session.away_report_ready.connect(_show_away_report)
	session.start(save_path)
	add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.bind_pet(session.pet)
	var result := LevelProject.read_project(project_path)
	if not result.ok:
		_fatal("Projekt poziomów nie ładuje się: " + ", ".join(result.errors))
		return
	if not preview.open_project(result.project):
		_fatal("Nie udało się załadować grafik projektu.")
		return
	fade.color = Color(0.09, 0.14, 0.11, 0)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fade)
	preview.interaction_requested.connect(_on_interaction)
	preview.level_changed.connect(_on_level_changed)
	session.changed.connect(_refresh)
	session.feedback.connect(_say_feedback)
	# Session's subsystems (bath, cuddle, course, hide, …) steer the puppy by
	# emitting clip/destination signals. Route them into the preview so the
	# visible world matches session state.
	session.clip_requested.connect(func(c): preview.animator.request_clip(c))
	session.destination_requested.connect(func(p: Vector2): preview.target = preview.clamp_walk(p))
	session.activity_cancelled.connect(func(): preview.target = Vector2.INF; preview.pending.clear())
	session.save_status.connect(func(_ok): _refresh())
	_build_hud()
	_rebuild_tabs()
	_refresh()
	if session.newly_created and session.pet != null: _open_naming_dialog()

func _build_hud() -> void:
	hud.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	hud.offset_left = 16; hud.offset_right = -16; hud.offset_top = 10; hud.offset_bottom = 110
	hud.add_theme_constant_override("separation", 6)
	add_child(hud)

	top_row.add_theme_constant_override("separation", 14)
	hud.add_child(top_row)
	_style_label(name_label, 20, true)
	top_row.add_child(name_label)
	_style_label(wellbeing_label, 14, false)
	top_row.add_child(wellbeing_label)
	top_row.add_child(tabs)
	tabs.add_theme_constant_override("separation", 6)

	needs_row.add_theme_constant_override("separation", 10)
	hud.add_child(needs_row)
	for key in _NEEDS:
		var column := VBoxContainer.new()
		column.custom_minimum_size = Vector2(130, 0)
		var lbl := Label.new()
		lbl.text = _NEED_NAMES[key]
		_style_label(lbl, 12, false)
		var bar := ProgressBar.new()
		bar.min_value = 0; bar.max_value = 100
		bar.custom_minimum_size = Vector2(0, 14)
		bar.show_percentage = true
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(_NEED_COLORS[key])
		sb.corner_radius_top_left = 4; sb.corner_radius_top_right = 4
		sb.corner_radius_bottom_left = 4; sb.corner_radius_bottom_right = 4
		bar.add_theme_stylebox_override("fill", sb)
		column.add_child(lbl); column.add_child(bar)
		needs_row.add_child(column)
		needs_bars[key] = bar

	_style_label(status_label, 14, false)
	hud.add_child(status_label)

	settings_bar.add_theme_constant_override("separation", 10)
	hud.add_child(settings_bar)
	_make_toggle("🎵 Muzyka", music.enabled, func(v): music.set_enabled(v))
	_make_toggle("🔊 Dźwięki", effects.enabled, func(v): effects.set_enabled(v))
	_make_toggle("📳 Wibracje", haptics.enabled, func(v): haptics.set_enabled(v))

	bath_finish.text = "🛁 Zakończ kąpiel"
	bath_finish.visible = false
	bath_finish.pressed.connect(func(): session.finish_bath())
	settings_bar.add_child(bath_finish)

func _make_toggle(label: String, initial: bool, change: Callable) -> void:
	var b := CheckBox.new()
	b.text = label
	b.button_pressed = initial
	b.toggled.connect(change)
	settings_bar.add_child(b)

func _style_label(label: Label, size: int, bold: bool) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("edf6d8"))
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color("18251e"))
	if bold: label.add_theme_constant_override("line_spacing", 0)

func _rebuild_tabs() -> void:
	for child in tabs.get_children(): child.queue_free()
	if preview.project.is_empty(): return
	for level_data in preview.project.levels:
		var b := Button.new()
		b.text = level_data.name
		b.toggle_mode = true
		b.button_pressed = (preview.current.get("id", "") == level_data.id)
		var level_id: String = level_data.id
		b.pressed.connect(func(): preview.show_level(level_id); _rebuild_tabs())
		tabs.add_child(b)

func _refresh() -> void:
	if session.pet == null: return
	var p := session.pet
	name_label.text = p.pet_name if p.pet_name != "" else "Pies"
	wellbeing_label.text = "💝 %s" % session.wellbeing.label()
	for key in _NEEDS:
		if needs_bars.has(key): needs_bars[key].value = float(p.needs[key])
	status_label.text = session.last_message
	bath_finish.visible = session.in_bath
	if not tabs.get_children().size(): _rebuild_tabs()

func _on_interaction(element_id: String, script_id: String, props: Dictionary) -> void:
	# portal/message/thought/bark/greet/play_clip/walk_to are visual — LevelPreview
	# handles them. Care scripts route through session.act; "specials" start their
	# own subsystem (bath, cuddle, drink, sniff). LevelPreview still animates the
	# walk to the target in parallel.
	var action: String = _CARE.get(script_id, "")
	if not action.is_empty():
		session.act(action, true)
		return
	var params: Dictionary = props.get("params", {})
	match script_id:
		"bath": session.start_bath()
		"cuddle": session.start_cuddle()
		"drink": session.home_drink.start(session)
		"sniff": session.start_sniff(int(params.get("spot", -1)))
		"course": session.course.start(session)
		"timed_course": session.timed_course.start(session)
		"water":
			var spot: String = str(params.get("spot", "puddle"))
			session.water.start(session, spot)
		"hide":
			var kind: String = str(params.get("kind", "bush"))
			var seed_value: int = int(params.get("seed", 0))
			session.start_hide(kind, seed_value)
		"visitor":
			var guest: String = str(params.get("guest", "bird"))
			session.visitors.start(session, guest)
		"none", "portal", "message", "thought", "walk_to", "play_clip", "bark": pass
		_:
			unhandled.append(script_id + "@" + element_id)
			unhandled_script.emit(script_id, element_id)

func _on_level_changed(level_id: String) -> void:
	# Convention: level id "yard" (or any id containing "yard") means outdoor mode.
	session.in_yard = "yard" in level_id
	_rebuild_tabs()
	_play_fade()

func _play_fade() -> void:
	fade.color.a = 0.65
	var tween := create_tween()
	tween.tween_property(fade, "color:a", 0.0, 0.45)

func _open_naming_dialog() -> void:
	naming_pending = true
	naming_dialog = AcceptDialog.new()
	naming_dialog.title = "Pierwsze spotkanie"
	naming_dialog.exclusive = true
	naming_dialog.dialog_close_on_escape = false
	naming_dialog.dialog_hide_on_ok = false
	naming_dialog.get_ok_button().text = "Poznajmy się"
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	box.custom_minimum_size.x = 260
	var greeting := Label.new()
	greeting.text = "Mały przyjaciel czeka na Ciebie. Jak ma na imię?"
	greeting.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(greeting)
	naming_input = LineEdit.new()
	naming_input.placeholder_text = "Imię pieska"
	naming_input.max_length = 24
	naming_input.custom_minimum_size = Vector2(240, 44)
	box.add_child(naming_input)
	naming_error = Label.new()
	naming_error.text = "Imię możesz później zmienić w ustawieniach."
	naming_error.add_theme_color_override("font_color", Color("a5b4a4"))
	naming_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(naming_error)
	naming_dialog.add_child(box)
	add_child(naming_dialog)
	naming_dialog.confirmed.connect(_finish_naming)
	naming_input.text_submitted.connect(func(_t): _finish_naming())
	naming_dialog.popup_centered(Vector2i(320, 240))
	naming_input.grab_focus()

func _show_away_report() -> void:
	if session.pet == null: return
	var report: Variant = session.pet.get("life")
	if report == null: return
	var text: String = str(session.pet.life.get("away_report", {}).get("summary", session.last_message))
	if text.is_empty(): return
	var dialog := AcceptDialog.new()
	dialog.title = "Co się działo"
	dialog.dialog_text = text
	add_child(dialog)
	dialog.popup_centered(Vector2i(400, 200))
	dialog.confirmed.connect(dialog.queue_free)
	dialog.canceled.connect(dialog.queue_free)

func _finish_naming() -> void:
	var value := naming_input.text.strip_edges()
	if value.is_empty():
		naming_error.text = "Wpisz imię, żebyśmy mogli się poznać."
		return
	var previous := session.pet.pet_name
	if not session.rename_pet(value) or not session.save_ok:
		session.pet.pet_name = previous
		naming_error.text = "Nie udało się zapisać imienia. Spróbuj ponownie."
		return
	naming_pending = false
	naming_dialog.hide()
	naming_dialog.queue_free()
	naming_dialog = null
	session.say("Dobrze, że jesteś. Dotknij pieska, żeby się przywitać.")
	_refresh()

func _say_feedback(text: String) -> void:
	if text.is_empty(): return
	status_label.text = text

func _fatal(message: String) -> void:
	status_label.text = message
	push_error(message)
