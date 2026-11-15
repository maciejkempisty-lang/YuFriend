extends SceneTree

# Extract existing production frames with the same alpha cutoff as PetAnimator.
# Originals are unchanged; the small PNGs are resources of the native extension.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		printerr("Expected destination directory")
		quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/sprites/puppy/pixel/manifest.json"))
	DirAccess.make_dir_recursive_absolute(args[0])
	for clip in ["idle", "sleep"]:
		var spec: Dictionary = manifest.animations[clip]
		var rect: Array = spec.regions[0]
		var sheet := Image.load_from_file(spec.sheet)
		var frame := sheet.get_region(Rect2i(rect[0], rect[1], rect[2], rect[3]))
		frame.convert(Image.FORMAT_RGBA8)
		for y in frame.get_height():
			for x in frame.get_width():
				var color := frame.get_pixel(x, y)
				if color.a < 0.5: frame.set_pixel(x, y, Color.TRANSPARENT)
		var trimmed := frame.get_region(frame.get_used_rect())
		if trimmed.save_png(args[0].path_join("puppy-%s.png" % clip)) != OK:
			quit(1)
			return
	print("Widget portraits exported from production frames")
	quit(0)
