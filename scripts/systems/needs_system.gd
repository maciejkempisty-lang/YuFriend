class_name NeedsSystem
extends RefCounted

const WAKE_ENERGY := 85.0
const MAX_OFFLINE_SECONDS := 8.0 * 3600.0
const LOSS_PER_HOUR := {"fullness": 7.0, "energy": 5.0, "hygiene": 3.0, "play": 7.0, "contact": 5.0}

static func advance(pet: PetState, seconds: float, offline: bool = false) -> void:
	if not is_finite(seconds) or seconds <= 0:
		return
	var elapsed := minf(seconds, MAX_OFFLINE_SECONDS) if offline else seconds
	if offline and pet.resting:
		# Net offline recovery: +18 minus the usual 5 energy/hour.
		var rest_seconds := minf(elapsed, maxf(0, (WAKE_ENERGY - float(pet.needs.energy)) / 13.0 * 3600.0))
		_advance_chunk(pet, rest_seconds, true)
		if float(pet.needs.energy) >= WAKE_ENERGY - 0.001:
			pet.resting = false
		_advance_chunk(pet, elapsed - rest_seconds, true)
	else:
		_advance_chunk(pet, elapsed, offline)

static func _advance_chunk(pet: PetState, elapsed: float, offline: bool) -> void:
	if elapsed <= 0: return
	for key in PetState.NEED_KEYS:
		var rate: float = LOSS_PER_HOUR[key]
		if key == "contact":
			rate *= 0.7 + float(pet.traits.sociability) * 0.6
		if key == "energy" and pet.resting:
			rate -= 18.0 if offline else 0.8 * 3600.0
		pet.needs[key] = clampf(float(pet.needs[key]) - rate * elapsed / 3600.0, 15.0, 100.0)
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

# Scheduled sleep uses the same rates in foreground and background. Manual
# recovery naps retain the legacy fast recovery used by short care activities.
static func advance_sleep(pet: PetState, seconds: float) -> void:
	if not is_finite(seconds) or seconds <= 0: return
	for key in PetState.NEED_KEYS:
		var rate: float = -13.0 if key == "energy" else float(LOSS_PER_HOUR[key]) * 0.35
		if key == "contact": rate *= 0.7 + float(pet.traits.sociability) * 0.6
		pet.needs[key] = clampf(float(pet.needs[key]) - rate * seconds / 3600.0, 15.0, 100.0)
	pet.fatigue = maxf(0, pet.fatigue - seconds * 0.35)

static func catch_up_rhythm(pet: PetState, now: float, local_now: float) -> float:
	var elapsed := clampf(now - pet.last_seen_at, 0, MAX_OFFLINE_SECONDS)
	var cursor := local_now - maxf(0, now - pet.last_seen_at)
	var remaining := elapsed
	# Hour boundaries include every sleep/wake transition, even with a half-hour offset.
	while remaining > 0.000001:
		var offset := float(pet.rhythm.offset_minutes) * 60
		var boundary: float = (floor((cursor - offset) / 3600) + 1) * 3600 + offset
		if float(pet.rhythm.awake_until) > cursor:
			boundary = minf(boundary, float(pet.rhythm.awake_until))
		var step := minf(remaining, maxf(0.000001, boundary - cursor))
		pet.resting = DailyRhythm.should_sleep(pet, cursor)
		if pet.resting: advance_sleep(pet, step)
		else: _advance_chunk(pet, step, true)
		cursor += step
		remaining -= step
	# Needs freeze after eight hours; the displayed rhythm still follows today's clock.
	pet.resting = DailyRhythm.should_sleep(pet, local_now)
	pet.last_seen_at = maxf(pet.last_seen_at, now)
	return elapsed
