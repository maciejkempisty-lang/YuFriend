extends SceneTree

var passed: int = 0
var failed: int = 0
const SOURCE := "res://assets/art/reference/golden-puppy-simple-side-v1.png"

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS SPRITES " + label)
	else:
		failed += 1
		push_error("FAIL SPRITES " + label)

func _manifest() -> Dictionary:
	return {"version": 1, "frame_size": [627, 627], "anchor": [313, 530], "animations": {
		"give_paw": {"sheet": SOURCE, "columns": 2, "count": 3, "fps": 1, "durations": [1, 3, 1]}}}

func _run() -> void:
	var result := SpriteImporter.build(_manifest())
	check(result.ok, "partial atlas pack imports")
	if not result.ok:
		printerr(result.error)
		quit(1)
		return
	var pack: PetAnimationSet = result.pack
	check(pack.frames.get_frame_count("give_paw") == 3, "empty last atlas cell is excluded")
	var last: AtlasTexture = pack.frames.get_frame_texture("give_paw", 2)
	check(last.region == Rect2(0, 627, 627, 627), "atlas order is row-major")
	check(not pack.frames.get_animation_loop("give_paw") and pack.frames.get_frame_duration("give_paw", 1) == 3, "one-shot and authored hold timing survive import")
	check(result.missing.size() == 21 and result.missing.has("idle"), "missing clips remain eligible for fallback")
	var invalid := _manifest()
	invalid.animations.give_paw.count = 5
	check(not SpriteImporter.build(invalid).ok, "too many atlas cells rejected")
	invalid = _manifest()
	invalid.animations.give_paw.durations = [1, 0, 1]
	check(not SpriteImporter.build(invalid).ok, "zero-duration frame rejected")
	invalid = _manifest()
	invalid.animations.give_paw.frames = [SOURCE]
	check(not SpriteImporter.build(invalid).ok, "ambiguous source rejected")
	invalid = _manifest()
	invalid.anchor = [700, 0]
	check(not SpriteImporter.build(invalid).ok, "anchor outside frame rejected")
	invalid = _manifest()
	invalid.animations = {"typo": invalid.animations.give_paw}
	check(not SpriteImporter.build(invalid).ok, "unknown clip cannot silently disappear")
	invalid = _manifest()
	invalid.animations.give_paw.sheet = "res://assets/does-not-exist.png"
	check(not SpriteImporter.build(invalid).ok, "missing PNG produces useful import failure")
	var separate := {"version": 1, "frame_size": [1254, 1254], "anchor": [627, 1050], "animations": {"idle": {"frames": [SOURCE, SOURCE], "fps": 2}}}
	var ordered := SpriteImporter.build(separate)
	check(ordered.ok and ordered.pack.frames.get_frame_count("idle") == 2 and ordered.pack.frames.get_animation_loop("idle"), "individual PNG sequence preserves order and loop")
	separate.frame_size = [512, 512]
	check(not SpriteImporter.build(separate).ok, "inconsistent PNG dimensions rejected")
	var irregular := {"version": 1, "frame_size": [512, 512], "anchor": [256, 448], "animations": {
		"walk": {"sheet": SOURCE, "regions": [[0, 0, 627, 626], [627, 626, 627, 628]],
		"anchors": [[300, 530], [302, 532]], "scale": 0.8, "fps": 10}}}
	var irregular_pack := SpriteImporter.build(irregular)
	check(irregular_pack.ok and irregular_pack.pack.frames.get_frame_texture("walk", 1).get_size() == Vector2(627, 628), "explicit rectangles preserve unequal cell dimensions")
	check(irregular_pack.ok and irregular_pack.pack.clip_layouts.walk.anchors[1] == Vector2(302, 532), "per-frame ground anchors survive import")
	invalid = irregular.duplicate(true)
	invalid.animations.walk.regions[1][2] = 628
	check(not SpriteImporter.build(invalid).ok, "rectangle crossing sheet edge is rejected")
	invalid = irregular.duplicate(true)
	invalid.animations.walk.anchors[0] = [700, 530]
	check(not SpriteImporter.build(invalid).ok, "anchor outside an irregular cell is rejected")
	invalid = irregular.duplicate(true)
	invalid.animations.walk.scale = NAN
	check(not SpriteImporter.build(invalid).ok, "nonfinite clip scale is rejected")
	var path := "user://qa-sprites-%s.res" % Time.get_ticks_usec()
	check(ResourceSaver.save(pack, path) == OK, "animation pack serializes")
	var loaded: PetAnimationSet = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded != null and loaded.frames.get_frame_count("give_paw") == 3 and loaded.anchor == pack.anchor, "saved pack reloads with frame metadata")
	var animator := PetAnimator.new()
	root.add_child(animator)
	animator.set_process(false)
	var skin := PetSkin.new()
	skin.standing = load(SOURCE)
	skin.sitting = load(SOURCE)
	skin.animation_pack_path = path
	animator.set_skin(skin)
	check(animator.skin.frame_height == 627 and animator.skin.frames != null, "runtime discovers imported pack automatically")
	var completions: Array[int] = []
	animator.request_completed.connect(func(id: int): completions.append(id))
	animator.request_clip("give_paw", 7)
	check(animator.current == "sit_down", "paw routes through sitting")
	animator._process(0.61)
	check(animator.current == "give_paw" and animator.real_clip, "supplied clip replaces fallback")
	animator._process(2)
	check(completions.is_empty(), "long authored trick cannot complete early")
	animator.set_skin(skin)
	animator._process(5.01)
	check(completions == [7] and animator.pose == "sit", "completion survives skin refresh and fires once")
	animator.request_clip("walk", 9)
	check(completions == [7] and animator.current == "stand_up", "walking waits for standing transition")
	animator._process(0.61)
	check(completions == [7, 9] and animator.current == "walk" and not animator.real_clip, "missing walk uses fallback after transition")
	var trainer := TrainingSystem.new()
	var pet := PetState.create(29)
	trainer.begin(pet, "sit", true)
	trainer.advance(20, false)
	check(trainer.phase == "attempt" and not trainer.reward(pet, "praise").ok, "slow presentation cannot unlock reward")
	trainer.advance(0.02, true)
	check(trainer.phase == "reward" and trainer.time_left > 2, "reward window starts after presentation finishes")
	var room := RoomView.new()
	room.size = Vector2(390, 568)
	room.hud_bottom = 194
	root.add_child(room)
	room.set_process(false)
	room.animator.set_process(false)
	room.animator.request_clip("sit_idle")
	room.animator._process(0.61)
	room.move_to(RoomLayout.START + Vector2(180, 0))
	var arrivals: Array[int] = []
	room.performance_finished.connect(func(id: int): arrivals.append(id))
	room.play_performance("walk", 11)
	room._process(0.5)
	check(room.pet_world == RoomLayout.START and arrivals.is_empty(), "seated pet does not slide toward destination")
	room.animator._process(0.61)
	room._process(2.5)
	check(room.pet_world == RoomLayout.START + Vector2(180, 0) and arrivals == [11], "come finishes only at destination")
	var distances: Array[float] = []
	for width in [390, 1100]:
		room.size = Vector2(width, 568)
		room.update_placement()
		room.pet_world = Vector2(500, 322)
		room.animator._start("walk")
		room.move_to(Vector2(900, 322))
		var before := room.pet_world.x
		room._process(0.1)
		distances.append((room.pet_world.x - before) / room.presentation_scale)
	check(is_equal_approx(distances[0], distances[1]), "room width does not change walking speed relative to puppy size")
	check(room.action_at(room.world_to_screen(room.pet_world - Vector2(0, 170) * room.presentation_scale)) == "pet", "top of the animated puppy is also touchable")
	room.free()
	# Exercise the actual delivered pack, including serialized source geometry.
	var production: PetSkin = load("res://data/skins/puppy_pixel.tres")
	animator.pose = "stand"
	animator.pending = ""
	animator.current = "idle"
	animator.current_id = 0
	animator.set_skin(production)
	var production_frames: SpriteFrames = animator.skin.frames
	var total := 0
	for clip in PetAnimator.CLIPS: total += production_frames.get_frame_count(clip)
	check(production_frames.get_animation_names().size() == 22 and total == 142, "production pack contains all 22 clips and 142 frames")
	var paw_seconds := 0.0
	for i in production_frames.get_frame_count("give_paw"):
		paw_seconds += production_frames.get_frame_duration("give_paw", i) / production_frames.get_animation_speed("give_paw")
	check(is_equal_approx(paw_seconds, 1.5) and production_frames.get_frame_duration("give_paw", 7) > production_frames.get_frame_duration("give_paw", 0), "delivered paw hold retains its 1500 ms timing")
	animator._start("walk")
	animator.sprite.set_frame_and_progress(7, 0)
	var ground: Vector2 = animator.skin.clip_layouts.walk.anchors[7]
	check(is_zero_approx((animator.sprite.position + ground * animator.sprite.scale).y), "last walk frame stays on its calibrated ground line")
	animator.facing_left = true
	animator._apply_transform()
	var mirrored := Vector2(production_frames.get_frame_texture("walk", 7).get_width() - ground.x, ground.y)
	check((animator.sprite.position + mirrored * animator.sprite.scale).is_zero_approx(), "left-facing sprite mirrors around its calibrated anchor")
	animator._start("walk")
	check(animator.sprite.frame == 0, "restarting a clip starts at frame zero")
	animator.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("SPRITE RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
