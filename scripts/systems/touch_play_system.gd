class_name TouchPlaySystem
extends RefCounted

const REWARD_INTERVAL := 30.0
const TUG_STROKES := 5
const TUG_RETURN_SECONDS := 4.0
var tug_demo_seen := false
var tug_best := 0
var tug_round := 0
var tug_good := 0
var tug_pulled := false
var tug_released := false
var tug_bad := false
var tug_feedback := ""
const SEARCH_SECONDS := 1.5
var kind := ""
var phase := ""
var elapsed := 0.0
var success := false
var settled := false
var held := false
var tug_handle := Vector2(0.60, 0.54)
var tug_anchor := 0.60
var tug_return_from := 0.80
var strokes := 0
var treat_cup := -1
var selected_cup := -1
var search_order: Array[int] = []
var search_index := 0
var _pressed_cup := -1
var _press_point := Vector2.ZERO
var _rng := RandomNumberGenerator.new()

func start(game: String, seed_value: int = 0) -> bool:
	if not PetState.PLAY_KEYS.has(game): return false
	reset()
	kind = game
	if seed_value == 0: _rng.randomize()
	else: _rng.seed = seed_value
	phase = {"ball": "chase", "tug": "pull" if tug_demo_seen else "demo_pull", "cups": "hide"}[kind]
	return true

func reset() -> void:
	kind = ""
	phase = ""
	elapsed = 0
	success = false
	settled = false
	held = false
	tug_handle = Vector2(0.60, 0.54)
	tug_anchor = tug_handle.x
	strokes = 0
	tug_round = 0
	tug_good = 0
	tug_pulled = false
	tug_released = false
	tug_bad = false
	tug_feedback = ""
	treat_cup = -1
	selected_cup = -1
	_pressed_cup = -1
	search_order.clear()
	search_index = 0

func running() -> bool:
	return not kind.is_empty() and phase != "result"

func advance(delta: float) -> void:
	if not is_finite(delta) or delta <= 0: return
	if kind == "tug":
		_advance_tug(delta)
		return
	if kind != "cups": return
	var left := delta
	while left > 0 and phase in ["cover", "search"]:
		var duration := 0.7 if phase == "cover" else SEARCH_SECONDS
		var step := minf(left, duration - elapsed)
		elapsed += step
		left -= step
		if elapsed < duration: return
		elapsed = 0
		if phase == "cover": phase = "ready"
		elif search_order[search_index] == treat_cup:
			selected_cup = treat_cup
			phase = "found"
		else: search_index += 1

# The player prepares the hiding place; only the dog chooses while searching.
func cue() -> void:
	if kind == "tug" and phase == "demo_done":
		tug_demo_seen = true
		start("tug")
		return
	if kind != "cups": return
	if phase == "ready":
		search_order.assign([0, 1, 2])
		for index in range(2, 0, -1):
			var other := _rng.randi_range(0, index)
			var previous := search_order[index]
			search_order[index] = search_order[other]
			search_order[other] = previous
		search_index = 0
		elapsed = 0
		phase = "search"
	elif phase == "found": _finish(true)

func cup_point(id: int) -> Vector2:
	return Vector2(0.2 + id * 0.3, 0.48)

func cup_at(point: Vector2) -> int:
	for id in 3:
		if Rect2(cup_point(id) - Vector2(0.11, 0.34), Vector2(0.22, 0.39)).has_point(point): return id
	return -1

func dog_point() -> Vector2:
	var x := 0.5
	if phase == "search":
		var from := 0.5 if search_index == 0 else cup_point(search_order[search_index - 1]).x
		x = lerpf(from, cup_point(search_order[search_index]).x, smoothstep(0, 0.6, elapsed / SEARCH_SECONDS))
	elif phase in ["found", "result"] and selected_cup >= 0: x = cup_point(selected_cup).x
	return Vector2(x, 0.91)

func _valid_point(point: Vector2) -> bool:
	return point.is_finite() and Rect2(Vector2.ZERO, Vector2.ONE).has_point(point)

func press(point: Vector2) -> void:
	if held or not _valid_point(point): return
	if kind == "tug" and phase in ["pull", "warning", "demo_pull"]:
		if absf(point.x - tug_handle.x) > 0.13 or absf(point.y - tug_handle.y) > 0.16: return
		held = true
	elif kind == "cups" and phase == "hide":
		_pressed_cup = cup_at(point)
		held = _pressed_cup >= 0
		_press_point = point

