extends SceneTree

# Rebuild the transparent 1:3 yard sprites from their pixel-native draw code.
# Run with: Godot --path . --script res://tools/export_yard_sprites.gd
const OUTPUT := "res://assets/art/yard/sprites"

func _initialize() -> void:
	call_deferred("_export_all")

func _export_all() -> void:
	var folder := ProjectSettings.globalize_path(OUTPUT)
	DirAccess.make_dir_recursive_absolute(folder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(480, 120)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node2D.new()
	world.scale = Vector2.ONE / RoomLayout.PIXEL_SIZE
	viewport.add_child(world)
	var failures := 0
	for id in YardSpriteLayout.CROPS:
		var variants: Array[String] = [id]
		if id == "gate": variants.append("gate_open")
		if id == "puddle": variants.append("puddle_dry")
		for variant in variants:
			var art := _make_art(id, variant)
			world.add_child(art)
			await process_frame
			await RenderingServer.frame_post_draw
			var crop: Rect2i = YardSpriteLayout.CROPS[id]
			var pixels := Rect2i(crop.position / 3, crop.size / 3)
			var image := viewport.get_texture().get_image().get_region(pixels)
			var path: String = folder.path_join(variant + ".png")
			var error := image.save_png(path)
			if error != OK or image.get_used_rect().size == Vector2i.ZERO:
				printerr("Failed to export ", variant, " error=", error)
				failures += 1
			else:
				print("EXPORTED ", variant, " ", image.get_size(), " -> ", path)
			world.remove_child(art)
			art.queue_free()
			await process_frame
	viewport.queue_free()
	quit(1 if failures else 0)

func _make_art(id: String, variant: String) -> Node2D:
	if id in ["shade", "course", "puddle", "sprinkler"]:
		if id == "shade":
			var shade := YardRestView.new()
			shade.animate = false
			return shade
		if id == "course": return YardCourseView.new()
		var water := YardWaterView.new()
		water.set_process(false)
		water.wet = variant != "puddle_dry"
		water.show_puddle = id == "puddle"
		water.show_sprinkler = id == "sprinkler"
		return water
	var art := RoomArtwork.new()
	art.kind = "yard_" + id
	art.portal_open = variant == "gate_open"
	return art
