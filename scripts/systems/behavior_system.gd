class_name BehaviorSystem
extends RefCounted

# Group, destination. A sequence is one choice, so quirks may revisit a station.
const BEHAVIORS := {
	"patrol": [0, "floor"], "window": [1, "window"], "door": [1, "door"],
	"toys": [0, "toys"], "ball": [0, "ball"], "bowl": [1, "food"],
	"carpet": [1, "carpet"], "wait": [1, "center"], "approach": [1, "front"],
	"nap": [2, "bed"]
}

static func weights(pet: PetState, now: float, recent: Array = [], last_place: String = "") -> Dictionary:
	var quiet := DailyRhythm.quiet(pet, now)
	var raw := {"patrol": 1.0, "window": 0.6 + float(pet.traits.curiosity), "door": 0.7,
		"toys": 0.7, "ball": 0.7, "bowl": 0.35, "carpet": 1.0, "wait": 0.7,
		"approach": 0.5 + float(pet.traits.sociability), "nap": 1.0}
	if pet.habits.has("playful"):
		raw.toys += 0.7
		raw.ball += 0.7
	if pet.habits.has("student"): raw.wait += 1.0
	if pet.life.mood == "curious": raw.window += 1.0
	if pet.habits.has("cuddler") or pet.life.mood == "cuddly": raw.approach += 1.2
	if pet.habits.has("time_" + PersonalitySystem.part_of(now)): raw.door += 1.2
	if DailyRhythm.phase(pet, now) == "morning": raw.bowl += 1.0
	for pair in [["window_watch", "window"], ["door_listener", "door"], ["toy_sorter", "toys"], ["ball_guard", "ball"], ["sun_napper", "nap"]]:
		if pet.life.quirks.has(pair[0]): raw[pair[1]] += 0.8
	if quiet:
		raw.ball = 0.0
		raw.toys = 0.0
		raw.carpet += 2.0
	raw.nap = 0.0 # Sleep follows the clock, never a random behavior roll.
	var totals := [0.0, 0.0, 0.0]
	for id in raw: totals[BEHAVIORS[id][0]] += raw[id]
	var groups := DailyRhythm.proportions(pet, now)
	for id in raw:
		var group: int = BEHAVIORS[id][0]
		raw[id] = raw[id] * groups[group] / totals[group] if totals[group] > 0 else 0.0
		# Soft penalties retain a valid choice even with a small eligible pool.
		if recent.has(id): raw[id] *= 0.08
		if BEHAVIORS[id][1] == last_place: raw[id] *= 0.12
	return raw

static func choose(options: Dictionary, roll: float) -> String:
	var total := 0.0
	for weight in options.values(): total += float(weight)
	if total <= 0: return "carpet"
	var cursor := clampf(roll, 0, 0.999999) * total
	for id in options:
		cursor -= float(options[id])
		if cursor < 0: return id
	return "carpet"

static func steps(id: String, pet: PetState, quiet: bool = false) -> Array:
	var carpet := Vector2(640, 324)
	var bed: Vector2 = RoomLayout.STATIONS.bed.stand
	var window: Vector2 = RoomLayout.STATIONS.window.stand
	match id:
		"patrol": return [_move(Vector2(410, 307)), _clip("idle", 3), _move(Vector2(1040, 316)), _clip("sit_idle", 6)]
		"window":
			var sequence := [_move(window), _clip("sit_idle", 8), _clip("head_tilt_stand", 2)]
			if pet.life.quirks.has("window_watch") and not quiet: sequence.append(_clip("bark_stand", 1.5))
			sequence.append_array([_move(carpet), _clip("idle_lie", 15)])
			return sequence
		"door": return [_move(RoomLayout.STATIONS.door.stand), _clip("head_tilt_stand", 3), _clip("sit_idle", 12)]
		"toys":
			var point: Vector2 = RoomLayout.STATIONS.toys.stand
			var sequence := [_move(point), _clip("play_bow", 2), _clip("tail_wag_stand", 2)]
			if pet.life.quirks.has("toy_sorter"):
				sequence.append_array([_move(point + Vector2(-70, 8)), _move(point), _clip("play_bow", 2)])
			return sequence
		"ball": return [_move(RoomLayout.STATIONS.ball.stand), _clip("play_bow", 2), _clip("bark_stand", 1.5)]
		"bowl": return [_move(RoomLayout.STATIONS.food.stand), _clip("head_tilt_stand", 2), _clip("eat_enter", 0.8), _clip("eat_exit", 0.8)]
		"carpet": return [_move(carpet), _clip("idle_lie", 35 if quiet else 20)]
		"wait": return [_move(RoomLayout.START), _clip("sit_idle", 12), _clip("tail_wag_sit", 3)]
		"approach": return [_move(Vector2(670, 328)), _clip("give_paw", 3), _clip("sit_idle", 12)]
		"nap", "night":
			var point := window + Vector2(-40, 25) if id == "nap" and pet.life.quirks.has("sun_napper") else bed
			var sequence := []
			if pet.life.quirks.has("bed_circles") and point == bed:
				sequence.append_array([_move(bed + Vector2(-45, 8)), _move(bed + Vector2(40, 14)), _move(bed + Vector2(35, -10))])
			sequence.append(_move(point))
			sequence.append({"sleep": id})
			return sequence
	return [_clip("sit_idle", 10)]

static func _move(point: Vector2) -> Dictionary:
	return {"point": RoomLayout.clamp_walk(point)}

static func _clip(clip: String, seconds: float) -> Dictionary:
	return {"clip": clip, "seconds": seconds}
