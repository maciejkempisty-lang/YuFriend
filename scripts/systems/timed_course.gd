class_name TimedCourse
extends RefCounted

const CUE_AT := 1.5
const WINDOW := 0.35
const PENALTY := 1.5
const COMMANDS := ["Slalom", "Skacz", "Stój"]
var phase := ""
var phase_time := 0.0
var elapsed := 0.0
var segment := 0
var step := 0
var mistakes := 0
var judged := false
var missed := false
var stars := 0
var settled := false
var feedback := ""

func active() -> bool: return not phase.is_empty()
func can_cue() -> bool: return phase == "cue" and not judged
func cancel() -> void:
	phase = ""
	phase_time = 0
func start(s: GameSession) -> bool:
	var reason := s.course.readiness(s)
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
	elapsed = 0
	segment = 0
	step = 0
	mistakes = 0
	stars = 0
	settled = false
	feedback = ""
	_set_phase("countdown")
	s.activity = "timed_course"
	s.activity_left = 0
	s.clip_requested.emit("idle")
	s.attention_requested.emit(false)
	s.say("Tor na czas! Naciśnij komendę, gdy kółko dotrze do jasnego pola. Każdy błąd to 1,5 s postoju.")
	s.changed.emit()
	return true
func _set_phase(value: String) -> void:
	phase = value
	phase_time = 0
func _move(s: GameSession, point: Vector2) -> void:
	s.activity_cancelled.emit()
	s.destination_requested.emit(point)
	s.clip_requested.emit("run")
func _offer(s: GameSession) -> void:
	judged = false
	missed = false
	feedback = ""
	_set_phase("cue")
	s.clip_requested.emit("idle")
	s.changed.emit()
func cue(s: GameSession) -> bool:
	if not can_cue() or not s.course.safe(s): return false
	judged = true
	missed = absf(phase_time - CUE_AT) > WINDOW + 0.000001
	if missed: mistakes += 1
	feedback = "Za wcześnie · +1,5 s postoju" if missed else "Dobrze!"
	s.player_activity()
	s.changed.emit()
	return true
func arrived(s: GameSession) -> void:
	match phase:
		"approach": _offer(s)
		"slalom":
			step += 1
			if step < YardCourse.PATH.size(): _move(s, YardCourse.PATH[step])
			else:
				segment = 1
				_offer(s)
		"jump":
			_set_phase("podium")
			_move(s, YardCourse.PODIUM)
		"podium":
			segment = 2
			_offer(s)
func advance(s: GameSession, delta: float) -> void:
	if not active() or not is_finite(delta) or delta <= 0: return
	if not s.course.safe(s):
		finish(s, "Tor poczeka. Czas na spokojną przerwę.")
		return
	var left := minf(delta, 64)
	while left > 0 and active():
		var dt := minf(left, 0.01)
		left -= dt
		if phase not in ["countdown", "approach"]: elapsed += dt
		phase_time += dt
		if elapsed >= 60 or (phase == "approach" and phase_time >= 60):
			finish(s, "Limit 60 s. Spróbujemy ponownie po odpoczynku.")
			return
		if phase == "countdown" and phase_time >= 3:
			_set_phase("approach")
			_move(s, YardCourse.PATH[0])
		elif phase == "cue" and phase_time >= CUE_AT + WINDOW:
			if not judged:
				judged = true
				missed = true
				mistakes += 1
				feedback = "Za późno · +1,5 s postoju"
			if missed:
				_set_phase("penalty")
				s.clip_requested.emit("head_tilt_stand")
			else: _proceed(s)
		elif phase == "penalty" and phase_time >= PENALTY: _proceed(s)
		elif phase == "finish" and phase_time >= 0.6: _complete(s)
func _proceed(s: GameSession) -> void:
	match segment:
		0:
			step = 1
			_set_phase("slalom")
			_move(s, YardCourse.PATH[step])
		1:
			_set_phase("jump")
			s.course_jump_requested.emit(YardCourse.LANDING)
		2:
			_set_phase("finish")
			s.clip_requested.emit("sit_down")
	s.changed.emit()
func _complete(s: GameSession) -> void:
	if settled or phase != "finish": return
	settled = true
	stars = 3 if mistakes == 0 else (2 if mistakes == 1 else 1)
	var before := s.pet.to_dict()
	var now := Time.get_unix_time_from_system()
	s.pet.social.games.ball = mini(PetState.MAX_EVENT_COUNT, int(s.pet.social.games.ball) + 1)
	if now - float(s.pet.social.last_reward_at) >= TouchPlaySystem.REWARD_INTERVAL:
		s.pet.social.last_reward_at = now
		NeedsSystem.change(s.pet, {"play": 12, "contact": 4})
		BondLevels.add(s.pet, 0.35, s._local_now())
		s._note("play")
	s.pet.remember("timed_course", "Pierwszy tor na czas", "Slalom, skok i zatrzymanie na mecie — wspólny przejazd.", now)
	if not s.flush():
		s.pet = PetState.from_dict(before)
		finish(s, "Nie zapisano wyniku. Nagroda nie została naliczona.")
		return
	var written := SkillRecords.write_course(s.storage.path, elapsed, stars)
	var record := SkillRecords.read(s.storage.path, "agility")
	var message := "Meta! %.1f s · %d/3 gwiazdki · błędy: %d.\nCzas zawiera postoje za błędy.\n%s" % [elapsed, stars, mistakes, "Rekord: %.1f s." % record.seconds if written else "Nie udało się zapisać rekordu."]
	s.yard_rest.note_play()
	s.sound_requested.emit("success")
	finish(s, message)
	s.timed_course_finished.emit(message)
func finish(s: GameSession, message: String) -> void:
	cancel()
	s._cancel_motion()
	s.activity = "idle"
	s.activity_left = 0
	s._brain_left = maxf(s._brain_left, 8)
	s.clip_requested.emit("idle")
	s.say(message)
	s.changed.emit()
func hint() -> String:
	if phase == "countdown": return "Tor na czas · start za %d" % maxi(1, ceili(3 - phase_time))
	if phase == "cue": return "%.1f s · %s · %s" % [elapsed, COMMANDS[segment], feedback if judged else ("TERAZ!" if absf(phase_time - CUE_AT) <= WINDOW else "poczekaj na jasne pole")]
	if phase == "penalty": return "%.1f s · %s" % [elapsed, feedback]
	return "%.1f s · %s · błędy: %d" % [elapsed, {"approach": "Do startu", "slalom": "Slalom", "jump": "Skok", "podium": "Do mety", "finish": "Meta"}.get(phase, "Tor"), mistakes]
