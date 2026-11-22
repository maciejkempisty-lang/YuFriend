extends SceneTree
# Yard places are touched in the scene; labelled buttons exist only on the
# whole-yard map, and untried places carry a quiet twinkle instead of a badge.
var app: Control
var failed := 0
var requested: Array[String] = []

func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, text: String) -> void:
	if not ok:
		failed += 1
		push_error(text)
	else: print("PASS YARD PLACES " + text)

func shot(name: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	root.get_texture().get_image().save_png("/tmp/yuf-yard-places-" + name + ".png")

func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	var data_dir := preload("res://tests/helper_paths.gd").data_root() + "/yuf-yard-places-%s" % Time.get_ticks_usec()
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = data_dir + "/pet.json"
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	await process_frame
	var room = app.room
	room.care_requested.connect(func(action: String): requested.append(action))
	# Scene focus: the session rules for entering the yard have their own suites,
	# so the session is placed outside directly and the view follows it.
	app.session.in_yard = true
	room.set_yard(true)
	room.update_placement()
	room._sync_layers()
	await process_frame

	await shot("normal")
	check(room.yard_markers.values().all(func(m): return not m.visible), "no label badges in the normal yard view")
	check(room.yard_markers.values().all(func(m): return m.tooltip_text.is_empty()), "yard places have no hover tooltips")
	var shown: Array = room.yard_sparkles.keys().filter(func(id): return room.yard_sparkles[id].visible)
	check(not shown.is_empty(), "untried places on screen twinkle")
	check(shown.all(func(id): return room.yard_sparkles[id].mouse_filter == Control.MOUSE_FILTER_IGNORE), "twinkles never take touches")

	# Touch the object itself: the bush on screen, not a button above it.
	var bush := ""
	for id in ["bush_0", "bush_1", "bush_2"]:
		var rect: Rect2 = room._screen_rect(RoomLayout.YARD_STATIONS[id].bounds)
		if room.render_rect.has_point(rect.get_center()) and not room._hits_pet(room.screen_to_world(rect.get_center())):
			bush = id
			break
	if bush.is_empty():
		room.look_at_world(RoomLayout.YARD_STATIONS.bush_1.bounds.get_center())
		room._sync_layers()
		bush = "bush_1"
	var point: Vector2 = room._screen_rect(RoomLayout.YARD_STATIONS[bush].bounds).get_center()
	check(room.yard_place_at(point) == bush, "bush is found under the finger")
	check(room.action_at(point) == "yard_" + bush, "touching the bush maps to its place action")
	room._interact(point)
	check(requested.has("yard_" + bush), "touching the bush requests the same action as its old badge")
	check(room.yard_seen.has(bush) and not room.yard_sparkles[bush].visible, "twinkle disappears after the first use")
	var config := ConfigFile.new()
	check(config.load(data_dir + "/ui.cfg") == OK and config.get_value("yard_seen", bush, false) == true, "tried place is remembered in ui.cfg")

	# Small props keep a finger-sized target.
	var sign_rect: Rect2 = room._screen_rect(RoomLayout.YARD_STATIONS.course.bounds)
	room.look_at_world(RoomLayout.YARD_STATIONS.course.bounds.get_center())
	room._sync_layers()
	sign_rect = room._screen_rect(RoomLayout.YARD_STATIONS.course.bounds)
	check(room.yard_place_at(sign_rect.get_center()) == "course", "course sign is touchable")
	check(room.yard_place_at(sign_rect.get_center() + Vector2(0, sign_rect.size.y / 2 + 6)) in ["course", ""], "sign target grows only to a finger size")

	# The whole-yard map keeps labelled, separate buttons and no twinkles.
	room.show_overview()
	room.update_placement()
	room._sync_layers()
	await process_frame
	await shot("overview")
	check(room.yard_markers.values().all(func(m): return m.visible), "overview shows all twelve places as a map")
	check(room.yard_sparkles.values().all(func(s): return not s.visible), "no twinkles on the overview map")
	check(room.yard_place_at(sign_rect.get_center()).is_empty(), "overview taps zoom instead of acting on a place")
	var markers: Array = room.yard_markers.values()
	var overlap := false
	for a in markers:
		for b in markers:
			if a != b and a.get_global_rect().intersects(b.get_global_rect()): overlap = true
	check(not overlap, "map buttons do not overlap")

	# A fresh start restores what was already tried.
	app.queue_free()
	await process_frame
	var again = load("res://scenes/Main.tscn").instantiate()
	again.save_path_override = data_dir + "/pet.json"
	again.room.ambient_life.life.autoplay = false
	root.add_child(again)
	await process_frame
	check(again.room.yard_seen.has(bush), "tried places survive a restart")
	again.queue_free()
	await process_frame

	print("YARD PLACES FAILURES: %d" % failed)
	quit(1 if failed > 0 else 0)
