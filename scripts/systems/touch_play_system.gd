class_name TouchPlaySystem
extends RefCounted

const REWARD_INTERVAL := 30.0
const TUG_STROKES := 6
const SWAP_SECONDS := 0.75
var kind := ""
var phase := ""
var elapsed := 0.0
var success := false
var settled := false
var held := false
var tug_handle := Vector2(0.78, 0.54)
var tug_anchor := 0.78
var tug_direction := -1
var strokes := 0
var cups: Array = [0, 1, 2] # cup ID → visible slot
var treat_cup := 0
var selected_cup := -1
var swap_pair := Vector2i(0, 1)
var swaps := 0
var _pressed_cup := -1
var _press_point := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

func start(game: String, seed_value: int = 0) -> bool:
	if not PetState.PLAY_KEYS.has(game): return false
	reset()
	kind = game
	if seed_value == 0: _rng.randomize()
	else: _rng.seed = seed_value
	phase = {"ball": "chase", "tug": "pull", "cups": "reveal"}[kind]
	treat_cup = _rng.randi_range(0, 2)
	return true

func reset() -> void:
	kind = ""
	phase = ""
	elapsed = 0
	success = false
	settled = false
	held = false
	tug_handle = Vector2(0.78, 0.54)
	tug_anchor = tug_handle.x
	tug_direction = -1
	strokes = 0
	cups = [0, 1, 2]
	selected_cup = -1
	_pressed_cup = -1
	swaps = 0

func running() -> bool:
	return not kind.is_empty() and phase != "result"

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0 or kind != "cups": return
	var left := delta
	while left > 0 and phase in ["reveal", "cover", "shuffle"]:
		var duration: float = {"reveal": 1.4, "cover": 0.5, "shuffle": SWAP_SECONDS}[phase]
		var step := minf(left, duration - elapsed)
		elapsed += step
		left -= step
		if elapsed < duration: return
		elapsed = 0
		match phase:
			"reveal": phase = "cover"
			"cover":
				phase = "shuffle"
				_next_swap()
			"shuffle":
				var previous: int = cups[swap_pair.x]
				cups[swap_pair.x] = cups[swap_pair.y]
				cups[swap_pair.y] = previous
				swaps += 1
				if swaps == 3: phase = "guess"
				else: _next_swap()

func _next_swap() -> void:
	swap_pair.x = _rng.randi_range(0, 2)
	swap_pair.y = (swap_pair.x + _rng.randi_range(1, 2)) % 3

func cup_point(id: int) -> Vector2:
	var slot := float(cups[id])
	var lift := 0.0
	if phase == "shuffle" and id in [swap_pair.x, swap_pair.y]:
		var other := swap_pair.y if id == swap_pair.x else swap_pair.x
		var progress := smoothstep(0.0, 1.0, elapsed / SWAP_SECONDS)
		slot = lerpf(slot, float(cups[other]), progress)
		lift = sin(progress * PI) * (0.08 if id == swap_pair.x else -0.08)
	return Vector2(0.2 + slot * 0.3, 0.66 - lift)

func cup_at(point: Vector2) -> int:
	for id in 3:
		if Rect2(cup_point(id) - Vector2(0.11, 0.27), Vector2(0.22, 0.32)).has_point(point): return id
	return -1

func _valid_point(point: Vector2) -> bool:
	return point.is_finite() and Rect2(Vector2.ZERO, Vector2.ONE).has_point(point)

func press(point: Vector2) -> void:
	if held or not _valid_point(point): return
	if kind == "tug" and phase == "pull":
		if absf(point.x - tug_handle.x) > 0.13 or absf(point.y - tug_handle.y) > 0.16: return
		held = true
		tug_anchor = tug_handle.x
	elif kind == "cups" and phase == "guess":
		_pressed_cup = cup_at(point)
		held = _pressed_cup >= 0
		_press_point = point

func move(point: Vector2) -> void:
	if not held or not point.is_finite(): return
	if kind == "tug" and phase == "pull":
		tug_handle.x = clampf(point.x, 0.42, 0.88)
		if (tug_handle.x - tug_anchor) * tug_direction >= 0.18:
			strokes += 1
			tug_anchor = tug_handle.x
			tug_direction *= -1
			if strokes >= TUG_STROKES: _finish(true)
	elif kind == "cups" and point.distance_to(_press_point) > 0.06:
		_pressed_cup = -1

func release(point: Vector2, cancelled: bool = false) -> void:
	if not held: return
	if not cancelled and _valid_point(point):
		move(point)
		if kind == "cups" and phase == "guess" and _pressed_cup >= 0 and cup_at(point) == _pressed_cup:
			selected_cup = _pressed_cup
			_finish(selected_cup == treat_cup)
	held = false
	_pressed_cup = -1

func finish_ball() -> void:
	if kind == "ball" and phase == "chase": _finish(true)

func _finish(won: bool) -> void:
	if phase == "result": return
	success = won
	phase = "result"
	held = false

func hint() -> String:
	if phase == "result":
		if kind == "cups" and not success: return "Tutaj był smakołyk! Możecie spróbować jeszcze raz."
		return {"ball": "Piłka złapana!", "tug": "Ale zabawa! Lina na chwilę odpoczywa.", "cups": "Jest smakołyk! Świetny z Was zespół."}.get(kind, "")
	if kind == "tug":
		return "Chwyć węzeł i pociągnij %s. %d z %d" % ["w lewo ←" if tug_direction < 0 else "w prawo →", strokes, TUG_STROKES]
	return {"reveal": "Zapamiętaj kubek ze smakołykiem.", "cover": "Teraz chowamy smakołyk…", "shuffle": "Śledź swój kubek…", "guess": "Pod którym kubkiem jest smakołyk? Dotknij go."}.get(phase, "Rzuć piłkę i patrz, jak ją łapie.")
