extends SceneTree
var failed := 0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var pet := PetState.create(42)
	var original := pet.to_dict()
	var now := 20000 * 86400.0 + 12 * 3600
	var total := 0.0
	for i in 150:
		total += BondLevels.petting_gain(pet, now)
		PersonalitySystem.record(pet, "pet", now)
	check(is_equal_approx(total, 3.5), "150 strokes cap daily bond at 3.5")
	pet = PetState.from_dict(pet.to_dict())
	check(BondLevels.petting_gain(pet, now) == 0, "roundtrip retains spent budget")
	check(BondLevels.petting_gain(pet, now - 86400) == 0, "rollback cannot renew budget")
	check(BondLevels.petting_gain(pet, now + 86400) == 0.6, "next day renews budget")
	check(pet.skills == original.skills and pet.bond == original.bond, "budget lookup preserves progress")
	var s := GameSession.new()
	s.local_clock = func(): return now
	s.start(preload("res://tests/helper_paths.gd").data_root() + "/yuf-stage1-%s/pet.json" % Time.get_ticks_usec())
	s.local_clock = func(): return now
	s.pet.history = []
	s.pet.fatigue = 0
	s.change_yard(true)
	s.outdoor_commands.offer_recall(Vector2(700,310))
	check(s.outdoor_commands.start(s,true), "outdoor command begins")
	s.outdoor_commands.arrived = true
	s.outdoor_commands.advance(s,s.outdoor_commands.trial.time_left)
	check(s.outdoor_commands.praise(s), "outdoor reward completes")
	check(s.pet.history[-1].events.get("train_guided",0)==1 and s.pet.history[-1].events.get("reward_praise",0)==1, "outdoor training records personality events exactly once")
	s.free()
	# Quirk discoveries: only matching activities reveal them, and only a saved
	# discovery is announced.
	s = GameSession.new()
	s.local_clock = func(): return now
	s.start(preload("res://tests/helper_paths.gd").data_root() + "/yuf-stage1-quirk-%s/pet.json" % Time.get_ticks_usec())
	s.local_clock = func(): return now
	s.pet.life.quirks = ["ball_guard", "bed_circles"]
	s.pet.life.discovered = []
	s.pet.life.observations = {"ball_guard": 2, "bed_circles": 2}
	s._note("play", false)
	check(int(s.pet.life.observations.ball_guard) == 2 and s.pet.history[-1].events.get("play", 0) >= 1, "digging-style play counts without revealing ball quirks")
	s._note("rest")
	check(s._discovery_message.is_empty(), "discovery waits for its save")
	check(s.flush() and s._discovery_message.contains("Kółko przed snem"), "saved discovery is announced")
	s._discovery_message = ""
	var good_path := s.storage.path
	s.storage.path = "/dev/null/yuf-unwritable/pet.json"
	s._note("play")
	check(not s.flush() and s._discovery_message.is_empty() and s._pending_discovery.is_empty(), "failed save never announces a discovery")
	s.storage.path = good_path
	s.free()
	var app: GameUI = load("res://scenes/Main.tscn").instantiate()
	app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/yuf-stage1-ui-%s/pet.json" % Time.get_ticks_usec()
	app.session.local_clock = func(): return now
	root.add_child(app)
	app.session.set_process(false)
	app.app_foreground = true
	app._show_settings()
	app._update_attention()
	check(app._dialog_open() and app.modal_shade.visible and not app.session.attention_available, "settings blocks attention and shades background")
	app._hide_settings()
	app._show_tricks()
	app._update_attention()
	check(app._dialog_open() and app.modal_shade.visible and not app.session.attention_available, "dynamic window blocks attention and shades background")
	for child in app.get_children():
		if child is Window: child.hide()
	app._update_attention()
	check(not app.modal_shade.visible and app.session.attention_available, "closing windows restores attention")
	app.queue_free()
	await process_frame
	print("STAGE1 FAILURES: ",failed)
	quit(1 if failed else 0)
