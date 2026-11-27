class_name YardWater
extends RefCounted

static func spots() -> Dictionary:
	return {"puddle": RoomLayout.yard_stand("puddle"), "sprinkler": RoomLayout.yard_stand("sprinkler")}
const LABELS := {"puddle": "Kałuża", "sprinkler": "Zraszacz"}
const MAX_SPLASHES := 3
var kind := ""
var phase := ""
var splashes := 0
var remaining := 0.0
var phase_left := 0.0
var cooldown := 0.0

func active() -> bool:
	return not kind.is_empty()

func readiness(s: GameSession) -> String:
	if not s.in_yard or not s.writable or s.suspended or s.is_sleeping() or s.busy(false) or not s.outdoor_commands.phase.is_empty(): return "Zakończmy obecną czynność, potem zabawa w wodzie."
	if DailyRhythm.phase(s.pet, s._local_now()) == "night": return "Za ciemno na pluskanie. Pora odpocząć."
	if s.pet.needs.energy < 45: return "Najpierw odpoczynek. Zostawmy też energię na kąpiel."
	if s.pet.needs.fullness < 30: return "Najpierw posiłek, potem pluskanie."
	if cooldown > 0: return "Chwila przerwy od wody · jeszcze %d s." % ceili(cooldown)
	return ""

func start(s: GameSession, spot: String) -> bool:
	if not RoomLayoutLoader.allows("water", "yard", {"spot": spot}): return false
	if not spots().has(spot): return false
	var reason := readiness(s)
	if reason.is_empty(): reason = s.weather.water_reason(s, spot)
	if not reason.is_empty():
		s.say(reason)
		return false
	s._cancel_motion()
	s.invitation.clear()
	s._follow_target = Vector2.INF
	kind = spot
	phase = "approach"
	splashes = 0
	remaining = 60
	s.activity = "water"
	s.activity_left = 0
	s.pose = "stand"
	s.destination_requested.emit(spots()[kind] - Vector2(24, 0))
	s.clip_requested.emit("run")
	s.attention_requested.emit(false)
	s.say("%s! Za chwilę wybierz Plusk!" % LABELS[kind])
	s.changed.emit()
	return true

func hint() -> String:
	if phase == "approach": return "Biegnie do wody…"
	if phase == "run": return "Plusk! Biegnie przez wodę…"
	# The Plusk! button is disabled while the splash plays; do not ask for a tap.
	if phase == "splash": return "%s · %d/%d · plusk!" % [LABELS.get(kind, "Woda"), splashes, MAX_SPLASHES]
	if phase == "shake": return "Otrzepuje wodę. Błoto zostaje na sierści."
	return "%s · %d/%d · dotknij Plusk!" % [LABELS.get(kind, "Woda"), splashes, MAX_SPLASHES]

func splash(s: GameSession) -> bool:
	if phase != "ready" or not safe(s): return false
	phase = "run"
	s.activity_cancelled.emit()
	s.destination_requested.emit(spots()[kind] + Vector2(24 if splashes % 2 == 0 else -24, 0))
	s.clip_requested.emit("run")
	s.player_activity()
	s.changed.emit()
	return true

func safe(s: GameSession) -> bool:
	return s.in_yard and s.writable and not s.suspended and not s.is_sleeping() and s.pet.needs.energy >= 28 and DailyRhythm.phase(s.pet, s._local_now()) != "night"

func arrived(s: GameSession) -> void:
	if not active(): return
	if not safe(s):
		finish(s, "Wracamy do spokojniejszych zajęć.")
		return
	if phase == "approach":
		phase = "ready"
		s.clip_requested.emit("tail_wag_stand")
	elif phase == "run":
		# Each completed crossing commits immediately: leaving cannot undo the mud.
		var before := s.pet.to_dict()
		NeedsSystem.change(s.pet, {"play": 4, "energy": -2, "hygiene": -12 if kind == "puddle" else -3})
		s._note("play", false)
		s.pet.remember("water_" + kind, "Pierwsze pluski: " + LABELS[kind], "Woda, małe łapki i radosne otrzepywanie. Błoto zmyjemy w łazience.")
		if not s.flush():
			s.pet = PetState.from_dict(before)
			finish(s, "Nie udało się zapisać zabawy. Ten plusk nie zmienił potrzeb.")
			return
		s.yard_rest.note_play()
		splashes += 1
		cooldown = 60
		phase = "splash"
		phase_left = 0.7
		s.clip_requested.emit("play_bow")
	s.changed.emit()

func shake(s: GameSession) -> bool:
	if not active() or phase == "shake" or not safe(s): return false
	s.activity_cancelled.emit()
	phase = "shake"
	phase_left = 1.8
	s.clip_requested.emit("shake")
	s.changed.emit()
	return true

func advance(s: GameSession, delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	if not active(): return
	if not safe(s):
		finish(s, "Koniec pluskania. Czas odpocząć.")
		return
	remaining -= delta
	if phase in ["splash", "shake"]:
		phase_left -= delta
		if phase_left <= 0:
			if phase == "shake":
				finish(s)
				return
			if splashes >= MAX_SPLASHES: shake(s)
			else:
				phase = "ready"
				s.clip_requested.emit("tail_wag_stand")
	elif remaining <= 0: shake(s)

func cancel() -> void:
	kind = ""
	phase = ""
	splashes = 0
	remaining = 0
	phase_left = 0

func finish(s: GameSession, message: String = "") -> void:
	cancel()
	s._cancel_motion()
	s.activity = "idle"
	s.activity_left = 0
	s.clip_requested.emit("idle")
	if message.is_empty():
		message = "Woda strzepnięta! "
		if s.pet.needs.hygiene < 80:
			message += "Błotko zostało — wybierz Kąpiel." if s.bath_readiness().is_empty() else s.bath_readiness()
		else: message += "Sierść dość czysta — wystarczy czesanie."
	s.say(message)
	s.changed.emit()
