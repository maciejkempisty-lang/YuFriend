class_name LevelPreview
extends Control
## Opt-in playable project viewer. Never reads or writes the player's save.
signal interaction_requested(element_id: String, script_id: String, properties: Dictionary)
signal level_changed(level_id: String)

var project: Dictionary
var current: Dictionary
var assets := {}
var textures := {}
var nodes := {}
var world := SceneLayers.new()
var dog := Node2D.new()
var animator := PetAnimator.new()
var dog_position := Vector2.ZERO
var target := Vector2.INF
var pointer_ball := ""
var pointer_id := -1
var flight := {}
var pending := {}
var wait_left := 0.0
var test_pet := PetState.create(42)
var external_pet: PetState = null
var game_mode := false  # true when embedded in a real game; preview chrome hides and
                         # care effects route through the host instead of test_pet.
var caption := Label.new()
var needs := Label.new()
var selector := OptionButton.new()
var message := Panel.new()
var message_label := Label.new()
var thought := Panel.new()
var thought_label := Label.new()
var message_left := 0.0
var thought_left := 0.0
var thought_follow := "dog"  # "dog" or element_id
var ready_ok := false

func bind_pet(pet: PetState) -> void:
	external_pet = pet
	game_mode = pet != null
	if is_node_ready():
		var toolbar := caption.get_parent()
		if toolbar is Control: (toolbar as Control).visible = not game_mode
		needs.visible = not game_mode

func open_project(data: Dictionary, level_id: String = "") -> bool:
	if not LevelProject.validate(data).is_empty(): return false
	var loaded := {}
	for a in data.assets:
		var tex := LevelProject.texture(a)
		if tex == null: return false
		loaded[a.id] = tex
	project = data.duplicate(true)
	textures = loaded
	assets.clear()
	for a in project.assets: assets[a.id] = a
	if is_node_ready(): _populate(level_id)
	else: set_meta("initial_level", level_id)
	return true

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background := ColorRect.new()
	background.color = Color("18251e")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	add_child(world)
	var toolbar := HBoxContainer.new()
	toolbar.position = Vector2(20, 16)
	toolbar.add_theme_constant_override("separation", 20)
	add_child(toolbar)
	caption.text = "YuFriend · Podgląd poziomów"
	toolbar.add_child(caption)
	toolbar.add_child(selector)
	selector.item_selected.connect(func(index): show_level(project.levels[index].id))
	var reset := Button.new()
	reset.text = "Od początku"
	reset.pressed.connect(func(): show_level(current.id))
	toolbar.add_child(reset)
	# game_mode is set by bind_pet(); host (LevelRoom) owns the top bar.
	toolbar.visible = not game_mode
	needs.position = Vector2(20, 62)
	add_child(needs)
	_style_bubble(message, message_label, "message")
	_style_bubble(thought, thought_label, "thought")
	add_child(message); add_child(thought)
	message.visible = false; thought.visible = false
	dog.add_child(animator)
	animator.scale = Vector2.ONE * RoomLayout.PUPPY_SCALE * 1.15
	world.middle_ground.add_child(dog)
	animator.set_skin(load("res://data/skins/puppy_pixel.tres"))
	resized.connect(_fit)
	if game_mode:
		var tb := caption.get_parent()
		if tb is Control: (tb as Control).visible = false
		needs.visible = false
	if not project.is_empty(): _populate(get_meta("initial_level", ""))

func _style_bubble(panel: Panel, label: Label, kind: String) -> void:
	label.add_theme_color_override("font_color", Color("243c29"))
	label.add_theme_font_size_override("font_size", 14)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(240, 0)
	label.add_theme_constant_override("outline_size", 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("f6f6ec") if kind == "thought" else Color("edf0d9")
	sb.border_color = Color("243c29")
	sb.border_width_left = 1; sb.border_width_right = 1; sb.border_width_top = 1; sb.border_width_bottom = 1
	var radius := 24 if kind == "thought" else 12
	sb.corner_radius_top_left = radius; sb.corner_radius_top_right = radius
	sb.corner_radius_bottom_left = radius; sb.corner_radius_bottom_right = radius
	sb.content_margin_left = 16; sb.content_margin_right = 16
	sb.content_margin_top = 10; sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)
	panel.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.offset_left = 16; label.offset_right = -16
	label.offset_top = 10; label.offset_bottom = -10

func _populate(level_id: String) -> void:
	selector.clear()
	for l in project.levels: selector.add_item(l.name)
	show_level(project.startLevel if level_id.is_empty() else level_id)

