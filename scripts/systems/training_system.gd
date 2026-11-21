class_name TrainingSystem
extends RefCounted

const LABELS := {"come": "Przyjdź", "sit": "Siad", "paw": "Podaj łapę", "lie": "Leżeć", "bow": "Ukłon", "bark": "Głos", "stay": "Zostań", "spin": "Kręć się", "roll": "Turlaj się"}
const PREREQUISITES := {"lie": "sit", "bow": "lie", "bark": "paw", "stay": "sit", "spin": "bow", "roll": "lie"}

static func unlock_reason(pet: PetState, key: String) -> String:
	# Existing progress always keeps a previously practiced trick available.
	if float(pet.skills[key].mastery) > 0 or int(pet.skills[key].attempts) > 0: return ""
	if key == "paw" and float(pet.skills.sit.mastery) < 25: return "Siad: 25%"
	if PREREQUISITES.has(key):
		var required: String = PREREQUISITES[key]
		if float(pet.skills[required].mastery) < 100: return "%s: 100%%" % LABELS[required]
	return ""

const REWARDS := ["treat", "praise", "play"]
# Marker timing is measured from the rendered sitting-contact frame, not a trial timer.
const MARKER_PREPARE_SECONDS := 1.2
var marker_prepare_left := 0.0
var marker_mode := false
var marker_gentle := false
var marker_grade := ""
var marker_contact_at := -1.0
var marker_clock: Callable = func(): return Time.get_ticks_usec() / 1000000.0
var phase: String = "idle"
var trick: String = ""
var guided: bool = true
var time_left: float = 0.0
var reward_duration: float = 3.0
var will_succeed: bool = false
var trial_id: int = 0

func readiness(pet: PetState, key: String) -> String:
	if not LABELS.has(key): return "Nie znam takiej komendy."
	if phase != "idle": return "Dokończmy najpierw tę próbę."
	if pet.resting: return "Najpierw obudź pieska."
	if float(pet.needs.energy) < 25: return "Najpierw chwila odpoczynku."
	if float(pet.needs.fullness) < 25: return "Najpierw coś do jedzenia."
	if pet.fatigue >= 75: return "Czas na przerwę od ćwiczeń."
	var locked := unlock_reason(pet, key)
	if not locked.is_empty(): return "Odblokowanie: " + locked
	return ""

func begin(pet: PetState, key: String, use_guidance: bool, roll: float = -1.0, use_marker: bool = false, gentle: bool = false) -> Dictionary:
	var reason := readiness(pet, key)
	if not reason.is_empty(): return {"ok": false, "message": reason}
	marker_mode = use_marker and key == "sit"
	marker_prepare_left = MARKER_PREPARE_SECONDS if marker_mode else 0.0
	marker_gentle = gentle
	marker_grade = ""
	marker_contact_at = -1.0
	trick = key
	guided = use_guidance
	phase = "attempt"
	trial_id += 1
	# Include time for a seated/standing transition before the main trick.
	time_left = (2.8 if key == "paw" else 2.0) + (1.0 - float(pet.traits.patience)) * 0.4
	reward_duration = (2.7 + float(pet.traits.patience) * 0.7)
	var distraction := pet.fatigue * (0.0008 + float(pet.traits.sensitivity) * 0.0012)
	var chance := clampf(0.16 + float(pet.skills[key].mastery) * 0.007 + pet.bond * 0.001 - distraction, 0.12, 0.96)
	chance *= 0.5 + 0.5 * PracticeSystem.form(pet, key) / 100.0
	will_succeed = marker_mode or guided or (randf() if roll < 0 else roll) < chance
	pet.skills[key].attempts = int(pet.skills[key].attempts) + 1
	pet.fatigue = minf(100, pet.fatigue + 12)
	NeedsSystem.change(pet, {"energy": -2})
	return {"ok": true, "message": "Przygotuj się. Obserwuj pupę pieska — ruch za chwilę." if marker_mode else ("Pokaż spokojnie gest i zaczekaj…" if guided else "Sprawdźmy, czy pamięta komendę…")}

