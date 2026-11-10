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
	var path := "user://qa-sprites-%s.res" % Time.get_ticks_usec()
	check(ResourceSaver.save(pack, path) == OK, "animation pack serializes")
	var loaded: PetAnimationSet = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded != null and loaded.frames.get_frame_count("give_paw") == 3 and loaded.anchor == pack.anchor, "saved pack reloads with frame metadata")
	var animator := PetAnimator.new()
	root.add_child(animator)
	animator.set_process(false)
	var skin: PetSkin = load("res://data/skins/puppy_simple.tres").duplicate()
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
	root.add_child(room)
	room.set_process(false)
	room.animator.set_process(false)
	room.animator.request_clip("sit_idle")
	room.animator._process(0.61)
	room.move_to(0.75)
	var arrivals: Array[int] = []
	room.performance_finished.connect(func(id: int): arrivals.append(id))
	room.play_performance("walk", 11)
	room._process(0.5)
	check(room.current_ratio == 0.5 and arrivals.is_empty(), "seated pet does not slide toward destination")
	room.animator._process(0.61)
	room._process(2)
	check(is_equal_approx(room.current_ratio, 0.75) and arrivals == [11], "come finishes only at destination")
	room.free()
	animator.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	print("SPRITE RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
