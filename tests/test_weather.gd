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
	s.storage = SaveSystem.new("/tmp/yuf-weather-%s/pet.json" % Time.get_ticks_usec())
	s.storage.save_pet(s.pet)
	s.pet = s.storage.load_pet().pet
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	s.pet.needs.energy = 90
	s.pet.needs.fullness = 90
	s.active = true
	s.in_yard = true
	s._brain_left = INF
	return s
func _initialize() -> void:
	var s := game()
	var stable := s.weather.kind(s)
	check(stable == "rain" and s.weather.kind(s) == stable, "weather repeatable for same local day and seed")
	for day in 4:
		s.local_clock = func(): return (100 + day) * 86400.0 + 12 * 3600
		check(s.weather.kind(s) == ["rain", "after_rain", "sun", "sun"][day], "calendar sequence")
	s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
	s.pet.yard_routines.plant = "daisy"
	var before := s.pet.to_dict()
	var now := 100 * 86400.0 + 12 * 3600
	check(s.weather.water_garden(s, now), "rain waters garden")
	check(s.pet.yard_routines.growth == 0, "rain grants no instant growth")
	check(s.pet.yard_routines.watered_day == 100, "rain shares calendar watering slot")
	check(not YardRoutines.can_water(s, now), "manual watering cannot stack with rain")
	var wet := s.pet.yard_routines.duplicate(true)
	check(not s.weather.water_garden(s, now + 50) and wet == s.pet.yard_routines, "repeated rain is idempotent")
	YardRoutines.update(s.pet.yard_routines, now + 3600)
	check(s.pet.yard_routines.growth == 3600, "existing real time growth only once")
	check(not s.weather.water_garden(s, now - 100), "rollback cannot rewater")
	for key in before:
		if key not in ["yard_routines", "last_seen_at"]: check(before[key] == s.pet.to_dict()[key], "rain preserves " + key)
	s.flush()
	check(JSON.parse_string(JSON.stringify(s.storage.load_pet().pet.yard_routines)) == JSON.parse_string(JSON.stringify(s.pet.yard_routines)), "rain survives reload")
	s.weather.override_kind = "sun"
	check(not s.water.start(s, "puddle") and s.last_message.contains("wyschła"), "dry puddle explains weather")
	check(s.water.start(s, "sprinkler"), "sun permits sprinkler")
	s.water.finish(s)
	s.weather.override_kind = "rain"
	check(not s.water.start(s, "sprinkler") and s.last_message.contains("Deszcz"), "rain pauses sprinkler")
	check(s.water.start(s, "puddle"), "rain permits puddle")
	s.water.finish(s)
	s.weather.override_kind = "after_rain"
	check(s.weather.water_reason(s, "puddle").is_empty(), "puddle persists after rain")
	var snapshot := s.pet.to_dict()
	check(s.offer_initiative("yard_puddle", now), "offer water invitation")
	check(s.activity == "initiative" and not s.busy(), "invitation is interruptible")
	check(CompanionVoice.new().describe(s).kind == "invitation", "voice recognizes yard invitation")
	s.destination_reached()
	check(s.invitation.arrived, "invitation reaches its yard station")
	check(s.accept_invitation() and s.water.kind == "puddle", "accept starts actual water game")
	check(s.pet.needs == snapshot.needs and s.pet.bond == snapshot.bond, "no reward before water crossing")
	s.water.finish(s)
	s.pet.social.last_offer_at = 0
	check(s.offer_initiative("yard_hide", now), "offer hide")
	snapshot = s.pet.to_dict()
	s.decline_invitation()
	for key in snapshot:
		if key != "last_seen_at": check(s.pet.to_dict()[key] == snapshot[key], "declining is harmless: " + key)
	check(not s.offer_initiative("yard_ball", now + 1), "shared cooldown prevents invitation spam")
	s.pet.social.last_offer_at = 0
	check(s.offer_initiative("yard_hide", now), "offer hide again")
	check(s.accept_invitation() and s.hide_game.active(), "accepted hide uses existing game")
	check(s.pet.social.responses.cups.accepted == 1, "accepted search learns existing preference")
	s.cancel_hide()
	s.pet.social.last_offer_at = 0
	check(s.offer_initiative("yard_ball", now), "offer fetch")
	var aimed := [false]
	s.ball_aim_requested.connect(func(): aimed[0] = true)
	check(s.accept_invitation() and aimed[0], "accepted fetch opens throw control")
	s.pet.needs.energy = 27
	check(YardInvitations.options(s).is_empty(), "tired dog never proposes play")
	s.pet.needs.energy = 90
	s.local_clock = func(): return 100 * 86400.0 + 23 * 3600
	check(YardInvitations.options(s).is_empty(), "night never proposes yard play")
	s.free()
	s = game()
	s.weather.override_kind = "after_rain"
	s._initiative_wait = 0
	s._spontaneous()
	check(not s.invitation.is_empty(), "autonomous brain makes a yard offer")
	var learned: Dictionary = s.pet.social.responses.duplicate(true)
	s._finish_invitation("ignored")
	check(s.pet.social.responses == learned, "ignored offer does not lower preferences")
	s.pet.social.last_offer_at = 0
	check(s.offer_initiative("yard_puddle", now), "water offer before weather change")
	s.weather.override_kind = "sun"
	s.weather.check_left = 0
	s.weather.advance(s, 0.1)
	check(s.invitation.is_empty(), "weather change withdraws obsolete offer")
	s.pet.social.last_offer_at = 0
	check(s.offer_initiative("yard_ball", now), "fetch offer before background")
	check(s.start_sniff(), "player sniff overrides invitation")
	check(s.invitation.is_empty(), "new activity clears invitation without penalty")
	s.destination_reached()
	check(s.activity == "sniff", "arrival belongs to selected activity")
	s.suspend_session()
	check(s.invitation.is_empty() and not s.in_yard, "background clears outdoor offer")
	s.free()
	s = game()
	s.pet.yard_routines.plant = "poppy"
	s.weather.override_kind = "rain"
	s.storage = SaveSystem.new("/dev/null/no-save.json")
	snapshot = s.pet.to_dict()
	check(not s.weather.water_garden(s, now) and JSON.parse_string(JSON.stringify(s.pet.to_dict())) == JSON.parse_string(JSON.stringify(snapshot)), "failed rain save rolls back")
	check(not s.offer_initiative("yard_puddle", now) and s.invitation.is_empty(), "failed offer save produces no invitation")
	s.free()
	print("WEATHER RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
