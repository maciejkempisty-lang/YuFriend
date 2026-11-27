class_name OutdoorCommands
extends RefCounted

var trial := TrainingSystem.new()
var key := ""
var phase := ""
var origin := Vector2.ZERO
var arrived := false
var offer_left := 0.0

func running() -> bool:
	return phase in ["perform", "praise"]
func cancel() -> void:
	trial.cancel()
	key = ""
	phase = ""
	arrived = false
	offer_left = 0
func offer_recall(point: Vector2) -> void:
	cancel()
	origin = point
	key = "come"
	phase = "offer"
	offer_left = 25
func available_key(s: GameSession) -> String:
	if not RoomLayoutLoader.allows("outdoor_commands", "yard"): return ""
	if not s.in_yard or s.suspended or not s.writable: return ""
	if running(): return key
	if phase == "offer": return "come"
	if s.hide_game.kind == "treat" and s.hide_game.phase == "choose" and not s.hide_game.stay_used: return "stay"
	return ""
func start(s: GameSession, guided: bool, roll: float = -1) -> bool:
	var command := available_key(s)
	if command.is_empty() or running() or s.is_sleeping() or s.training.phase != "idle": return false
	if command == "come" and s.busy(): return false
	if DailyRhythm.phase(s.pet, s._local_now()) == "night":
		s.say("Za ciemno na ćwiczenia, pora spać.")
		return false
	var before := s.pet.to_dict()
	PracticeSystem.sync(s.pet, s._local_now())
	var tired := s.pet.fatigue >= 50
	var result := trial.begin(s.pet, command, guided, roll)
	if not result.ok:
		s.say(result.message)
		return false
	s.record_training_start(guided, tired)
	if not s.flush():
		s.pet = PetState.from_dict(before)
		trial.cancel()
		return false
	# Cancel the old motion before marking this command active. The trial is
	# already prepared, so preserve it across the session's cancellation hook.
	var prepared := trial
	trial = TrainingSystem.new()
	s._cancel_motion()
	trial = prepared
	key = command
	phase = "perform"
	arrived = command == "stay" or not trial.will_succeed
	s.player_activity()
	s.activity = "yard_command"
	s.activity_left = 0
	s.pose = "sit" if command == "stay" and trial.will_succeed else "stand"
	if command == "stay": s.hide_game.stay_used = true
	if command == "come" and trial.will_succeed:
		s.destination_requested.emit(origin)
		s._travel_left = 90
		s.clip_requested.emit("walk")
	else: s.clip_requested.emit("sit_down" if trial.will_succeed else "head_tilt_stand")
	s.say("Przyjdź! Wracamy z piłką." if command == "come" else "Zostań… poczekaj spokojnie, zanim schowasz smakołyk.")
	s.changed.emit()
	return true
func advance(s: GameSession, delta: float) -> void:
	if s.suspended or not s.writable: return
	if not s.in_yard:
		cancel()
		return
	if phase == "offer":
		offer_left -= delta
		if offer_left <= 0: cancel()
		return
	if not running(): return
	var result := trial.advance(delta, arrived)
	if not result.is_empty(): s.record_training_outcome(result.event)
	if result.is_empty(): return
	if result.event == "ready":
		phase = "praise"
		s.clip_requested.emit("sit_idle" if key == "stay" else "idle")
		s.say("Udało się! Dotknij „Pochwal”, aby zaliczyć ćwiczenie.")
	else:
		var command := key
		var point := origin
		cancel()
		if command == "come": offer_recall(point)
		elif s.hide_game.phase == "choose": s.hide_game.stay_used = false
		s.activity = "hide" if s.hide_game.active() else "idle"
		s.say(result.message)
	s.changed.emit()
func praise(s: GameSession) -> bool:
	if phase != "praise" or not s.in_yard or s.suspended or not s.writable: return false
	var before := s.pet.to_dict()
	var command := key
	var old_form := PracticeSystem.form(s.pet, command)
	var result := trial.reward(s.pet, "praise", s._local_now())
	if not result.ok: return false
	s._note("reward_praise")
	var daily := PracticeSystem.record(s.pet, command, s._local_now())
	var adventure_completed := DailyAdventure.record(s.pet, "trick", s._local_now())
	cancel() # Consume the opportunity even if storage fails; no double reward.
	s.activity = "hide" if s.hide_game.active() else "idle"
	if not s.flush():
		s.pet = PetState.from_dict(before)
		s.changed.emit()
		return false
	s.sound_requested.emit("success")
	var message := "%s: forma %d%% (+%d)." % [TrainingSystem.LABELS[command], roundi(PracticeSystem.form(s.pet, command)), roundi(PracticeSystem.form(s.pet, command) - old_form)]
	if result.gain > 0: message += " Opanowanie +%d." % roundi(result.gain)
	if s.pet.practice.done.has(command): message += " Zaliczone na dziś."
	if result.mastered: message = "Umiem: %s! 100%%. " % TrainingSystem.LABELS[command] + message
	if adventure_completed: message += " Przygoda ukończona! Pamiątka w Albumie."
	if daily: message += " Miło poćwiczyć razem! +2 więzi."
	s.say(message)
	s.changed.emit()
	return true