func show_level(level_id: String) -> bool:
	var found: Dictionary = {}
	for l in project.levels:
		if l.id == level_id: found = l; break
	if found.is_empty(): return false
	for n in nodes.values():
		n.get_parent().remove_child(n)
		n.queue_free()
	nodes.clear()
	current = found
	flight.clear(); pending.clear()
	pointer_ball = ""; pointer_id = -1
	target = Vector2.INF; wait_left = 0
	for e in current.elements:
		var node := Node2D.new()
		node.name = e.id
		node.position = Vector2(e.x, e.y)
		node.visible = e.visible
		var sprite := Sprite2D.new()
		sprite.texture = textures[e.asset]
		sprite.centered = false
		var a: Dictionary = assets[e.asset]
		sprite.scale = Vector2(e.width / a.width, e.height / a.height)
		sprite.position = -Vector2(e.pivot.x, e.pivot.y) * sprite.scale
		node.add_child(sprite)
		var layer: Node2D = {"background": world.background, "middle": world.middle_ground, "foreground": world.foreground}[e.layer]
		layer.add_child(node)
		nodes[e.id] = node
	world.middle_ground.move_child(dog, -1)
	dog_position = Vector2(current.spawn.x, current.spawn.y)
	dog.position = dog_position
	animator.request_clip("idle")
	for i in project.levels.size():
		if project.levels[i].id == level_id: selector.select(i)
	ready_ok = true
	_fit()
	_say(current.name + " · kliknij ziemię lub przedmiot; przeciągnij piłkę.")
	level_changed.emit(current.id)
	return true

func _fit() -> void:
	if current.is_empty(): return
	var factor := maxf(0.02, minf((size.x - 40) / current.width, (size.y - 180) / current.height))
	world.scale = Vector2.ONE * factor
	world.position = Vector2((size.x - current.width * factor) / 2, 150 + (size.y - 170 - current.height * factor) / 2)

func clamp_walk(point: Vector2) -> Vector2:
	var w: Dictionary = current.walk
	return Vector2(clampf(point.x, w.x, w.x + w.width), clampf(point.y, w.y, w.y + w.height))

func hit(point: Vector2) -> Dictionary:
	var found: Dictionary = {}
	var best := -INF
	for i in current.elements.size():
		var e: Dictionary = current.elements[i]
		if not e.visible or not LevelProject.is_interactive(e): continue
		var moved := e.duplicate()
		moved.x = nodes[e.id].position.x
		moved.y = nodes[e.id].position.y
		if not LevelProject.element_rect(moved, assets[e.asset]).has_point(point): continue
		var priority: float = LevelProject.LAYERS.find(e.layer) * 1000000000.0 + (moved.y * 1000 if e.layer == "middle" else 0) + i
		if priority >= best: best = priority; found = e
	return found

func _unhandled_input(event: InputEvent) -> void:
	if not ready_ok: return
	if event is InputEventScreenTouch:
		if event.pressed: _press(world.to_local(event.position), event.index)
		elif event.index == pointer_id:
			_release(world.to_local(event.position), event.canceled)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not OS.has_feature("mobile"):
		if event.pressed: _press(world.to_local(event.position), -2)
		elif pointer_id == -2: _release(world.to_local(event.position), false)

func _press(point: Vector2, index: int) -> void:
	if pointer_id != -1 or not Rect2(0, 0, current.width, current.height).has_point(point): return
	var e := hit(point)
	if not e.is_empty() and e.get("script", "") == "ball":
		pointer_ball = e.id
		pointer_id = index
		return
	activate(e, point)

func _release(point: Vector2, cancelled: bool) -> void:
	if not cancelled and not pointer_ball.is_empty(): throw_ball(pointer_ball, point)
	pointer_id = -1
	pointer_ball = ""

func throw_ball(element_id: String, destination: Vector2) -> void:
	if not nodes.has(element_id): return
	var e: Dictionary = {}
	for entry in current.elements:
		if entry.id == element_id: e = entry
	if e.is_empty() or e.get("script", "") != "ball" or e.get("static", true): return
	if not flight.is_empty(): _reset_ball_lift()
	var end := clamp_walk(destination)
	var arc: float = float(e.get("params", {}).get("arc", 100))
	flight = {"id": element_id, "from": nodes[element_id].position, "to": end, "time": 0.0, "arc": arc}
	target = end
	pending = {"script": "ball", "id": element_id, "element": e}
	interaction_requested.emit(element_id, "ball", e.duplicate(true))
	_say("Łap piłkę!")

func activate(e: Dictionary, point: Vector2) -> void:
	pending.clear(); wait_left = 0
	if e.is_empty(): target = clamp_walk(point); return
	if not LevelProject.is_interactive(e): return
	var script_id: String = e.get("script", "none")
	interaction_requested.emit(e.get("id", ""), script_id, e.duplicate(true))
	var params: Dictionary = e.get("params", {})
	match script_id:
		"portal":
			var next: String = params.get("target", "")
			if params.get("message", "") != "": _say(params.message)
			show_level(next)
		"message":
			_say(params.get("text", e.get("name", "")), float(params.get("duration", 4)))
		"thought":
			var text: String = params.get("text", "…")
			var duration := float(params.get("duration", 4))
			var from_dog: bool = params.get("from_dog", true) == true
			thought_follow = "dog" if from_dog else e.get("id", "dog")
			_think(text, duration)
		"greet":
			_say(params.get("text", "Cześć, przyjacielu!"))
		"bark":
			animator.request_clip(params.get("clip", "bark_stand"))
			_say(params.get("message", "Hau!"))
		"play_clip":
			animator.request_clip(params.get("clip", "idle"))
			if params.get("message", "") != "": _say(params.message)
			wait_left = float(params.get("duration", 3))
		"walk_to":
			target = clamp_walk(Vector2(float(params.get("x", e.x)), float(params.get("y", e.y))))
			pending = {"script": "walk_to", "element": e}
		"feed", "pet", "clean", "rest", "bath", "cuddle", "drink", "sniff", "course", "timed_course", "water", "hide", "visitor":
			target = clamp_walk(Vector2(e.x - 50, e.y))
			pending = {"script": script_id, "element": e}

