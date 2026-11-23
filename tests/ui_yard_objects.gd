extends SceneTree

var app: GameUI
var failed := 0

func _initialize() -> void:
	create_timer(30).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
	else: print("PASS YARD OBJECTS " + label)

func tick() -> void:
	app.room.animator._process(0.1)
	app.room._process(0.1)
	app.session._process(0.1)
	app._process(0.1)

func shot(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/yuf-yard-objects-" + name + ".png")

func run() -> void:
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = "/tmp/yuf-yard-objects-%s/pet.json" % Time.get_ticks_usec()
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	var game := app.session
	game.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	game.weather.override_kind = "sun"
	game.set_process(false)
	game._brain_left = INF
	app.room.set_process(false)
	app.room.animator.set_process(false)
	await process_frame
	app._toggle_yard(false)
	app.bubble_left = 0
	app.bubble.hide()
	check(app.room.yard_nodes.size() == 12 and app.room.yard_nodes.values().all(func(n): return n.visible), "twelve separate station nodes render")
	check(app.room.yard_nodes.values().all(func(n): return n.sprite is Sprite2D and n.sprite.texture != null and n.highlight.material is ShaderMaterial), "every interactive station has a transparent sprite and its own glow")
	check(app.room.yard_nodes.garden.art != null and app.room.yard_nodes.garden.art.yard_overlay_only, "growing plants remain a separate live overlay")
	var gate_sprite: Texture2D = app.room.yard_nodes.gate.sprite.texture
	app.room.yard_nodes.gate.set_gate_open(true)
	check(app.room.yard_nodes.gate.sprite.texture != gate_sprite, "gate swaps to its open sprite")
	app.room.yard_nodes.gate.set_gate_open(false)
	var dry_sprite: Texture2D = app.room.yard_nodes.puddle.sprite.texture
	app.room.yard_nodes.puddle.set_puddle_wet(true)
	check(app.room.yard_nodes.puddle.sprite.texture != dry_sprite, "puddle swaps to its wet sprite")
	app.room.yard_nodes.puddle.set_puddle_wet(false)
	check(app.room.yard_markers.values().all(func(m): return not m.visible), "permanent name cards are hidden while walking")
	check(not app.yard_toolbar.visible, "permanent home bush and bath buttons are hidden outdoors")
	for id in RoomLayout.YARD_STATIONS:
		app.room.look_at_world(RoomLayout.YARD_STATIONS[id].visual)
		var station_touch := app.room.world_to_screen(RoomLayout.YARD_STATIONS[id].visual)
		check(app.room.yard_station_at(station_touch) == id, "visible artwork selects " + id)
	app.room.look_at_world(RoomLayout.YARD_STATIONS.bush_1.visual)
	await shot("before")
	var touch := app.room.world_to_screen(RoomLayout.YARD_STATIONS.bush_1.visual)
	check(app.room.yard_station_at(touch) == "bush_1", "bush artwork is touchable at its own location")
	var press := InputEventScreenTouch.new()
	press.position = touch
	press.index = 0
	press.pressed = true
	root.push_input(press, true)
	var release := press.duplicate()
	release.pressed = false
	root.push_input(release, true)
	await process_frame
	check(app.pending_yard_station == "bush_1" and game.activity == "walk" and not app.yard_action_bubble.visible, "tap starts approach without early action card")
	for i in 200:
		tick()
		if app.yard_action_bubble.visible: break
	check(app.yard_action_bubble.visible and app.yard_action_title.text == "Krzak 2" and app.yard_action_button.text == "Szukaj" and app.yard_action_secondary.text == "Chowanka", "arrival reveals object name and available actions")
	for i in 50: tick()
	check(app.yard_action_bubble.visible, "action card stays available while the player reads it")
	await shot("arrived")
	root.size = Vector2i(320, 640)
	root.content_scale_size = root.size
	await process_frame
	app._fit_room()
	app._position_yard_station()
	check(app.yard_action_bubble.visible and app.yard_action_bubble.modulate.a > 0 and not app.sheet.visible and app.yard_action_bubble.get_rect().end.y < app.navigation.position.y, "action card replaces care controls on a narrow phone")
	await shot("narrow")
	app.yard_action_button.pressed.emit()
	check(game.activity == "sniff_walk" and game.sniff_spot == 1 and not app.yard_action_bubble.visible, "action button starts the original search mechanic")
	app.queue_free()
	await process_frame
	print("YARD OBJECT FAILURES: ", failed)
	quit(1 if failed else 0)
