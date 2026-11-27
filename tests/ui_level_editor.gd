extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else: failed += 1; push_error(label)
func _initialize() -> void:
	create_timer(40).timeout.connect(func(): quit(1))
	call_deferred("run")
func run() -> void:
	root.size = Vector2i(1200, 720)
	root.content_scale_size = root.size
	var result := LevelProject.read_project("res://level-editor/projects/ver1.json")
	var data: Dictionary = result.project
	# Add scripted fixtures to the current version without changing the saved project.
	for element in data.levels[0].elements:
		if element.script == "ball":
			element.id = "ball"
			element.x = 890
			element.y = 497
		elif element.script == "portal": element.id = "door"
	data.levels[0].elements.append({"id": "food", "name": "Miska", "asset": "food", "layer": "middle",
		"x": 485, "y": 505, "width": 60, "height": 36, "pivot": {"x": 10, "y": 10},
		"visible": true, "locked": false, "static": true, "script": "feed",
		"params": {"fullness": 22, "message": "Mniam!", "clip": "eat_loop"}})
	data.levels[0].elements.append({"id": "toys", "name": "Kosz", "asset": "toys", "layer": "middle",
		"x": 1090, "y": 496, "width": 102, "height": 78, "pivot": {"x": 17, "y": 25},
		"visible": true, "locked": false, "static": true, "script": "message",
		"params": {"text": "W koszu czekają zabawki.", "duration": 4}})
	var before := data.duplicate(true)
	var preview := LevelPreview.new()
	check(preview.open_project(data), "project opens with all textures")
	root.add_child(preview)
	await process_frame
	preview.set_process(false)
	check(preview.current.id == "home" and preview.world.middle_ground.y_sort_enabled, "home opens with common depth sorting")
	check(preview.nodes.ball.get_parent() == preview.world.middle_ground, "ball joins middle ground")
	var ball: Dictionary = data.levels[0].elements.filter(func(e): return e.id == "ball")[0]
	var ball_asset: Dictionary = data.assets.filter(func(a): return a.id == ball.asset)[0]
	var ball_center: Vector2 = LevelProject.element_rect(ball, ball_asset).get_center()
	check(preview.hit(ball_center).get("id", "") == "ball", "interactive ball is hit at authored position")
	preview.throw_ball("ball", Vector2(1120, 500))
	for i in 200: preview._process(.1)
	check(preview.flight.is_empty() and preview.dog_position.distance_to(Vector2(1120, 500)) < 1, "dog completes throw at its authored destination")
	var play: float = preview.test_pet.needs.play
	for i in 20: preview._process(.1)
	check(preview.test_pet.needs.play == play, "completed throw rewards only once")
	preview.test_pet.needs.fullness = 40
	var food: Dictionary
	for e in data.levels[0].elements:
		if e.id == "food": food = e
	preview.activate(food, Vector2.ZERO)
	for i in 150: preview._process(.1)
	check(preview.test_pet.needs.fullness == 62, "feeding uses authored script params after arrival")
	var door: Dictionary
	for e in data.levels[0].elements:
		if e.id == "door": door = e
	preview.activate(door, Vector2.ZERO)
	check(preview.current.id == "yard" and preview.nodes.has("bush_2"), "portal loads authored yard")
	var gate: Dictionary = data.levels[1].elements.filter(func(e): return e.id == "gate")[0]
	preview.activate(gate, Vector2.ZERO)
	check(preview.current.id == "home", "return portal restores home")
	# Message script shows speech.
	var toys: Dictionary
	for e in data.levels[0].elements:
		if e.id == "toys": toys = e
	preview.activate(toys, Vector2.ZERO)
	check(preview.message_left > 0 and preview.message_label.text.find("kosz") >= 0, "message script shows speech bubble")
	# Thought script (synthesised).
	var thought_element := {
		"id": "thought_test", "name": "Myśli", "asset": "food", "layer": "middle",
		"x": 500, "y": 320, "width": 60, "height": 36, "pivot": {"x": 10, "y": 10},
		"visible": true, "locked": false, "static": true,
		"script": "thought", "params": {"text": "Jestem szczęśliwy!", "duration": 4, "from_dog": true}
	}
	preview.activate(thought_element, Vector2.ZERO)
	check(preview.thought_left > 0 and preview.thought_label.text == "Jestem szczęśliwy!", "thought script renders pet thought")
	check(data == before, "playing never mutates project data")
	preview.throw_ball("ball", Vector2(1200, 300))
	preview.show_level("yard")
	check(preview.flight.is_empty() and preview.pending.is_empty() and not preview.target.is_finite(), "level change cancels old activity")
	await process_frame
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		var vp_tex := root.get_texture()
		if vp_tex:
			var img := vp_tex.get_image()
			if img: img.save_png("/tmp/yuf-level-editor-preview.png")
	preview.queue_free()
	await process_frame
	print("LEVEL EDITOR UI: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
