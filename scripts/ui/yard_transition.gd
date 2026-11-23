class_name YardTransition
extends Control

var app: GameUI
var phase := ""
var destination := false
var elapsed := 0.0
var total := 0.0
var veil := ColorRect.new()
var status_panel := PanelContainer.new()
var caption := Label.new()
var cancel_button := Button.new()

func setup(owner_app: GameUI) -> void:
	app = owner_app
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 120
	mouse_filter = Control.MOUSE_FILTER_STOP
	veil.color = Color(0.12, 0.22, 0.17, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	status_panel.add_theme_stylebox_override("panel", app._style(app.CREAM, 18, 8))
	add_child(status_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	status_panel.add_child(row)
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_color_override("font_color", Color("24483d"))
	caption.add_theme_color_override("font_outline_color", Color("fff9ed"))
	caption.add_theme_constant_override("outline_size", 6)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(caption)
	cancel_button.text = "Anuluj"
	cancel_button.custom_minimum_size = Vector2(90, 44)
	cancel_button.pressed.connect(cancel)
	row.add_child(cancel_button)
	hide()

func start(outside: bool) -> bool:
	var s := app.session
	if not phase.is_empty() or outside == s.in_yard: return false
	if not s.writable or s.suspended or s.is_sleeping() or s.in_bath or s.training.phase != "idle": return false
	if outside and s.busy():
		s.say("Dokończmy najpierw tę czynność.")
		return false
	if outside and DailyRhythm.phase(s.pet, s._local_now()) == "night":
		s.say("Za ciemno, pora spać.")
		return false
	s.cancel_touch_game()
	s._cancel_motion()
	s.invitation.clear()
	s.portal_active = true
	s.activity = "portal"
	s.activity_left = 0
	app.bubble_left = 0
	app.gain_left = 0
	destination = outside
	phase = "approach"
	elapsed = 0
	total = 0
	caption.text = "Idziemy do drzwi…" if outside else "Wracamy przez furtkę…"
	cancel_button.show()
	show()
	app.room.focus_pet(false)
	var portal := Vector2(1230, 306) if outside else Vector2(150, 306)
	app.room.move_to(portal)
	app.room.portal_speed = 160
	app.room.animator.request_clip("run")
	s.changed.emit()
	return true

func _process(delta: float) -> void:
	if phase.is_empty() or app == null: return
	status_panel.position = Vector2(app.safe_rect.position.x + 12, app.safe_rect.end.y - 72)
	status_panel.size = Vector2(app.safe_rect.size.x - 24, 60)
	if app.session.suspended or not app.session.writable:
		cancel()
		return
	total += delta
	if total > 18:
		cancel()
		return
	match phase:
		"approach":
			if not app.room.moving:
				_open(true)
				phase = "fade_out"
				elapsed = 0
		"fade_out":
			elapsed += delta
			var amount := clampf(elapsed / 0.4, 0, 1)
			veil.color.a = amount
			app.room.puppy.modulate.a = 1 - amount
			if amount >= 1: _cross()
		"fade_in":
			elapsed += delta
			veil.color.a = 1 - clampf(elapsed / 0.4, 0, 1)
			if elapsed >= 0.4: phase = "arrival"
		"arrival":
			if not app.room.moving:
				cancel()
				app.session.say("Już na podwórku!" if destination else "Jesteśmy w domu.")
				app.bubble_left = 0
				app.bubble.hide()

func _cross() -> void:
	_open(false)
	app.session.portal_active = false
	# Recheck readiness, including the clock, at the moment of crossing.
	app.session.activity = "idle"
	if not app.session.change_yard(destination):
		cancel()
		return
	app.session.portal_active = true
	app.session.activity = "portal"
	app.room.pet_world = Vector2(150, 306) if destination else Vector2(1230, 306)
	app.room.target_world = app.room.pet_world
	app.room.puppy.modulate.a = 1
	app.room.focus_pet(false)
	app.room.update_placement()
	_open(true)
	app.room.move_to(Vector2(260, 315) if destination else Vector2(1190, 315))
	app.room.portal_speed = 70
	app.room.animator.request_clip("walk")
	caption.text = "Wychodzimy na podwórko…" if destination else "Wchodzimy do domu…"
	cancel_button.hide()
	elapsed = 0
	phase = "fade_in"

func _open(value: bool) -> void:
	app.room.yard_nodes.gate.set_gate_open(value)
	app.room.station_nodes.door.portal_open = value
	app.room.station_nodes.door.queue_redraw()

func cancel() -> void:
	if phase.is_empty(): return
	phase = ""
	app.session.portal_active = false
	app.session.activity = "idle"
	app.session.activity_left = 0
	app.room.portal_speed = 0
	app.room.puppy.modulate.a = 1
	app.room.cancel_activity()
	app.room.animator.request_clip("idle")
	_open(false)
	veil.color.a = 0
	hide()
	app.session.changed.emit()
