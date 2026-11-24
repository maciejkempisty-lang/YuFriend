extends SceneTree
# Exercise actual scene/button touches while contextual choices are open.
# Existing activity suites cover the complete rounds; this guards routing and
# interruption at the boundary between the menu and those same activities.
var app: GameUI
var passed := 0
var failed := 0

func _initialize() -> void:
	create_timer(110).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func settle() -> void:
	await process_frame
	app.app_foreground = true
	app._process(0)
	app._fit_room()
	app.room._sync_layers()
	await process_frame
	await process_frame

func fresh(width: int) -> void:
	if is_instance_valid(app):
		app.music.stop()
		app.effects.stop_all()
		app.queue_free()
		await process_frame
	root.size = Vector2i(width, 640 if width == 320 else 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-menu-actions-%s/pet.json" % Time.get_ticks_usec()
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	app.set_process(false)
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	app.session.visitors.wait_left = INF
	app.session._brain_left = INF
	app.session._initiative_wait = INF
	app.session.pet.needs.energy = 95
	app.session.pet.needs.fullness = 95
	app.session.pet.needs.hygiene = 40
	app.session.pet.fatigue = 0
	for key in ["sit", "stay", "come"]: app.session.pet.skills[key].mastery = 100
	app.session.weather.override_kind = "after_rain"
	app._toggle_yard(false)
	await settle()

func tap(point: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = point
	press.pressed = true
	root.push_input(press, true)
	await process_frame
	var release := press.duplicate()
	release.pressed = false
	root.push_input(release, true)
	await settle()

func button(control: Button, label: String) -> void:
	check(control.is_visible_in_tree() and not control.disabled, label + " visible and enabled")
	check(app.safe_rect.encloses(control.get_global_rect()) and control.size.y >= 44, label + " fits touch area")
	await tap(control.get_global_rect().get_center())

func station_point(id: String) -> Vector2:
	var rect: Rect2 = app.room._screen_rect(RoomLayout.YARD_STATIONS[id].bounds)
	for y in range(int(rect.position.y), int(rect.end.y), 3):
		for x in range(int(rect.position.x), int(rect.end.x), 3):
			var point := Vector2(x, y)
			if point.y > app.room.hud_bottom + 60 and point.y < app.sheet.position.y and app.room.action_at(point) == "yard_" + id:
				return point
	return Vector2.INF

func dialog(title: String) -> AcceptDialog:
	for child in app.get_children():
		if child is AcceptDialog and child.visible and child.title == title: return child
	return null

func menu_before_action() -> void:
	# Modal test windows may deliver a late focus-out from the previous fixture.
	# These synthetic touches model the new window in the foreground.
	app.app_foreground = true
	check(app.yard_menu.offer("bush_1"), "menu opens before another action")
	await settle()

func run() -> void:
	for width in [320, 390]:
		# Switch from an open menu to all twelve original interactive places.
		for id in RoomLayout.YARD_STATIONS:
			await fresh(width)
			app.room.look_at_world(RoomLayout.YARD_STATIONS[id].bounds.get_center())
			await menu_before_action()
			var point := station_point(id)
			check(point.is_finite(), "scene target exists: %s %d" % [id, width])
			if not point.is_finite(): continue
			await tap(point)
			if id.begins_with("bush_") or id in ["puddle", "sprinkler"]:
				check(app.yard_menu.visible and app.yard_menu.station_id == id, "scene touch selects menu: " + id)
				await button(app.yard_menu.primary, id + " primary")
			check(not app.yard_menu.visible, "original action dismisses choices: " + id)
			match id:
				"gate": check(app.yard_transition.phase == "approach", "gate starts animated return")
				"shade": check(dialog("Chwila w cieniu") != null, "shade retains rest/drink choices")
				"course": check(app.session.course.active(), "course starts")
				"puddle", "sprinkler": check(app.session.water.kind == id, "water starts: " + id)
				"dig": check(app.session.activity == "dig_walk", "digging starts")
				"garden": check(dialog("Ogródek") != null, "garden retains planting/watering")
				"outing": check(app.session.activity == "outing_walk", "outing starts from sign")
				"fetch": check(app.session.last_message.begins_with("Przeciągnij piłkę"), "fetch retains drag instructions")
				_: check(app.session.activity == "sniff_walk" and app.session.sniff_spot == int(id.trim_prefix("bush_")), "search keeps selected bush")

		# Direct shortcuts must still work while the menu owns the care area.
		for kind in ["home", "outing", "bath", "hide", "command"]:
			await fresh(width)
			if kind == "hide": app.session.pet.yard_routines.outday = PersonalitySystem.day_of(app.session._local_now())
			if kind == "command": app.session.outdoor_commands.offer_recall(Vector2(700, 315))
			app._refresh()
			await menu_before_action()
			match kind:
				"home":
					await button(app.yard_button, "home shortcut")
					check(app.yard_transition.phase == "approach", "home shortcut starts return")
				"outing":
					await button(app.potty_action, "outing shortcut")
					check(app.session.activity == "outing_walk", "outing shortcut starts walking")
				"bath":
					await button(app.yard_bath_button, "bath shortcut")
					check(app.session.in_bath and app.bath_dialog.visible, "bath shortcut opens bathroom")
				"hide":
					await button(app.sniff_button, "hide shortcut")
					check(dialog("Zabawy w krzakach") != null, "hide shortcut opens three games")
				"command":
					await button(app.yard_command_button, "command shortcut")
					check(dialog("Przyjdź w zabawie") != null, "command shortcut opens training choices")
			check(not app.yard_menu.visible, "shortcut dismisses menu: " + kind)

		# A menu is not an input shield over the dog, ball or camera controls.
		await fresh(width)
		app.room.look_at_world(app.room.ball_world)
		await menu_before_action()
		var start := app.room.ball_center()
		var finish := start + Vector2(-100, -25)
		var press := InputEventScreenTouch.new()
		press.index = 0
		press.position = start
		press.pressed = true
		root.push_input(press, true)
		await process_frame
		var drag := InputEventScreenDrag.new()
		drag.index = 0
		drag.position = finish
		drag.relative = finish - start
		root.push_input(drag, true)
		await process_frame
		check(app.room.throw_guide.visible, "ball drag still previews while menu is open")
		press.position = finish
		press.pressed = false
		root.push_input(press, true)
		await settle()
		check(app.session.play.running() and not app.yard_menu.visible, "ball release starts fetch and frees its controls")
		await fresh(width)
		await menu_before_action()
		await button(app.room.overview_button, "whole-yard map")
		check(app.room.overview and not app.yard_menu.visible and app.room.yard_markers.values().all(func(m): return m.visible), "map remains available with all twelve targets")
		await fresh(width)
		await menu_before_action()
		await button(app.yard_menu.back, "back to care")
		check(app.care_actions.visible and app.session.attention_available, "back restores care and invitations")
		await button(app.care_buttons.rest, "outdoor nap")
		check(app.session.yard_rest.active(), "rest starts after closing menu")

		# New state must free the controls immediately, even when the UI synchronizes.
		for kind in ["water", "course", "rest", "visitor", "invitation", "cleanup", "hide"]:
			await fresh(width)
			await menu_before_action()
			match kind:
				"water":
					check(app.session.water.start(app.session, "puddle"), "water fixture starts")
					app.session.water.arrived(app.session)
					await settle()
					await button(app.water_splash_button, "splash")
					check(app.session.water.phase == "run", "splash remains usable")
					await button(app.water_shake_button, "shake")
					check(app.session.water.phase == "shake", "shake remains usable")
				"course":
					check(app.session.course.start(app.session), "course fixture starts")
					app.session.course.phase = "jump_ready"
					app.session.changed.emit()
					await settle()
					await button(app.course_action, "jump")
					check(app.session.course.phase == "jump", "jump remains usable")
					await button(app.course_stop, "stop course")
					check(not app.session.course.active(), "course can be stopped")
				"rest":
					check(app.session.yard_rest.start(app.session, "drink"), "rest fixture starts")
					await settle()
					await button(app.yard_rest_stop, "stop rest")
					check(not app.session.yard_rest.active(), "rest can be stopped")
				"visitor":
					app.session.visitors.begin_visit()
					check(app.session.visitors.start(app.session, "cat"), "visitor fixture starts")
					await settle()
					await button(app.visitor_soothe_button, "soothe visitor")
					check(app.session.visitors.phase == "soothe", "visitor response remains usable")
				"invitation":
					app.session.activity = "initiative"
					app.session.invitation = {"kind": "yard_puddle", "remaining": 30.0, "arrived": true}
					app.session.changed.emit()
					await settle()
					await button(app.yard_invite_accept, "accept invitation")
					check(app.session.water.kind == "puddle" and app.session.invitation.is_empty(), "invitation starts its activity")
				"cleanup":
					app.session.pet.yard_routines.mess = true
					app.session.changed.emit()
					await settle()
					await button(app.potty_action, "cleanup")
					check(not YardRoutines.has_mess(app.session), "cleanup remains usable")
				"hide":
					check(app.session.start_hide("treat", 42), "hide fixture starts")
					await settle()
					await button(app.room.yard_markers.bush_0, "hide target")
					check(app.session.activity == "hide_walk" and not app.room.overview, "hide selection bypasses contextual choices")
			check(not app.yard_menu.visible, "active state dismisses choices: " + kind)
	app.music.stop()
	app.effects.stop_all()
	app.queue_free()
	await process_frame
	await process_frame
	print("YARD MENU ACTIONS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
