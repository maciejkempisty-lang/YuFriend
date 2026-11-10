class_name TrainingSystem
extends RefCounted

const LABELS := {"come": "Przyjdź", "sit": "Siad", "paw": "Podaj łapę"}
const REWARDS := ["treat", "praise", "play"]
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
	if key == "paw" and float(pet.skills.sit.mastery) < 25:
		return "Najpierw poćwicz siad — do 25%."
	return ""

func begin(pet: PetState, key: String, use_guidance: bool, roll: float = -1.0) -> Dictionary:
	var reason := readiness(pet, key)
	if not reason.is_empty(): return {"ok": false, "message": reason}
	trick = key
	guided = use_guidance
	phase = "attempt"
	trial_id += 1
	# Include time for a seated/standing transition before the main trick.
	time_left = (2.8 if key == "paw" else 2.0) + (1.0 - float(pet.traits.patience)) * 0.4
	reward_duration = 2.7 + float(pet.traits.patience) * 0.7
	var distraction := pet.fatigue * (0.0008 + float(pet.traits.sensitivity) * 0.0012)
	var chance := clampf(0.16 + float(pet.skills[key].mastery) * 0.007 + pet.bond * 0.001 - distraction, 0.12, 0.96)
	will_succeed = guided or (randf() if roll < 0 else roll) < chance
	pet.skills[key].attempts = int(pet.skills[key].attempts) + 1
	pet.fatigue = minf(100, pet.fatigue + 12)
	NeedsSystem.change(pet, {"energy": -2})
	return {"ok": true, "message": "Pokaż spokojnie gest i zaczekaj…" if guided else "Sprawdźmy, czy pamięta komendę…"}

func advance(seconds: float, performance_done: bool = true) -> Dictionary:
	if phase == "idle" or seconds <= 0: return {}
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
			return {"event": "miss", "message": "Jeszcze się uczy. Spróbuj z naprowadzaniem."}
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
	var gain := (8.0 if guided else 12.0) + (2.0 if favorite else 0.0)
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
	return {"ok": true, "gain": float(pet.skills[trick].mastery) - before,
		"message": "To jego ulubiona nagroda!" if favorite else "Dobrze wyczuty moment. Zapamiętuje!"}

func cancel() -> void:
	phase = "idle"
	time_left = 0
	trial_id += 1
