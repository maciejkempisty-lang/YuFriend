extends SceneTree
# Exact game artwork for the HTML editor; no duplicate hand-maintained drawings.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.size = Vector2i(480, 120)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node2D.new()
	world.scale = Vector2.ONE / 3
	viewport.add_child(world)
	var crops := {"home-background": Rect2(0,0,1440,360), "yard-background": Rect2(0,0,1440,360), "bed": Rect2(-90,-54,180,72), "food": Rect2(-30,-30,60,36), "toys": Rect2(-51,-75,102,78), "door": Rect2(-63,-189,126,192), "ball": Rect2(-18,-18,36,36)}
	for id in crops:
		var crop: Rect2 = crops[id]
		viewport.size = Vector2i(crop.size / 3)
		var art := RoomArtwork.new()
		art.kind = "room" if id == "home-background" else ("yard" if id == "yard-background" else id)
		art.configure(Vector2(1440,360))
		art.position = -crop.position
		world.add_child(art)
		await process_frame
		RenderingServer.force_draw()
		var error := viewport.get_texture().get_image().save_png("res://level-editor/assets/" + id + ".png")
		if error != OK: quit(1); return
		world.remove_child(art)
		art.free()
	viewport.size = Vector2i(96,96)
	var pet := PetAnimator.new()
	pet.scale = Vector2.ONE * RoomLayout.PUPPY_SCALE * 1.15
	pet.position = Vector2(144,240)
	world.add_child(pet)
	pet.set_skin(load("res://data/skins/puppy_pixel.tres"))
	pet.request_clip("idle")
	await process_frame
	RenderingServer.force_draw()
	viewport.get_texture().get_image().save_png("res://level-editor/assets/puppy.png")
	viewport.queue_free()
	quit()