func advance(seconds: float, performance_done: bool = true) -> Dictionary:
	if phase == "idle" or seconds <= 0: return {}
	if marker_mode:
		if phase == "reward": return {} # Marking is the skill; feeding is not another timer.
		if marker_prepare_left > 0:
			marker_prepare_left = maxf(0, marker_prepare_left - seconds)
			if marker_prepare_left == 0:
				return {"event": "marker_start", "message": "Patrz na ruch. Kliknij, gdy pupa dotknie podłogi."}
			return {}
		time_left -= seconds
		if marker_contact_at >= 0 and float(marker_clock.call()) - marker_contact_at > marker_window():
			phase = "idle"
			marker_grade = "missed"
			return {"event": "marker_miss", "message": "Nie było kliknięcia. Kliknij, gdy pupa dotknie podłogi."}
		if marker_contact_at < 0 and time_left < -12:
			phase = "idle"
			return {"event": "marker_miss", "message": "Ruch nie dobiegł końca. Rozpocznij nową próbę."}
		return {}
	time_left -= seconds
	# Presentation can take longer than the puppy's minimum reaction time.
	# Wait for the animation/movement without consuming the reward window.
	if phase == "attempt" and not performance_done:
		time_left = maxf(0, time_left)
		return {}
	if time_left > 0: return {}
	var overrun := -time_left
	if phase == "attempt":
		if not will_succeed:
			phase = "idle"
			return {"event": "miss", "message": "Hmm, jak to szło? Spróbuj z podpowiedzią."}
		# A stalled frame cannot grant a fresh full reward window after it expired.
		if overrun >= reward_duration:
			phase = "idle"
			return {"event": "expired", "message": "Okazja minęła. Zrobimy kolejną próbę."}
		phase = "reward"
		time_left = reward_duration - overrun
		return {"event": "ready", "message": "Udało się! Teraz nagródź pieska."}
	phase = "idle"
	return {"event": "expired", "message": "Nagroda przyszłaby za późno. Spróbuj ponownie."}

func reward(pet: PetState, kind: String) -> Dictionary:
	if phase != "reward" or time_left <= 0 or not REWARDS.has(kind):
		return {"ok": false, "message": "Nagródź zaraz po poprawnym wykonaniu."}
	# Consume eligibility before mutating any persistent data (one reward per trial).
	phase = "idle"
	var favorite := kind == pet.favorite_reward
	if favorite:
		pet.remember("favorite_reward", "Ulubiona nagroda", "Już wiesz, co najbardziej cieszy Twojego pieska: %s." % {"treat": "smakołyk", "praise": "pochwała", "play": "zabawa"}[kind])
	var gain := (10.0 if marker_grade == "perfect" else 6.0) if marker_mode else (8.0 if guided else 12.0) + (2.0 if favorite else 0.0)
	var before: float = pet.skills[trick].mastery
	pet.skills[trick].mastery = minf(100, before + gain)
	pet.skills[trick].successes = int(pet.skills[trick].successes) + 1
	pet.bond = minf(100, pet.bond + (1.5 if favorite else 1.0))
	if kind == "treat": NeedsSystem.change(pet, {"fullness": 2})
	if kind == "praise": NeedsSystem.change(pet, {"contact": 4})
	if kind == "play": NeedsSystem.change(pet, {"play": 4})
	pet.remember("first_" + trick, "Pierwsze „%s”" % LABELS[trick], "Dobry moment nagrody pomógł zapamiętać ćwiczenie.")
	if before < 75 and float(pet.skills[trick].mastery) >= 75:
		pet.remember("learned_" + trick, "Coraz pewniejsze „%s”" % LABELS[trick], "Wspólne ćwiczenia przynoszą efekty.")
	var mastered := before < 100 and float(pet.skills[trick].mastery) >= 100
	if mastered:
		pet.practice.forms[trick].value = 100.0
		pet.remember("mastered_" + trick, "Umiem: %s!" % LABELS[trick], "Wspólnie osiągnęliście 100% opanowania.")
	return {"ok": true, "mastered": mastered, "gain": float(pet.skills[trick].mastery) - before,
		"message": (("Idealnie!" if marker_grade == "perfect" else "Dobrze!") + " Nagroda podana. Jeszcze jedna próba?") if marker_mode else ("To ulubiona nagroda!" if favorite else "Dobrze wyczuty moment. Zapamiętuje!")}

func marker_window() -> float:
	return 1.0 if marker_gentle else 0.65

func sitting_contact(id: int) -> void:
	if marker_mode and marker_prepare_left <= 0 and phase == "attempt" and id == trial_id and marker_contact_at < 0:
		marker_contact_at = float(marker_clock.call())

func mark_sit() -> Dictionary:
	if not marker_mode or phase != "attempt": return {"ok": false, "message": "Najpierw rozpocznij próbę Siad."}
	if marker_prepare_left > 0: return {"ok": false, "message": "Jeszcze czekaj — ruch zacznie się za chwilę."}
	var elapsed := float(marker_clock.call()) - marker_contact_at
	if marker_contact_at < 0 or elapsed < 0:
		phase = "idle"
		marker_grade = "early"
		return {"ok": false, "message": "Za wcześnie. Kliknij dopiero, gdy pupa dotknie podłogi."}
	if elapsed > marker_window():
		phase = "idle"
		marker_grade = "late"
		return {"ok": false, "message": "Za późno. Kliknij przy siadaniu, nie gdy pies już siedzi."}
	marker_grade = "perfect" if elapsed <= (0.3 if marker_gentle else 0.18) else "good"
	phase = "reward"
	time_left = INF
	return {"ok": true, "message": ("Idealnie — klik w chwili siadu." if marker_grade == "perfect" else "Dobrze — siad rozpoznany.") + " Teraz nagroda, bez pośpiechu."}

func cancel() -> void:
	marker_prepare_left = 0
	marker_mode = false
	marker_contact_at = -1
	phase = "idle"
	time_left = 0
	trial_id += 1
