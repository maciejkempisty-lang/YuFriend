extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error(label)
func game() -> GameSession:
	var s := GameSession.new()
	s.pet = PetState.create(42)
	s.pet.needs.hygiene = 100
	s.pet.needs.energy = 90
	s.storage = SaveSystem.new(preload("res://tests/helper_paths.gd").data_root() + "/yuf-water-%s/pet.json" % Time.get_ticks_usec())
	s.storage.save_pet(s.pet)
	s.pet = s.storage.load_pet().pet
	s.weather.override_kind = "after_rain"
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	s.active = true
	s._brain_left = INF
	s.in_yard = true
	return s
func crossing(s: GameSession) -> void:
	check(s.water.splash(s), "splash starts from ready state")
	check(not s.water.splash(s), "double tap rejected")
	s.destination_reached()
	var hygiene: float = s.pet.needs.hygiene
	s.destination_reached()
	check(s.pet.needs.hygiene == hygiene, "duplicate arrival cannot charge again")
	if s.water.phase == "splash": check(not s.water.hint().contains("dotknij"), "splash pause does not ask for a disabled tap")
	s.water.advance(s, 0.8)
	if s.water.phase == "ready": check(s.water.hint().contains("dotknij"), "ready state asks for the next tap")
func _initialize() -> void:
	var s := game()
	var before := s.pet.to_dict()
	check(s.water.start(s, "puddle"), "puddle starts")
	check(s.busy() and not s.visitors.start(s, "bird"), "visitor cannot interrupt water")
	check(not s.start_hide("treat") and not s.start_bath(), "other activities blocked during water")
	check(not s.water.splash(s), "must reach puddle first")
	check(s.pet.to_dict() == before, "approach has no cost")
	s.destination_reached()
	for i in 3: crossing(s)
	check(s.water.phase == "shake", "third crossing automatically shakes")
	check(s.pet.needs.hygiene == 64 and s.pet.needs.energy == 84 and s.pet.needs.play == 70, "three puddle crossings have bounded effects")
	check(not s.water.splash(s), "no fourth crossing")
	s.water.advance(s, 1.9)
	check(not s.water.active() and not s.busy(), "shake finishes round")
	check(s.pet.needs.hygiene == 64, "shaking does not wash mud")
	check(s.last_message.contains("Kąpiel"), "dirty dog offered bath")
	check(not s.water.start(s, "sprinkler"), "shared water cooldown")
	for key in before:
		if key not in ["needs", "journal", "milestones", "last_seen_at", "history", "life"]: check(s.pet.to_dict()[key] == before[key], "preserves " + key)
	check(s.pet.history[-1].events.get("play", 0) == 3, "completed splashes record three play events")
	check(s.start_bath(), "puddle followed by existing bath")
	s.bath.stage = 3
	check(s.finish_bath(), "bath completes")
	check(s.pet.needs.hygiene == 100 and s.pet.needs.energy == 79, "bath retains existing cost and bounded wash")
	var loaded: PetState = s.storage.load_pet().pet
	check(loaded.pet_id == before.pet_id and loaded.milestones.has("water_puddle"), "identity and first water memory survive reload")
	s.free()
	s = game()
	s.water.start(s, "sprinkler")
	s.destination_reached()
	crossing(s)
	check(s.pet.needs.hygiene == 97, "sprinkler dirt is gentler")
	check(s.water.shake(s), "manual finish shakes")
	s.water.advance(s, 1.9)
	check(s.last_message.contains("czesanie") and not s.start_bath(), "clean water does not force free bath")
	s.free()
	s = game()
	s.water.start(s, "puddle")
	s.destination_reached()
	s.water.splash(s)
	s.change_yard(false)
	s.destination_reached()
	check(s.pet.needs.hygiene == 100 and not s.water.active(), "cancelled crossing has no cost")
	s.in_yard = true
	s.water.start(s, "puddle")
	s.destination_reached()
	crossing(s)
	s.suspend_session()
	check(not s.in_yard and not s.water.active() and s.pet.needs.hygiene == 88, "background keeps earned dirt and clears effects")
	s.free()
	s = game()
	s.water.start(s, "puddle")
	s.destination_reached()
	s.water.splash(s)
	s.storage = SaveSystem.new("/dev/null/pet.json")
	before = s.pet.to_dict()
	s.destination_reached()
	check(s.pet.to_dict() == before and not s.water.active(), "save failure rolls back this crossing and closes round")
	s.free()
	s = game()
	s.pet.needs.energy = 44
	check(not s.water.start(s, "puddle"), "reserve energy for bath")
	s.pet.needs.energy = 90
	s.pet.needs.fullness = 29
	check(not s.water.start(s, "puddle"), "hungry dog waits")
	s.pet.needs.fullness = 78
	s.outdoor_commands.offer_recall(Vector2(700, 310))
	check(not s.water.start(s, "puddle"), "pending fetch recall preserved")
	s.outdoor_commands.cancel()
	s.water.start(s, "puddle")
	s.pet.needs.energy = 27
	s._process(0.1)
	check(not s.in_yard and not s.water.active(), "tired dog leaves water and returns home")
	s.free()
	s = game()
	s.water.start(s, "puddle")
	s.local_clock = func(): return 100 * 86400.0 + 23 * 3600
	s._process(0.1)
	check(not s.water.active(), "night stops water")
	check(not s.water.start(s, "puddle"), "no night splashing")
	s._process(30)
	check(not s.in_yard, "night return still happens")
	s.free()
	s = game()
	s.water.start(s, "puddle")
	s.water.advance(s, 61)
	check(s.water.phase == "shake", "idle timeout starts safe finish")
	s.water.advance(s, 1.9)
	check(not s.water.active() and s.pet.needs.hygiene == 100, "timeout has no fake rewards")
	s.free()
	print("WATER RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
