class_name NeedsSystem
extends RefCounted

const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const LOSS_PER_HOUR := {"fullness": 7.0, "energy": 5.0, "hygiene": 3.0, "play": 7.0, "contact": 5.0}

static func advance(pet: PetState, seconds: float, offline: bool = false) -> void:
	if not is_finite(seconds) or seconds <= 0:
		return
	var elapsed := minf(seconds, MAX_OFFLINE_SECONDS) if offline else seconds
	for key in PetState.NEED_KEYS:
		var rate: float = LOSS_PER_HOUR[key]
		if key == "contact":
			rate *= 0.7 + float(pet.traits.sociability) * 0.6
		pet.needs[key] = clampf(float(pet.needs[key]) - rate * elapsed / 3600.0, 15.0, 100.0)
	if pet.resting:
		var gain := elapsed * (18.0 / 3600.0 if offline else 0.8)
		pet.needs.energy = minf(100.0, float(pet.needs.energy) + gain)
	pet.fatigue = maxf(0.0, pet.fatigue - elapsed * (0.35 if pet.resting else 0.08))

static func catch_up(pet: PetState, now: float) -> float:
	var elapsed := clampf(now - pet.last_seen_at, 0, MAX_OFFLINE_SECONDS)
	advance(pet, elapsed, true)
	# Preserve the watermark if the device clock has moved backwards.
	pet.last_seen_at = maxf(pet.last_seen_at, now)
	return elapsed

static func change(pet: PetState, effects: Dictionary) -> void:
	for key in effects:
		if pet.needs.has(key):
			pet.needs[key] = clampf(float(pet.needs[key]) + float(effects[key]), 0, 100)
