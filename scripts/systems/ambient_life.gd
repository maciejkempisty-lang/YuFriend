class_name AmbientLife
extends RefCounted

# Presentation only: no pet state, rewards, daily counters or activity locks.
const KINDS := ["butterfly", "sparrow", "snail", "squirrel", "window_bird"]
const ANCHORS := {"butterfly": Vector2(550, 260), "sparrow": Vector2(850, 338), "window_bird": Vector2(771, 210), "snail": Vector2(645, 344), "squirrel": Vector2(585, 252)}
const DURATION := {"butterfly": 20.0, "sparrow": 9.0, "window_bird": 8.0, "snail": 40.0, "squirrel": 9.0}
const FIRST_WAIT := {"butterfly": 4.0, "sparrow": 22.0, "window_bird": 15.0, "snail": 10.0, "squirrel": 30.0}
var actors: Dictionary = {}
var waits: Dictionary = {}
var location := ""
var enabled := false
# Tests turn this off so random spawns never land in compared screenshots;
# explicit start() calls still work.
var autoplay := true
var calm := false
var planted := false
var flower_y := 273.0
var dog := Vector2.INF
var in_view: Array[String] = []
var rng := RandomNumberGenerator.new()

func _init(seed_value: int = 0) -> void:
	if seed_value == 0: rng.randomize()
	else: rng.seed = seed_value
	_reset_waits()

func _reset_waits() -> void:
	for kind in KINDS:
		waits[kind] = FIRST_WAIT[kind] + rng.randf_range(0, 4)

func configure(place: String, watching: bool, idle: bool, plant: bool, blossom_y: float, pet_position: Vector2, visible_kinds: Array[String]) -> void:
	if location != place:
		location = place
		actors.clear()
		_reset_waits()
	enabled = watching
	calm = idle
	planted = plant
	flower_y = blossom_y
	dog = pet_position
	in_view = visible_kinds
	if not enabled:
		for kind in actors: waits[kind] = rng.randf_range(40, 75)
		actors.clear()
		return
	for kind in actors.keys():
		if kind not in in_view:
			actors.erase(kind)
			waits[kind] = rng.randf_range(40, 75)
		elif not calm or (kind == "sparrow" and dog.distance_to(actors[kind].position) < 85):
			depart(kind)

func start(kind: String) -> bool:
	if kind not in KINDS or not enabled or not calm or kind not in in_view or actors.has(kind) or actors.size() >= 2: return false
	if (location == "yard") != (kind != "window_bird"): return false
	if kind == "sparrow" and dog.distance_to(ANCHORS.sparrow) < 100: return false
	actors[kind] = {"age": 0.0, "leaving": false, "exit_age": 0.0, "exit_from": Vector2.ZERO, "position": _point(kind, 0), "frame": _frame(kind, 0), "opacity": 0.0 if kind in ["snail", "squirrel"] else 1.0}
	return true

func depart(kind: String) -> void:
	if not actors.has(kind) or actors[kind].leaving: return
	actors[kind].leaving = true
	actors[kind].exit_from = actors[kind].position
	actors[kind].exit_age = 0.0
	actors[kind].exit_opacity = actors[kind].opacity

func advance(delta: float) -> void:
	if not enabled or not is_finite(delta) or delta <= 0: return
	for kind in actors.keys():
		var actor: Dictionary = actors[kind]
		actor.age += delta
		if actor.leaving:
			actor.exit_age += delta
			var t := minf(1, float(actor.exit_age) / 0.8)
			actor.position = actor.exit_from + Vector2(100 * t, -85 * t - sin(t * PI) * 12)
			actor.frame = int(actor.exit_age * 12) % 2 + (0 if kind == "butterfly" else 2)
			if kind == "snail":
				# Withdraw into the shell where it is, never make a ground animal fly.
				actor.position = actor.exit_from
				actor.frame = 2
				actor.opacity = float(actor.exit_opacity) * (1.0 - t)
			elif kind == "squirrel":
				actor.position = actor.exit_from + Vector2(96 * t, 0)
				actor.frame = int(actor.exit_age * 12) % 2
				actor.opacity = float(actor.exit_opacity) * (1.0 - t)
			if t >= 1:
				actors.erase(kind)
				waits[kind] = rng.randf_range(40, 75)
			continue
		actor.position = _point(kind, actor.age)
		actor.frame = _frame(kind, actor.age)
		actor.opacity = minf(1.0, actor.age / 0.4) if kind in ["snail", "squirrel"] else 1.0
		if actor.age >= DURATION[kind] or (kind == "sparrow" and dog.distance_to(actor.position) < 85): depart(kind)
	if not calm or not autoplay: return
	for kind in KINDS:
		if kind not in in_view or actors.has(kind): continue
		if (location == "yard") != (kind != "window_bird"): continue
		waits[kind] = maxf(0, float(waits[kind]) - delta)
		if waits[kind] == 0: start(kind)

func _point(kind: String, age: float) -> Vector2:
	if kind == "snail":
		return Vector2(606 + minf(age / DURATION.snail, 1.0) * 78, 344)
	if kind == "squirrel":
		if age < 3: return Vector2(450, 252).lerp(Vector2(585, 252), age / 3)
		if age < 5: return Vector2(585, 252)
		return Vector2(585, 252).lerp(Vector2(705, 252), clampf((age - 5) / 4, 0, 1))
	if kind == "window_bird":
		return Vector2(820, 175).lerp(Vector2(771, 213), smoothstep(0, 1.4, age))
	if kind == "sparrow":
		if age < 1.8: return Vector2(960, 180).lerp(Vector2(835, 338), smoothstep(0, 1.8, age))
		if age < 3: return _hop(Vector2(835, 338), Vector2(865, 338), (age - 1.8) / 1.2)
		if age < 5.5: return Vector2(865, 338)
		if age < 6.7: return _hop(Vector2(865, 338), Vector2(826, 338), (age - 5.5) / 1.2)
		return Vector2(826, 338)
	var orbit := Vector2(550 + sin(age * 0.85) * 60, 240 + sin(age * 1.7) * 15)
	if age < 2: return Vector2(440, 210).lerp(orbit, smoothstep(0, 2, age))
	if planted and age >= 6:
		var arrival := Vector2(550 + sin(6 * 0.85) * 60, 240 + sin(6 * 1.7) * 15)
		return arrival.lerp(Vector2(553, flower_y), smoothstep(6, 8, age))
	return orbit

func _frame(kind: String, age: float) -> int:
	if kind == "snail": return int(age * 1.5) % 2
	if kind == "squirrel": return 2 if age >= 3 and age < 5 else int(age * 10) % 2
	if kind == "butterfly": return 1 if planted and age >= 8 else int(age * 8) % 2
	if age < (1.4 if kind == "window_bird" else 1.8): return 2 + int(age * 10) % 2
	if kind == "window_bird": return 1 if fmod(age, 2.4) > 2 else 0
	return 1 if (age > 3 and age < 5.5 or age > 6.7) and fmod(age, 0.9) > 0.55 else 0

static func _hop(from: Vector2, to: Vector2, t: float) -> Vector2:
	return from.lerp(to, t) + Vector2(0, -sin(t * PI) * 12)
