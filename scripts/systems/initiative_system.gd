class_name InitiativeSystem
extends RefCounted

const OFFER_INTERVAL := 300.0
const RESPONSE_SECONDS := 30.0
const LABELS := {"ball": "Piłka", "tug": "Przeciąganie liny", "cups": "Szukanie smakołyka", "cuddle": "Bliskość"}
const RESPONSES := {"accepted": "wspólna chwila", "declined": "później", "ignored": "własne sprawy"}

static func weights(pet: PetState) -> Dictionary:
	var result := {}
	for kind in PetState.INITIATIVE_KEYS:
		result[kind] = 0.3 + float(pet.social.responses[kind].interest) * 2.0
	result.ball += float(pet.traits.curiosity)
	result.tug += float(pet.traits.patience)
	result.cups += float(pet.traits.curiosity)
	result.cuddle += float(pet.traits.sociability)
	if pet.life.mood == "playful":
		result.ball += 1.0
		result.tug += 1.0
	if pet.life.mood == "curious": result.cups += 1.5
	if pet.life.mood in ["cuddly", "sleepy", "calm"]: result.cuddle += 1.2
	if pet.life.quirks.has("ball_guard"): result.ball += 0.7
	if pet.life.quirks.has("meal_sniff"): result.cups += 0.7
	# A gentle invitation remains possible when energetic games are unsuitable.
	if float(pet.needs.energy) < 35 or pet.fatigue >= 80:
		for kind in PetState.PLAY_KEYS: result[kind] = 0.0
	return result

static func choose(pet: PetState, roll: float = -1.0) -> String:
	var options := weights(pet)
	var total := 0.0
	for weight in options.values(): total += float(weight)
	var cursor := clampf(randf() if roll < 0 else roll, 0, 0.999999) * total
	for kind in PetState.INITIATIVE_KEYS:
		cursor -= float(options[kind])
		if cursor < 0: return kind
	return "cuddle"

static func invitation_text(pet: PetState, kind: String) -> String:
	return {
		"ball": "%s ma ochotę na piłkę. Rzucisz?",
		"tug": "%s zaprasza do zabawek. Może przeciąganie liny?",
		"cups": "%s ma ochotę powęszyć. Poszukacie razem smakołyka?",
		"cuddle": "%s wyciąga łapę w Twoją stronę. Chwila bliskości?",
	}[kind] % pet.pet_name

static func record(pet: PetState, kind: String, response: String, now: float) -> bool:
	if not PetState.INITIATIVE_KEYS.has(kind) or not PetState.RESPONSE_KEYS.has(response) or not is_finite(now) or now < 0: return false
	var memory: Dictionary = pet.social.responses[kind]
	memory[response] = mini(PetState.MAX_EVENT_COUNT, int(memory[response]) + 1)
	memory.interest = clampf(float(memory.interest) + {"accepted": 0.12, "declined": -0.08, "ignored": -0.04}[response], 0.15, 0.95)
	pet.social.recent.push_front({"kind": kind, "response": response, "at": now})
	if pet.social.recent.size() > 12: pet.social.recent.resize(12)
	if response == "accepted" and int(memory.accepted) == 3:
		pet.remember("initiative_" + kind, "Nasz mały rytuał: " + LABELS[kind],
			"Trzy przyjęte zaproszenia. Coraz lepiej wie, jakie wspólne chwile lubicie.", now)
	return true

static func profile_text(pet: PetState) -> String:
	if pet.social.recent.is_empty(): return "Dopiero poznaje Twoje odpowiedzi na zaproszenia."
	var best := ""
	var interest := -1.0
	for kind in PetState.INITIATIVE_KEYS:
		var memory: Dictionary = pet.social.responses[kind]
		if int(memory.accepted) > 0 and float(memory.interest) > interest:
			best = kind
			interest = memory.interest
	var text := "Chętnie proponuje: %s." % LABELS[best].to_lower() if not best.is_empty() else "Poznaje Wasz rytm. Może zaproponować inną wspólną chwilę."
	text += "\nOstatnie zaproszenia:"
	for index in mini(3, pet.social.recent.size()):
		var entry: Dictionary = pet.social.recent[index]
		text += "\n• %s — %s" % [LABELS[entry.kind], RESPONSES[entry.response]]
	return text
