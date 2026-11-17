class_name YardRest
extends RefCounted

const BED := Vector2(220, 315)
const DRINK := Vector2(276, 319)
const BOWL := Vector2(330, 325)
var phase := ""
var elapsed := 0.0
var remaining := 0.0
var drink_stage := 0
var after_play := false
var idle_left := 6.0
var cooldown := 0.0
var then_rest := false

func active() -> bool: return not phase.is_empty()
func note_play() -> void:
	after_play = true
	idle_left = 6
func readiness(s: GameSession, kind: String) -> String:
	if kind not in ["bed", "drink"]: return ""
	if not s.in_yard or not s.writable or s.suspended or s.busy(false) or s.is_sleeping(): return "Dokończmy obecną czynność, potem chwila w cieniu."
	if DailyRhythm.phase(s.pet, s._local_now()) == "night": return "Na noc wracamy do legowiska w domu."
	if s.pet.needs.energy < 28: return "Bardzo zmęczone łapki — odpocznijmy w domu."
	if kind == "bed" and s.weather.kind(s) == "rain": return "Pada. Na drzemkę lepiej wrócić do domu."
	return ""
func start(s: GameSession, kind: String, chain: bool = false) -> bool:
	if kind not in ["bed", "drink"]: return false
	var reason := readiness(s, kind)
	if not reason.is_empty():
		s.say(reason)
		return false
	s._cancel_invitation()
	s._cancel_motion()
	s._follow_target = Vector2.INF
	after_play = false
	cooldown = 120
	then_rest = chain
	phase = "walk_bed" if kind == "bed" else "walk_drink"
	elapsed = 0
	remaining = 90
	s.activity = "yard_rest"
	s.activity_left = 0
	s.destination_requested.emit(BED if kind == "bed" else DRINK)
	s.clip_requested.emit("walk")
	s.attention_requested.emit(false)
	s.say("Chwila odpoczynku w cieniu." if kind == "bed" else "Kilka łyków świeżej wody.")
	s.changed.emit()
	return true
func arrived(s: GameSession) -> void:
	if phase == "walk_bed":
		var before := s.pet.to_dict()
		s.pet.resting = s.pet.needs.energy < NeedsSystem.WAKE_ENERGY
		if not s.flush():
			s.pet = PetState.from_dict(before)
			finish(s, "Nie udało się zapisać odpoczynku.")
			return
		phase = "rest"
		elapsed = 0
		s._sleep_elapsed = 0
		s.automatic_nap = false
		s.night_sleep = false
		s.activity = "sleep" if s.pet.resting else "yard_rest"
		s.clip_requested.emit("sleep" if s.pet.resting else "idle_lie")
	elif phase == "walk_drink":
		phase = "drink"
		elapsed = 0
		drink_stage = 0
		s.clip_requested.emit("eat_enter")
	s.changed.emit()
func advance(s: GameSession, delta: float) -> void:
	cooldown = maxf(0, cooldown - delta)
	if not active():
		if not s.in_yard:
			after_play = false
			return
		var idle := s.writable and not s.suspended and s.attention_available and not s.busy() and not s.is_sleeping() and s.activity == "idle" and s.invitation.is_empty() and s.outdoor_commands.phase.is_empty()
		if not idle:
			idle_left = 6
			return
		if not after_play and (s.pet.needs.energy >= 60 and s.pet.fatigue < 35): return
		if cooldown > 0 or s.pet.needs.energy < 28 or s.pet.needs.fullness < 30 or DailyRhythm.quiet(s.pet, s._local_now()) or s.weather.kind(s) == "rain": return
		idle_left -= delta
		if idle_left <= 0: start(s, "drink", true)
		return
	if s.suspended or not s.writable:
		return
	if not s.in_yard:
		cancel(s)
		return
	if DailyRhythm.phase(s.pet, s._local_now()) == "night" or (phase in ["walk_bed", "rest"] and s.weather.kind(s) == "rain"):
		return_home(s)
		return
	elapsed += delta
	remaining -= delta
	if remaining <= 0 and phase != "rest":
		finish(s, "Chwila przerwy. Możecie spróbować ponownie.")
		return
	if phase == "rest":
		if not s.pet.resting and elapsed >= 8: finish(s, "Miło poleżeć razem. Gotowa na dalszy dzień.")
		return
	if phase == "drink":
		var stage := 2 if elapsed >= 3.4 else (1 if elapsed >= 0.8 else 0)
		if stage != drink_stage:
			drink_stage = stage
			s.clip_requested.emit("eat_exit" if stage == 2 else "eat_loop")
			s.changed.emit()
		if elapsed >= 4.2:
			var rest_next := then_rest and s.weather.kind(s) != "rain"
			finish(s, "Woda wypita. Teraz chwila spokoju.")
			if rest_next: start(s, "bed")
func cancel(s: GameSession) -> void:
	if phase == "rest": s.pet.resting = false
	phase = ""
	then_rest = false
	elapsed = 0
	remaining = 0
func finish(s: GameSession, message: String = "Koniec przerwy w cieniu.") -> void:
	var was_resting := s.pet.resting and phase == "rest"
	cancel(s)
	s._cancel_motion()
	s.activity = "idle"
	s.activity_left = 0
	s._brain_left = 12
	s.clip_requested.emit("idle")
	if was_resting: s.flush()
	s.say(message)
	s.changed.emit()
func return_home(s: GameSession) -> bool:
	if not active() or not s.writable or s.suspended: return false
	var nap := phase in ["walk_bed", "rest"]
	# Clear runtime state before cancellation, preserving an existing nap.
	phase = ""
	then_rest = false
	after_play = false
	s._cancel_motion()
	s.in_yard = false
	s.night_sleep = DailyRhythm.phase(s.pet, s._local_now()) == "night"
	s.pet.resting = (nap or s.night_sleep) and s.pet.needs.energy < NeedsSystem.WAKE_ENERGY
	s.activity = "sleep" if s.is_sleeping() else "idle"
	s.activity_left = 0
	s._sleep_elapsed = 0
	s.say("Wracamy do domu. Tutaj można spokojnie odpocząć.")
	s.flush()
	s.changed.emit()
	s.place_requested.emit("rest")
	s.clip_requested.emit("sleep" if s.is_sleeping() else "idle")
	return true
func hint(s: GameSession) -> String:
	if phase == "walk_bed": return "Idzie do legowiska w cieniu…"
	if phase == "walk_drink": return "Idzie do miski z wodą…"
	if phase == "drink": return "Pije wodę · spokojna przerwa"
	return "Drzemka w cieniu · odzyskuje siły" if s.pet.resting else "Chwila leżenia w cieniu"