func _process(delta: float) -> void:
	if not ready_ok: return
	message_left = maxf(0, message_left - delta)
	message.visible = message_left > 0
	thought_left = maxf(0, thought_left - delta)
	thought.visible = thought_left > 0
	if thought.visible: _position_bubble(thought, thought_follow)
	if message.visible: _position_bubble(message, "dog")
	if not flight.is_empty():
		flight.time = minf(1, flight.time + delta)
		var ball: Node2D = nodes[flight.id]
		ball.position = flight.from.lerp(flight.to, flight.time)
		var sprite: Sprite2D = ball.get_child(0)
		var e: Dictionary
		for entry in current.elements:
			if entry.id == flight.id: e = entry
		sprite.position.y = -e.pivot.y * sprite.scale.y - sin(flight.time * PI) * float(flight.get("arc", 100))
		if flight.time >= 1: _reset_ball_lift(); flight.clear()
	if target.is_finite():
		animator.facing_left = target.x < dog_position.x
		var running: bool = pending.get("script", "") == "ball"
		animator.request_clip("run" if running else "walk")
		var speed: float = float(current.get("runSpeed", 160)) if running else float(current.get("walkSpeed", 70))
		dog_position = dog_position.move_toward(target, delta * speed)
		dog.position = dog_position
		if dog_position.distance_to(target) < 1 and flight.is_empty():
			target = Vector2.INF
			_complete()
	elif wait_left > 0:
		wait_left -= delta
		if wait_left <= 0: animator.request_clip("idle")
	if not game_mode:
		needs.text = "Pies testowy · Sytość %d%% · Energia %d%% · Kontakt %d%% · Zapis gry pozostaje bez zmian" % [test_pet.needs.fullness, test_pet.needs.energy, test_pet.needs.contact]

func _position_bubble(panel: Panel, follow: String) -> void:
	var p: Vector2
	if follow == "dog" or not nodes.has(follow): p = world.to_global(dog.position + Vector2(0, -220))
	else: p = world.to_global(nodes[follow].position + Vector2(0, -80))
	var local := get_global_transform().affine_inverse() * p
	panel.position = local - Vector2(panel.size.x / 2, panel.size.y + 10)

func _reset_ball_lift() -> void:
	if flight.is_empty(): return
	for e in current.elements:
		if e.id == flight.id:
			var sprite: Sprite2D = nodes[e.id].get_child(0)
			sprite.position.y = -e.pivot.y * sprite.scale.y

func _complete() -> void:
	var script_id: String = pending.get("script", "none")
	var e: Dictionary = pending.get("element", {})
	var params: Dictionary = e.get("params", {})
	if script_id in ["feed", "pet", "clean", "rest", "ball"]:
		var effects := {}
		if script_id == "feed": effects = {"fullness": int(params.get("fullness", 22))}
		elif script_id == "pet": effects = {"contact": int(params.get("contact", 18))}
		elif script_id == "clean": effects = {"hygiene": int(params.get("hygiene", 20))}
		elif script_id == "rest": effects = {"energy": int(params.get("energy", 15))}
		elif script_id == "ball": effects = {"play": int(params.get("play", 15)), "contact": int(params.get("contact", 5))}
		if not game_mode: NeedsSystem.change(test_pet, effects)
	var clip: String = str(params.get("clip", ""))
	if clip.is_empty():
		clip = {"feed":"eat_loop","pet":"petted_stand","clean":"petted_stand","rest":"sleep","ball":"play_bow","walk_to":"idle","bath":"petted_stand","cuddle":"petted_stand","drink":"eat_loop","sniff":"idle","course":"run","timed_course":"run","water":"play_bow","hide":"idle","visitor":"wag_stand"}.get(script_id, "idle")
	animator.request_clip(clip)
	var done_msg: String = str(params.get("message", ""))
	if done_msg.is_empty():
		done_msg = "Gotowe · " + {"feed":"posiłek","pet":"głaskanie","clean":"czesanie","rest":"odpoczynek","ball":"aport","walk_to":"doszedłem","bath":"kąpiel","cuddle":"przytulanie","drink":"woda","sniff":"węszenie","course":"tor","timed_course":"tor na czas","water":"woda","hide":"schowany","visitor":"powitanie"}.get(script_id, script_id)
	if script_id != "none": _say(done_msg)
	wait_left = 3
	pending.clear()

func _say(value: String, duration: float = 4.0) -> void:
	message_label.text = value
	message_left = duration
	message.visible = true
	message.reset_size()

func _think(value: String, duration: float = 4.0) -> void:
	thought_label.text = value
	thought_left = duration
	thought.visible = true
	thought.reset_size()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		pointer_id = -1
		pointer_ball = ""
