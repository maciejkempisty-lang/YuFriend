class_name YardCourse
extends RefCounted

static func path() -> Array[Vector2]:
	var anchor := RoomLayout.yard_stand("course")
	var result: Array[Vector2] = []
	for offset in [Vector2(-210, 10), Vector2(-150, -28), Vector2(-90, 10), Vector2(-30, -28), Vector2(30, 0)]:
		result.append(RoomLayoutLoader.clamp_to_level(anchor + offset, "yard"))
	return result
static func landing() -> Vector2: return RoomLayout.yard_stand("landing")
static func podium() -> Vector2: return RoomLayout.yard_stand("podium")
var phase := ""
var step := 0
var remaining := 0.0
var trial := TrainingSystem.new()

func active() -> bool: return not phase.is_empty()
func readiness(s: GameSession, script_id: String = "course") -> String:
	if not RoomLayoutLoader.allows(script_id, "yard"): return "Brak toru w tym ogrodzie."
	if not s.in_yard or not s.writable or s.suspended or s.busy(false) or s.is_sleeping() or not s.outdoor_commands.phase.is_empty(): return "Dokończmy obecną czynność przed torem."
	if DailyRhythm.quiet(s.pet, s._local_now()): return "Tor odpoczywa wieczorem. Wrócimy za dnia."
	if s.pet.needs.energy < 45 or s.pet.needs.fullness < 30 or s.pet.fatigue >= 63: return "Najpierw odpoczynek i posiłek — tor wymaga sił."
	var locked := TrainingSystem.unlock_reason(s.pet, "stay")
	if not locked.is_empty(): return "Na podeście ćwiczymy Zostań. Najpierw " + locked + "."
	return ""
func start(s: GameSession) -> bool:
	var reason := readiness(s)
	if not reason.is_empty():
		s.say(reason)
		return false
	var before := s.pet.to_dict()
	NeedsSystem.change(s.pet, {"energy": -3, "hygiene": -2})
	if not s.flush():
		s.pet = PetState.from_dict(before)
		return false
	s._cancel_invitation()
	s._cancel_motion()
	s._follow_target = Vector2.INF
	s.player_activity()
	phase = "slalom"
	step = 0
	remaining = 120
	s.activity = "course"
	s.activity_left = 0
	move(s, path()[0])
	s.attention_requested.emit(false)
	s.say("Slalom! Potem wybierz Skacz przy płotku.")
	s.changed.emit()
	return true
func move(s: GameSession, target: Vector2) -> void:
	s.activity_cancelled.emit()
	s.destination_requested.emit(target)
	s.clip_requested.emit("run")
func arrived(s: GameSession) -> void:
	match phase:
		"slalom":
			step += 1
			if step < path().size(): move(s, path()[step])
			else:
				phase = "jump_ready"
				s.clip_requested.emit("idle")
		"jump":
			phase = "podium"
			move(s, podium())
		"podium":
			phase = "stay_ready"
			s.clip_requested.emit("idle")
	s.changed.emit()
func jump(s: GameSession) -> bool:
	if phase != "jump_ready" or not safe(s): return false
	phase = "jump"
	s.course_jump_requested.emit(landing())
	s.player_activity()
	s.changed.emit()
	return true
func stay(s: GameSession, guided: bool = true, roll: float = -1) -> bool:
	if phase != "stay_ready" or not safe(s): return false
	var before := s.pet.to_dict()
	PracticeSystem.sync(s.pet, s._local_now())
	var tired := s.pet.fatigue >= 50
	var result := trial.begin(s.pet, "stay", guided, roll)
	if not result.ok:
		s.pet = PetState.from_dict(before)
		s.say(result.message)
		return false
	s.record_training_start(guided, tired)
	if not s.flush():
		s.pet = PetState.from_dict(before)
		trial.cancel()
		finish(s, "Nie udało się zapisać ćwiczenia.")
		return false
	phase = "stay"
	s.clip_requested.emit("sit_down" if trial.will_succeed else "head_tilt_stand")
	s.player_activity()
	s.changed.emit()
	return true
func praise(s: GameSession) -> bool:
	if phase != "praise" or not safe(s): return false
	var before := s.pet.to_dict()
	var result := trial.reward(s.pet, "praise", s._local_now())
	if not result.ok: return false
	s._note("reward_praise")
	var daily := PracticeSystem.record(s.pet, "stay", s._local_now())
	DailyAdventure.record(s.pet, "trick", s._local_now())
	NeedsSystem.change(s.pet, {"play": 10})
	s.pet.remember("yard_course", "Pierwszy tor przeszkód", "Slalom, płotek i spokojne Zostań na podeście — razem do mety!")
	if not s.flush():
		s.pet = PetState.from_dict(before)
		finish(s, "Nie udało się zapisać mety. Nagroda nie została naliczona.")
		return false
	s.yard_rest.note_play()
	s.sound_requested.emit("success")
	finish(s, "Meta! Zostań zaliczone do wspólnego treningu. Pamiątka w Albumie." + (" +2 więzi za trening dnia." if daily else ""))
	return true
func safe(s: GameSession) -> bool:
	return s.in_yard and s.writable and not s.suspended and not s.is_sleeping() and s.pet.needs.energy >= 28 and not DailyRhythm.quiet(s.pet, s._local_now())
func advance(s: GameSession, delta: float) -> void:
	if not active(): return
	remaining -= delta
	if not safe(s) or remaining <= 0:
		finish(s, "Tor poczeka. Czas na spokojną przerwę.")
		return
	if phase in ["stay", "praise"]:
		var result := trial.advance(delta)
		if not result.is_empty(): s.record_training_outcome(result.event)
		if result.is_empty(): return
		if result.event == "ready":
			phase = "praise"
			s.clip_requested.emit("sit_idle")
		else:
			phase = "stay_ready"
			s.clip_requested.emit("idle")
			s.say(result.message)
		s.changed.emit()
func hint() -> String:
	return {"slalom": "Slalom · omija pachołki…", "jump_ready": "Płotek · dotknij Skacz", "jump": "Hop! Miękkie lądowanie…", "podium": "Idzie na podest…", "stay_ready": "Podest · Zostań z gestem", "stay": "Zostań… spokojnie czekamy", "praise": "Teraz! Pochwal za Zostań"}.get(phase, "Tor przeszkód")
func cancel() -> void:
	phase = ""
	trial.cancel()
	remaining = 0
func finish(s: GameSession, message: String) -> void:
	cancel()
	s._cancel_motion()
	s.activity = "idle"
	s.activity_left = 0
	s.clip_requested.emit("idle")
	s.say(message)
	s.changed.emit()
