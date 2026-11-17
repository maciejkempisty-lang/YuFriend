extends SceneTree

var passed := 0
var failed := 0
var app: Control
var heard: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, label: String) -> void:
	if condition:
		passed += 1
		print("PASS AUDIO " + label)
	else:
		failed += 1
		push_error("FAIL AUDIO " + label)

func _hear(effect: String) -> void:
	if effect == "bark": heard.append(effect)

func _reset() -> void:
	await process_frame
	app.room.cancel_activity()
	var animator: PetAnimator = app.room.animator
	animator.remaining = 0
	animator.pose = "stand"
	animator.pending = ""
	animator.request_clip("idle")
	app.effects.stop_all()
	await process_frame
	# Cases are independent; simulated animation time does not advance the audio clock.
	app.effects._last_played.clear()
	heard.clear()

func _bark_is_playing() -> bool:
	return _effect_is_playing("bark")

func _effect_is_playing(effect: String) -> bool:
	for player in app.effects.players:
		if player.playing and player.stream in app.effects.recordings[effect]: return true
	return false

func _run() -> void:
	var test_root := OS.get_environment("YUFRIEND_TEST_ROOT")
	var directory := ("user://" if test_root.is_empty() else test_root).path_join("qa-audio-%s" % Time.get_ticks_usec())
	app = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = directory.path_join("pet.json")
	app.room.ambient_life.life.autoplay = false
	app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600.0
	root.add_child(app)
	app.session.set_process(false)
	app.room.set_process(false)
	app.room.animator.set_process(false)
	app.session.sound_requested.connect(_hear)
	app.room.sound_requested.connect(_hear)
	check(app.effects.recordings.bark.size() == 3, "all three production bark recordings load")
	var barks: Array = app.effects.recordings.bark
	for index in barks.size():
		await _reset()
		app.effects.recordings.bark = [barks[index]]
		check(app.effects.play_effect("bark") and _bark_is_playing(), "production bark variant %d plays" % (index + 1))
	app.effects.start(directory.path_join("audio.cfg"))

	for scenario in [["door", true], ["door", false], ["hungry", false]]:
		await _reset()
		var action: String = scenario[0]
		var label := "%s (player=%s)" % [action, scenario[1]]
		app.room.pet_world = RoomLayout.START
		app.session._approach(action, scenario[1])
		check(heard.is_empty() and not _bark_is_playing(), label + " stays silent on the way")
		for step in 500:
			app.room.animator._process(0.1)
			app.room._process(0.1)
			if not app.room.moving: break
		check(not app.room.moving and app.room.animator.current == "bark_stand", label + " reaches the barking animation")
		check(heard == ["bark"] and _bark_is_playing(), label + " plays exactly one bark through the real app connections")
		app.session.arrive_at(app.session._approach_token)
		app.room.animator._process(2)
		check(heard == ["bark"], label + " does not repeat the bark on duplicate arrival or return to idle")

	await _reset()
	app.room.play_clip("sit_idle")
	app.room.animator._process(2)
	app.room.play_clip("bark_stand")
	check(app.room.animator.current == "stand_up" and heard.is_empty() and not _bark_is_playing(), "bark waits for the seated puppy to stand up")
	app.room.animator._process(2)
	check(app.room.animator.current == "bark_stand" and heard == ["bark"] and _bark_is_playing(), "queued bark plays when the visible barking actually starts")

	await _reset()
	app.room.play_clip("head_tilt_stand")
	app.room.play_clip("bark_stand")
	app.room.play_clip("idle")
	app.room.animator._process(2)
	check(heard.is_empty() and not _bark_is_playing(), "a replaced queued bark stays silent")

	await _reset()
	app.effects.set_enabled(false)
	app.room.play_clip("bark_stand")
	check(heard == ["bark"] and not _bark_is_playing(), "animation-triggered barking respects muted effects")
	app.effects.set_enabled(true)
	await _reset()
	app.effects.set_backgrounded(true)
	app.room.play_clip("bark_stand")
	check(not _bark_is_playing(), "animation-triggered barking respects background silence")
	app.effects.set_backgrounded(false)
	check(not _bark_is_playing(), "returning to foreground does not replay a missed bark")
	await _test_pet_happy()
	app.music.stop()
	# The audio mixer releases stopped streams on its own thread.
	await create_timer(0.1).timeout
	app.free()
	await process_frame
	for file in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(file))
	DirAccess.remove_absolute(directory)
	print("AUDIO RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _test_pet_happy() -> void:
	var happy: Array = app.effects.recordings.pet_happy
	check(happy.size() == 2 and happy.all(func(clip): return clip is AudioStreamWAV and clip.mix_rate == 48000 and not clip.stereo and clip.loop_mode == AudioStreamWAV.LOOP_DISABLED and clip.get_length() > 0 and clip.get_length() <= 1.1), "both ElevenLabs happy squeaks load as short mono one-shots")
	for index in happy.size():
		await _reset()
		app.effects.recordings.pet_happy = [happy[index]]
		check(app.effects.play_effect("pet_happy") and _effect_is_playing("pet_happy"), "happy squeak variant %d plays" % (index + 1))
	app.effects.recordings.pet_happy = happy

	await _reset()
	var requests: Array[String] = []
	app.session.sound_requested.connect(func(effect: String): requests.append(effect))
	check(app.session.act("pet") and requests == ["pet", "pet_happy"] and _effect_is_playing("pet") and _effect_is_playing("pet_happy"), "accepted petting plays the fur stroke and happy squeak through the app")
	var first_variant: int = app.effects._last_variant.get("pet_happy", -1)
	var started: float = app.effects._last_played.get("pet_happy", -INF)
	app.session.act("pet")
	check(app.effects._last_played.get("pet_happy") == started and app.effects.players.filter(func(player): return player.playing and player.stream in happy).size() == 1, "rapid petting does not restart or overlap happy squeaks")
	await _reset()
	check(app.session.act("pet") and app.effects._last_variant.get("pet_happy") != first_variant and _effect_is_playing("pet_happy"), "later petting alternates happy squeak variants")

	await _reset()
	requests.clear()
	app.session.pet.resting = true
	check(app.session.act("pet") and not app.session.is_sleeping() and requests.is_empty() and not _effect_is_playing("pet_happy"), "touch wakes a sleeping puppy quietly without a petting reward")
	app.session.pet.resting = false
	app.session.activity = "feed"
	check(not app.session.act("pet") and requests.is_empty() and not _effect_is_playing("pet_happy"), "an eating puppy does not squeak for rejected petting")
	app.session.activity = "idle"
	app.session.activity_left = 0
	app.session.pet.needs.hygiene = 40
	check(app.session.act("clean") and requests == ["brush"] and not _effect_is_playing("pet_happy"), "brushing keeps its own sound despite sharing the petted animation")

	await _reset()
	app.session.activity = "idle"
	app.session.activity_left = 0
	app.effects.set_enabled(false)
	check(app.session.act("pet") and not _effect_is_playing("pet_happy"), "happy squeaks respect muted effects")
	app.effects.set_enabled(true)
	await _reset()
	app.effects.set_backgrounded(true)
	check(not app.effects.play_effect("pet_happy"), "happy squeaks stay silent in the background")
	app.effects.set_backgrounded(false)