func move(point: Vector2) -> void:
	if not held or not point.is_finite(): return
	if kind == "tug":
		if phase in ["pull", "demo_pull"]:
			tug_handle.x = clampf(point.x, 0.60, 0.88)
			if tug_handle.x >= 0.78:
				tug_pulled = true
				if phase == "demo_pull": phase = "demo_warning"
		elif phase == "dog_pull": tug_bad = true
	elif kind == "cups" and point.distance_to(_press_point) > 0.06:
		_pressed_cup = -1

func release(point: Vector2, cancelled: bool = false) -> void:
	if not held: return
	if not cancelled and _valid_point(point):
		move(point)
		if kind == "cups" and phase == "hide" and _pressed_cup >= 0 and cup_at(point) == _pressed_cup:
			treat_cup = _pressed_cup
			elapsed = 0
			phase = "cover"
	if kind == "tug":
		if phase == "demo_warning" and not cancelled:
			phase = "demo_done"
		elif phase == "demo_pull" or (cancelled and phase == "demo_warning"):
			phase = "demo_pull"
			tug_handle.x = 0.60
		else:
			tug_released = phase == "warning" and not cancelled
			if not tug_released: tug_bad = true
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
		return {"ball": "Piłka złapana!", "tug": "%s · %d/3 gwiazdki. Dobre wymiany: %d/5. Rekord: %d/5." % ["Świetne wyczucie!" if tug_good >= 3 else "Gloria wygrała linę!", tug_stars(), tug_good, tug_best], "cups": "Smakołyk znaleziony i pochwała przyjęta!"}.get(kind, "")
	if kind == "tug":
		return {"demo_pull": "Pokaz bez punktów: chwyć węzeł i przeciągnij w prawo. Przytrzymaj.", "demo_warning": "Piesek przykuca — zaraz szarpnie. Teraz puść palec!", "demo_done": "Tak! Ciągnij, trzymaj i puść na zapowiedź. Runda: 5 wymian, około 20 s.", "pull": "Ciągnij w prawo i trzymaj. Czekaj na przykucnięcie.", "warning": "Uwaga, piesek przykuca! PUŚĆ palec przed szarpnięciem.", "dog_pull": "Teraz Gloria szarpie — zostaw linę luźną.", "recover": tug_feedback}.get(phase, "")
	return {"hide": "Schowaj smakołyk: dotknij wybranego kubka. Piesek czeka.", "cover": "Smakołyk schowany…", "ready": "Kryjówka gotowa. Daj pieskowi komendę „Szukaj!”", "search": "Piesek węszy przy kubkach. Poczekaj, aż znajdzie smakołyk.", "found": "Nos wskazał ten kubek! Pochwal pieska za znalezienie."}.get(phase, "Rzuć piłkę i patrz, jak piesek ją łapie.")

func tug_stars() -> int:
	return 3 if tug_good == 5 else (2 if tug_good >= 3 else (1 if tug_good >= 1 else 0))

func _advance_tug(delta: float) -> void:
	var left := delta
	while left > 0 and phase in ["pull", "warning", "dog_pull", "recover"]:
		var duration: float = {"pull": 2.0, "warning": 1.0, "dog_pull": 0.6, "recover": 0.4}[phase]
		var step := minf(left, duration - elapsed)
		elapsed += step
		left -= step
		if phase == "dog_pull": tug_handle.x = lerpf(tug_return_from, 0.60, elapsed / duration)
		if elapsed < duration - 0.000001: return
		elapsed = 0
		match phase:
			"pull": phase = "warning"
			"warning":
				phase = "dog_pull"
				tug_bad = tug_bad or held
				tug_return_from = tug_handle.x
			"dog_pull":
				tug_round += 1
				if tug_pulled: strokes += 1
				var good := tug_pulled and tug_released and not tug_bad
				if good: tug_good += 1
				tug_feedback = "Dobrze! Puściłeś przed szarpnięciem." if good else ("Najpierw pociągnij linę." if not tug_pulled else "Puść dopiero na zapowiedź szarpnięcia.")
				phase = "recover"
			"recover":
				if tug_round == TUG_STROKES:
					_finish(strokes > 0)
				else:
					phase = "pull"
					tug_pulled = false
					tug_released = false
					tug_bad = false
					held = false
					tug_handle.x = 0.60
