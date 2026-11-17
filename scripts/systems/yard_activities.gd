class_name YardActivities
extends RefCounted

static func change_yard(s: GameSession, enabled: bool) -> bool:
	if enabled and DailyRhythm.phase(s.pet, s._local_now()) == "night":
		s.say("Za ciemno, pora spać.")
		return false
	if s.in_bath: return false
	if not s.writable or s.suspended or s.is_sleeping() or s.training.phase != "idle": return false
	if enabled and s.busy(): return false
	s.cancel_touch_game()
	s._cancel_motion()
	s.invitation.clear()
	s._yard_dark_idle = 0
	s._follow_target = Vector2.INF
	s.in_yard = enabled
	s.activity = "idle"
	s.activity_left = 0
	s.pose = "stand"
	s.clip_requested.emit("idle")
	s.say("Podwórko! Rzuć piłkę albo poszukaj zapachu." if enabled else "Znów w domu.")
	s.changed.emit()
	return true


static func start_sniff(s: GameSession, spot: int = -1) -> bool:
	if not s.in_yard or not s.writable or s.suspended or s.busy() or s.is_sleeping() or spot < -1 or spot >= s.YARD_FINDS.size(): return false
	if float(s.pet.needs.energy) < 25:
		s.say("Najpierw wróćmy do domu odpocząć.")
		return false
	s._cancel_motion()
	s.sniff_spot = 0
	for index in s.YARD_FINDS.size():
		if not s.pet.milestones.has("yard_find_%d" % index):
			s.sniff_spot = index
			break
	if spot >= 0: s.sniff_spot = spot
	s._travel_left = 90.0
	s.activity = "sniff_walk"
	s.activity_left = 0
	s.destination_requested.emit(Vector2(350 + s.sniff_spot * 400, 302))
	s.clip_requested.emit("walk")
	s.say("Prowadzi mnie ciekawy zapach…")
	s.changed.emit()
	return true


static func _finish_sniff(s: GameSession) -> void:
	if not s.in_yard or s.sniff_spot < 0 or s.suspended or not s.writable: return
	NeedsSystem.change(s.pet, {"hygiene": -8})
	var key := "yard_find_%d" % s.sniff_spot
	var label: String = s.YARD_FINDS[s.sniff_spot]
	var fresh := not s.pet.milestones.has(key)
	if fresh:
		s.pet.remember(key, "Znalezisko: " + label, "Pierwszy skarb odkryty podczas węszenia na podwórku.")
		NeedsSystem.change(s.pet, {"play": 5, "energy": -2})
		s.sound_requested.emit("success")
	s.sniff_spot = -1
	s.activity = "idle"
	s.activity_left = 0
	s.clip_requested.emit("tail_wag_stand")
	s.say("Znalezione: %s! Pamiątka czeka w Albumie." % label if fresh else "Znajomy zapach. Ten skarb jest już w Albumie — sprawdź też pozostałe krzaki.")
	s.flush()
	s.changed.emit()


static func _tick_yard(s: GameSession, delta: float) -> void:
	if not s.writable or s.suspended: return
	if s._return_tired(): return
	if DailyRhythm.phase(s.pet, s._local_now()) != "night" or s.busy():
		s._yard_dark_idle = 0
		return
	s._yard_dark_idle += delta
	if s._yard_dark_idle < 30: return
	if s.change_yard(false):
		s._start_behavior("night")
		s.say("Za ciemno. Wracamy do domu, pora spać.")


static func start_hide(s: GameSession, kind: String, seed_value: int = 0) -> bool:
	if not s.in_yard: return false
	var reason := s.play_readiness()
	if not reason.is_empty():
		s.say(reason)
		return false
	if DailyRhythm.phase(s.pet, s._local_now()) == "night":
		s.say("Za ciemno na chowanego, pora spać.")
		return false
	if not s.hide_game.start(kind, seed_value): return false
	s.player_activity()
	s._cancel_invitation()
	s._cancel_motion()
	s._follow_target = Vector2.INF
	s.activity = "hide"
	s.activity_left = 0
	s.pose = "stand"
	s.clip_requested.emit("idle")
	s.say(s.hide_game.hint())
	s.changed.emit()
	return true


static func choose_hide_bush(s: GameSession, spot: int) -> bool:
	if s.outdoor_commands.running(): return false
	if not s.writable or s.suspended or not s.in_yard or not s.hide_game.active(): return false
	var event := s.hide_game.select(spot)
	if event.is_empty(): return false
	s.player_activity()
	s._handle_hide_event(event)
	return true


static func _tick_hide(s: GameSession, delta: float) -> void:
	if not s.writable or s.suspended or not s.hide_game.active(): return
	s._handle_hide_event(s.hide_game.advance(delta))


static func _handle_hide_event(s: GameSession, event: String) -> void:
	if event.is_empty(): return
	match event:
		"timeout":
			s.cancel_hide()
			s.say("Chowany poczeka. Piesek wrócił — możecie zacząć jeszcze raz.")
		"walk":
			s._cancel_motion()
			s.activity = "hide_walk"
			s.activity_left = 0
			s._travel_left = 90
			s.destination_requested.emit(Vector2(350 + s.hide_game.search_spot() * 400, 302))
			s.clip_requested.emit("walk")
			s.say(s.hide_game.hint())
		"guess": s.say(s.hide_game.hint())
		"wrong": s.say("Tutaj go nie ma. Rozejrzyj się za machającym ogonem!")
		"found": s._finish_hide()
	s.changed.emit()


static func _finish_hide(s: GameSession) -> void:
	if s.hide_game.phase != "found" or not s.writable or s.suspended: return
	var mode := s.hide_game.kind
	var spot := s.hide_game.hiding_spot
	s.hide_game.reset() # Consume the result before emitting any signals or granting rewards.
	s._cancel_motion()
	s._follow_target = Vector2.INF
	if mode == "dog": s.hide_revealed.emit(spot)
	var now := Time.get_unix_time_from_system()
	var rewarded := now - float(s.pet.social.last_reward_at) >= TouchPlaySystem.REWARD_INTERVAL
	if rewarded:
		s.pet.social.last_reward_at = maxf(float(s.pet.social.last_reward_at), now)
		s._apply_care_effects("play", {"play": 12, "contact": 6, "energy": -2})
		s.pet.bond = minf(100, s.pet.bond + 0.5)
		s._note("play")
	s.pet.remember("yard_hide_" + mode, "Smakołyk w krzakach" if mode == "treat" else "Ogon zdradził kryjówkę", "Pierwsza ukończona runda chowanego na podwórku.", now)
	s.activity = "happy"
	s.activity_left = 1.4
	s.clip_requested.emit("tail_wag_stand")
	s.sound_requested.emit("success")
	s.say(("Smakołyk znaleziony!" if mode == "treat" else "Jest piesek! Ogon go zdradził!") + (" +0,5 więzi." if rewarded else " Brawo! Nagrody odpoczywają 30 s."))
	s.flush()
	s.changed.emit()


static func cancel_hide(s: GameSession) -> void:
	if not s.hide_game.active(): return
	s.hide_game.reset()
	s._cancel_motion()
	s._follow_target = Vector2.INF
	s.activity = "idle"
	s.activity_left = 0
	s.clip_requested.emit("idle")
	s.changed.emit()


static func _return_tired(s: GameSession) -> bool:
	if not s.in_yard or s.busy() or float(s.pet.needs.energy) >= 28: return false
	if not s.change_yard(false): return false
	s.act("rest", false)
	s.say("Łapki potrzebują odpoczynku. Wracamy do legowiska.")
	return true
