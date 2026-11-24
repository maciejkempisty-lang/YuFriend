class_name WellbeingSystem
extends RefCounted

# Session-only emotional needs. Offline/sleep losses are rebased, never replayed
# later as a debt. The v17 pet and its actual needs remain untouched.
const WEIGHTS := {"contact": 0.30, "play": 0.25, "fullness": 0.20, "energy": 0.15, "hygiene": 0.10}
const WELCOME_LEVEL := 80.0
const LABELS := ["Smutna", "Markotna", "Zadowolona", "Radosna"]
var parts: Dictionary = {}
var observed: Dictionary = {}
var joy := 0.0
var awake_seconds := 0.0
var rewards: Dictionary = {}
var reunion_left := 0.0

func begin(pet: PetState, away: float = 0.0) -> void:
	parts.clear()
	joy = 0
	awake_seconds = 0
	rewards.clear()
	for key in WEIGHTS: parts[key] = maxf(WELCOME_LEVEL, float(pet.needs[key]))
	rebase(pet)
	reunion_left = 60.0 if away > 4 * 3600 else 0.0

func rebase(pet: PetState) -> void:
	observed = pet.needs.duplicate()

func returned(pet: PetState, away: float) -> void:
	if parts.is_empty(): begin(pet, away)
	else:
		# Returning can only improve the emotion, including after short absences.
		for key in parts: parts[key] = maxf(WELCOME_LEVEL, float(parts[key]))
		rebase(pet)
		if away > 4 * 3600: reunion_left = 60

func observe(pet: PetState, allow_loss: bool = true) -> void:
	if parts.is_empty(): begin(pet)
	for key in WEIGHTS:
		var change := float(pet.needs[key]) - float(observed[key])
		parts[key] = clampf(float(parts[key]) + (change if allow_loss else maxf(0, change)), 0, 100)
	rebase(pet)

func advance(seconds: float, awake: bool) -> void:
	if not awake or not is_finite(seconds) or seconds <= 0: return
	awake_seconds += seconds
	joy *= pow(0.5, seconds / 1200.0)
	reunion_left = maxf(0, reunion_left - seconds)

func add_joy(kind: String, amount: float) -> void:
	if not is_finite(amount) or amount <= 0: return
	var previous: Dictionary = rewards.get(kind, {"at": -INF, "count": 0})
	if awake_seconds - float(previous.at) < 30: return
	var count := int(previous.count) if awake_seconds - float(previous.at) < 1200 else 0
	joy = minf(20, joy + amount / (1 + count))
	rewards[kind] = {"at": awake_seconds, "count": count + 1}

func comfort() -> void:
	# One completed ritual visibly helps even when several needs are low.
	var gain := maxf(0, 58 - score())
	for key in parts: parts[key] = minf(100, float(parts[key]) + gain)

func score() -> float:
	if parts.is_empty(): return 75.0
	var value := joy
	for key in WEIGHTS: value += float(parts[key]) * float(WEIGHTS[key])
	return clampf(value, 0, 100)

static func state(value: float) -> int:
	return 3 if value >= 75 else (2 if value >= 55 else (1 if value >= 35 else 0))

func label() -> String:
	return "Stęskniona" if reunion_left > 0 else LABELS[state(score())]

func lowest_part() -> String:
	var lowest := "contact"
	for key in parts:
		if float(parts[key]) < float(parts[lowest]): lowest = key
	return lowest

static func favorite(pet: PetState) -> int:
	return posmod(pet.personality_seed, 2)

static func favorite_label(pet: PetState) -> String:
	return ["za uszkiem", "pod brodą"][favorite(pet)]
