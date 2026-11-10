class_name SpriteImporter
extends RefCounted

## Accepts partial packs. Unknown names and invalid dimensions stop the import.
static func build(config: Dictionary) -> Dictionary:
	if config.get("version") != 1:
		return _fail("Manifest musi mieć version: 1.")
	var size_value: Variant = config.get("frame_size")
	if not _pair(size_value) or not _whole(size_value[0], 1, 4096) or not _whole(size_value[1], 1, 4096):
		return _fail("frame_size musi zawierać dwa całkowite wymiary od 1 do 4096.")
	var dimensions := Vector2i(int(size_value[0]), int(size_value[1]))
	var anchor_value: Variant = config.get("anchor")
	if not _pair(anchor_value) or float(anchor_value[0]) < 0 or float(anchor_value[1]) < 0 or float(anchor_value[0]) > dimensions.x or float(anchor_value[1]) > dimensions.y:
		return _fail("anchor musi leżeć wewnątrz płótna klatki.")
	var height: Variant = config.get("display_height", 245)
	if not _number(height) or float(height) < 32 or float(height) > 400:
		return _fail("display_height musi być liczbą od 32 do 400.")
	var definitions: Variant = config.get("animations")
	if not definitions is Dictionary or definitions.is_empty():
		return _fail("Dodaj co najmniej jeden klip w animations.")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for clip in definitions:
		if not PetAnimator.CLIPS.has(clip): return _fail("Nieznana animacja: %s." % clip)
		var spec: Variant = definitions[clip]
		if not spec is Dictionary: return _fail("Opis %s musi być obiektem JSON." % clip)
		var fps: Variant = spec.get("fps")
		if not _number(fps) or float(fps) <= 0 or float(fps) > 60:
			return _fail("%s: fps musi być większe od 0 i nie większe od 60." % clip)
		if spec.has("frames") == spec.has("sheet"):
			return _fail("%s: podaj frames ALBO sheet." % clip)
		var textures: Array[Texture2D] = []
		if spec.has("sheet"):
			var source := _texture(spec.sheet)
			if not source.ok: return _fail("%s: %s" % [clip, source.error])
			var texture: Texture2D = source.texture
			if not _whole(spec.get("columns"), 1, 4) or not _whole(spec.get("count"), 1, 64):
				return _fail("%s: columns musi wynosić 1–4, a count 1–64." % clip)
			var columns := int(spec.columns)
			var count := int(spec.count)
			if texture.get_width() != dimensions.x * columns or texture.get_height() % dimensions.y != 0:
				return _fail("%s: arkusz nie pasuje do frame_size i columns." % clip)
			if count > columns * (texture.get_height() / dimensions.y):
				return _fail("%s: count przekracza liczbę pól arkusza." % clip)
			for index in count:
				var region := AtlasTexture.new()
				region.atlas = texture
				region.region = Rect2((index % columns) * dimensions.x, (index / columns) * dimensions.y, dimensions.x, dimensions.y)
				region.filter_clip = true
				textures.append(region)
		else:
			var paths: Variant = spec.frames
			if not paths is Array or paths.is_empty() or paths.size() > 64:
				return _fail("%s: frames musi zawierać od 1 do 64 ścieżek PNG." % clip)
			for path in paths:
				var source := _texture(path)
				if not source.ok: return _fail("%s: %s" % [clip, source.error])
				var texture: Texture2D = source.texture
				if Vector2i(texture.get_size()) != dimensions:
					return _fail("%s: wszystkie pliki muszą mieć rozmiar %s." % [clip, dimensions])
				textures.append(texture)
		var durations: Variant = spec.get("durations", [])
		if not durations is Array or (not durations.is_empty() and durations.size() != textures.size()):
			return _fail("%s: durations musi mieć po jednym mnożniku czasu na klatkę." % clip)
		for duration in durations:
			if not _number(duration) or float(duration) <= 0 or float(duration) > 60:
				return _fail("%s: czas klatki musi być dodatni i nie większy od 60." % clip)
		frames.add_animation(clip)
		frames.set_animation_speed(clip, float(fps))
		frames.set_animation_loop(clip, bool(PetAnimator.CLIPS[clip][3]))
		for index in textures.size():
			frames.add_frame(clip, textures[index], 1.0 if durations.is_empty() else float(durations[index]))
	var pack := PetAnimationSet.new()
	pack.frames = frames
	pack.frame_size = dimensions
	pack.anchor = Vector2(float(anchor_value[0]), float(anchor_value[1]))
	pack.display_height = float(height)
	var missing: Array[String] = []
	for clip in PetAnimator.CLIPS:
		if not definitions.has(clip): missing.append(clip)
	return {"ok": true, "pack": pack, "missing": missing}

static func _texture(value: Variant) -> Dictionary:
	if not value is String or not value.simplify_path().begins_with("res://assets/") or value.get_extension().to_lower() != "png":
		return _fail("Ścieżka PNG musi zaczynać się od res://assets/.")
	if not ResourceLoader.exists(value):
		return _fail("Brak %s. Dodaj plik i poczekaj na import w edytorze Godota." % value)
	var texture: Resource = ResourceLoader.load(value)
	if not texture is Texture2D: return _fail("Plik %s nie jest teksturą." % value)
	return {"ok": true, "texture": texture}

static func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func _whole(value: Variant, low: int, high: int) -> bool:
	return _number(value) and float(value) == floorf(float(value)) and float(value) >= low and float(value) <= high

static func _pair(value: Variant) -> bool:
	return value is Array and value.size() == 2 and _number(value[0]) and _number(value[1])

static func _fail(message: String) -> Dictionary:
	return {"ok": false, "error": message}
