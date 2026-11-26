extends SceneTree
# Check real renderer ordering, plus integration geometry and scene transitions.
var passed := 0
var failed := 0
var app: GameUI

func _initialize() -> void:
	create_timer(45).timeout.connect(func(): quit(1))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)

func patch(parent: Node2D, color: Color, depth: float) -> Node2D:
	var item := Node2D.new()
	item.position.y = depth
	var ink := Polygon2D.new()
	ink.color = color
	ink.polygon = PackedVector2Array([Vector2(8, 8), Vector2(40, 8), Vector2(40, 40), Vector2(8, 40)])
	ink.position.y = -depth
	item.add_child(ink)
	parent.add_child(item)
	return item

func color_at(view: SubViewport, expected: Color, label: String) -> void:
	await process_frame
	RenderingServer.force_draw()
	check(view.get_texture().get_image().get_pixel(20, 20).is_equal_approx(expected), label)

func run() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(48, 48)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.world_2d = World2D.new()
	root.add_child(view)
	var layers := SceneLayers.new()
	view.add_child(layers)
	patch(layers.background, Color.BLUE, 999)
	var front := patch(layers.foreground, Color.YELLOW, -999)
	# Deliberately add the deeper item first: tree order must not win.
	var actor := patch(layers.middle_ground, Color.RED, 30)
	patch(layers.middle_ground, Color.GREEN, 20)
	await color_at(view, Color.YELLOW, "foreground stays above all Y positions")
	front.hide()
	await color_at(view, Color.RED, "larger foot Y draws in front of a prop")
	actor.position.y = 10
	actor.get_child(0).position.y = -10
	await color_at(view, Color.GREEN, "smaller foot Y draws behind the prop")
	layers.middle_ground.hide()
	await color_at(view, Color.BLUE, "background remains beneath the middle ground")
	view.queue_free()
	await process_frame

	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-layers-%s/pet.json" % Time.get_ticks_usec()
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	app.room.ambient_life.life.autoplay = false
	root.add_child(app)
	app.session.set_process(false)
	app.room.set_process(false)
	await process_frame
	var room := app.room
	var before := app.session.pet.to_dict().duplicate(true)
	check(room.world.get_child_count() == 3, "world contains exactly three primary layers")
	check(room.puppy.get_parent() == room.actors and room.station_nodes.toys.get_parent() == room.actors and room.station_nodes.food.get_parent() == room.actors, "home puppy and upright props share depth sorting")
	check(room.station_nodes.bed.get_parent() == room.world.background, "sleeping puppy stays above its bed")
	check(room.fence_visitor.get_parent() == room.actors and room.ambient_life.y_sort_enabled, "visitors and individual ambient animals participate in sorting")
	for outside in [true, false, true, false]:
		room.set_yard(outside)
		room._sync_layers()
		for id in room.yard_nodes:
			var station: YardStationView = room.yard_nodes[id]
			check(station.sprite.position + station.position == Vector2(YardSpriteLayout.CROPS[id].position), "unchanged world crop: " + id)
			check(station.visible == outside, "location visibility: " + id)
			if not YardSpriteLayout.GROUND_ONLY.has(id):
				check(station.get_parent() == room.actors and station.z_index == 0, "upright yard prop shares puppy depth: " + id)
		check(room.yard_nodes.garden.art.position + room.yard_nodes.garden.position == Vector2.ZERO, "growing plant keeps original world coordinates")
	room.yard_weather.kind = "rain"
	room.yard_weather.night = true
	room._sync_layers()
	check(room.yard_nodes.bush_0.weather_material.get_shader_parameter("weather_tint") == Color(0.23, 0.35, 0.39, 0.24), "middle props preserve rainy palette")
	check(room.yard_nodes.bush_0.weather_material.get_shader_parameter("night_tint") == Color(0.10, 0.16, 0.28, 0.42), "middle props preserve night palette")
	check(room.yard_nodes.shade.weather_key.is_empty(), "background props are not tinted twice")
	check(app.session.pet.to_dict() == before, "layer transitions do not change pet save")
	room.yard_course.playing = true
	check(room.yard_course.y_sort_enabled and room.yard_course.get_child_count() == 5, "course has separate obstacle bases")
	check(room.yard_course.get_children().all(func(n): return n.visible), "course activation reveals all parts")
	room.yard_course.playing = false
	check(room.yard_course.get_children().all(func(n): return not n.visible), "course completion hides all parts")
	app.queue_free()
	await process_frame
	print("SCENE LAYERS UI: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
