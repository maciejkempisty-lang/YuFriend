class_name SkillPlaySystem
extends TouchPlaySystem

const EXTRA := ["tag", "cups2", "frisbee", "freestyle"]
const LABELS := {"tag": "Berek z zabawką", "cups2": "Kubki · śledź smakołyk", "frisbee": "Frisbee", "freestyle": "Psi freestyle"}
const DANCE_CLIPS := {"sit": "sit_down", "paw": "give_paw", "lie": "lie_down", "bow": "play_bow", "spin": "spin", "roll": "roll"}
var dance_skills: Array[String] = []
var dance_notes: Array[String] = []
var dance_grades: Array[int] = []
var dance_index := 0
var dance_combo := 0
var dance_best_combo := 0
var dance_last_clip := "idle"
var dance_action_at := -10.0

static func known_dance_skills(pet: PetState) -> Array[String]:
	var result: Array[String] = []
	for key in DANCE_CLIPS:
		if float(pet.skills[key].mastery) >= 50: result.append(key)
	return result

func dance_duration() -> float: return dance_notes.size() * 5.0
func dance_note_time(index: int) -> float: return 3.0 + index * 5.0
func record_key() -> String:
	return "freestyle_%d" % int(dance_duration()) if kind == "freestyle" else kind
func dance_clip() -> String:
	return dance_last_clip if total - dance_action_at < 2.5 else "idle"

var clock_left := 45.0
var total := 0.0
var score := 0
var rounds := 0
var stars := 0
var assisted := false
var level := 0
var slots: Array[int] = [0, 1, 2]
var swap_a := 0
var swap_b := 1
var swaps_left := 0
var swap_duration := 0.7
var tag_x := 0.5
var tag_from := 0.5
var tag_target := 0.8
var disk_power := 0.5
var jumped := false
var jump_at := 0.0
var shot_score := 0
var feedback := ""
var result_time := 0.0
var wind := 0.0
var caught := false
var catch_at := 0.0
var feint_next := false
var tag_offers := 0
var best_record: Dictionary = {}

func catch_progress() -> float: return clampf(0.68 + wind * 0.10, 0.5, 0.85)
func disk_position_at(t: float) -> Vector2:
	return Vector2(lerpf(0.18, 0.78, t) + wind * 0.10 * sin(t * PI), 0.65 - sin(t * PI) * 0.40)
func disk_attached() -> bool:
	return caught and phase in ["flight", "land", "result"]


static func label(game: String) -> String:
	return LABELS.get(game, InitiativeSystem.LABELS.get(game, game))

static func memory_key(game: String) -> String:
	return "cups" if game == "cups2" else ("ball" if game in ["tag", "frisbee", "freestyle"] else game)

func start(game: String, seed_value: int = 0) -> bool:
	if game not in EXTRA: return super.start(game, seed_value)
	if game == "freestyle" and dance_skills.is_empty(): return false
	var next_level := mini(level + 1, 4) if kind == "cups2" and game == kind and success else 0
	reset()
	kind = game
	if seed_value == 0: _rng.randomize()
	else: _rng.seed = seed_value
	clock_left = 45.0
	total = 0
	score = 0
	rounds = 0
	stars = 0
	assisted = false
	level = next_level
	slots.assign([0, 1, 2])
	tag_x = 0.5
	tag_from = tag_x
	tag_target = 0.8
	feedback = ""
	result_time = 0
	caught = false
	wind = _rng.randf_range(-1, 1)
	feint_next = false
	tag_offers = 0
	phase = {"tag": "run", "cups2": "show", "frisbee": "aim", "freestyle": "ready"}[game]
	if game == "freestyle":
		dance_notes.clear()
		dance_grades.clear()
		dance_index = 0
		dance_combo = 0
		dance_best_combo = 0
		dance_last_clip = "idle"
		dance_action_at = -10
		var count := 4 if dance_skills.size() < 3 else (8 if dance_skills.size() < 5 else 12)
		for i in count:
			dance_notes.append(dance_skills[i % dance_skills.size()])
			dance_grades.append(-1)
	if game == "cups2":
		treat_cup = _rng.randi_range(0, 2)
		swaps_left = 3 + level
		swap_duration = 0.7 - level * 0.08
	return true

func advance(delta: float) -> void:
	if kind not in EXTRA:
		super.advance(delta)
		return
	if not is_finite(delta) or delta <= 0 or phase == "result": return
	if kind == "freestyle":
		if phase == "ready": return
		total = minf(dance_duration(), total + delta)
		while dance_index < dance_notes.size() and total > dance_note_time(dance_index) + 0.4:
			_dance_judge(0)
		if total >= dance_duration():
			stars = 3 if score == dance_notes.size() * 2 else (2 if score >= dance_notes.size() else (1 if score > 0 else 0))
			_finish(score > 0)
		return
	# Small bounded steps keep boundary events independent of frame rate.
	var left := minf(delta, 91)
	while left > 0 and phase != "result":
		var step := minf(left, 0.02)
		left -= step
		total += step
		elapsed += step
		if kind == "tag":
			clock_left = maxf(0, 45 - total)
			if clock_left <= 0:
				stars = score
				_finish(score > 0)
			elif phase == "run":
				tag_x = lerpf(tag_from, tag_target, smoothstep(0, 1, elapsed / 1.8))
				if elapsed >= 1.8:
					tag_offers += 1
					phase = "feint" if feint_next else "bow"
					elapsed = 0
			elif phase == "feint" and elapsed >= 0.35: _tag_run()
			elif phase == "bow" and elapsed >= 1.5: _tag_run()
		elif kind == "cups2":
			if phase == "show" and elapsed >= 1.4: _next_swap()
			elif phase == "shuffle" and elapsed >= swap_duration:
				var old := slots[swap_a]
				slots[swap_a] = slots[swap_b]
				slots[swap_b] = old
				swaps_left -= 1
				if swaps_left > 0: _next_swap()
				else:
					phase = "guess"
					elapsed = 0
			elif phase == "hint" and elapsed >= 1.2:
				phase = "guess"
				elapsed = 0
		elif kind == "frisbee":
			if phase == "flight" and jumped and shot_score > 0 and not caught and elapsed >= jump_at + 0.3:
				caught = true
				catch_at = elapsed
			if phase == "flight" and elapsed >= flight_duration():
				feedback = "Idealny chwyt!" if shot_score == 2 else ("Złapany!" if shot_score == 1 else "Dysk na trawie. Spróbuj skoczyć wcześniej.")
				score += shot_score
				rounds += 1
				phase = "land"
				elapsed = 0
			elif phase == "land" and elapsed >= 0.9:
				if rounds >= 5:
					stars = 3 if score >= 8 else (2 if score >= 5 else (1 if score > 0 else 0))
					_finish(score > 0)
				else:
					phase = "aim"
					caught = false
					wind = _rng.randf_range(-1, 1)
					elapsed = 0
		# A forgotten open round never runs indefinitely.
		if total >= 90 and phase != "result":
			stars = 0
			_finish(false)

func _tag_run() -> void:
	tag_from = tag_x
	tag_target = 0.2 if tag_x > 0.5 else 0.8
	# A feint can never follow another feint; the first invitation is genuine.
	feint_next = false if phase == "feint" or tag_offers == 0 else _rng.randf() < 0.3
	phase = "run"
	elapsed = 0

func _next_swap() -> void:
	swap_a = _rng.randi_range(0, 2)
	swap_b = (swap_a + _rng.randi_range(1, 2)) % 3
	phase = "shuffle"
	elapsed = 0

func cup_point(id: int) -> Vector2:
	if kind != "cups2": return super.cup_point(id)
	var slot := float(slots[id])
	var y := 0.48
	if phase == "shuffle" and id in [swap_a, swap_b]:
		var t := clampf(elapsed / swap_duration, 0, 1)
		var other := swap_b if id == swap_a else swap_a
		slot = lerpf(slot, float(slots[other]), smoothstep(0, 1, t))
		y += sin(t * PI) * (0.09 if id == swap_a else -0.09)
	return Vector2(0.2 + slot * 0.3, y)

func dog_point() -> Vector2:
	if kind == "tag": return Vector2(tag_x, 0.76)
	if kind == "cups2":
		return Vector2(cup_point(treat_cup).x if phase == "hint" or (phase == "guess" and assisted) else 0.5, 0.91)
	if kind == "frisbee":
		var t := clampf(elapsed / flight_duration(), 0, 1) if phase == "flight" else (1.0 if phase in ["land", "result"] else 0.0)
		var lift := sin(clampf((elapsed - jump_at) / 0.6, 0, 1) * PI) * 0.24 if jumped and phase == "flight" else 0.0
		return Vector2(disk_position_at(t).x - 0.04, 0.78 - lift)
	return super.dog_point()

func flight_duration() -> float: return 1.8 + disk_power * 1.2

func disk_point() -> Vector2:
	if phase == "aim": return Vector2(0.18, 0.40)
	var t := clampf(elapsed / flight_duration(), 0, 1)
	return disk_position_at(t)

func _dance_judge(grade: int) -> void:
	if dance_index >= dance_notes.size(): return
	dance_grades[dance_index] = grade
	dance_combo = dance_combo + 1 if grade > 0 else 0
	dance_best_combo = maxi(dance_best_combo, dance_combo)
	score += grade
	dance_last_clip = DANCE_CLIPS[dance_notes[dance_index]] if grade > 0 else "head_tilt_stand"
	dance_action_at = total
	feedback = ["Pudło — próbuj dalej", "Dobrze!", "Idealnie!"][grade]
	dance_index += 1

func cue() -> void:
	if kind == "freestyle":
		if phase == "ready":
			phase = "dance"
			total = 0
		elif phase == "dance" and dance_index < dance_notes.size():
			var error := absf(total - dance_note_time(dance_index))
			_dance_judge(2 if error <= 0.18 else (1 if error <= 0.4 else 0))
		return
	if kind == "cups2" and phase == "guess":
		assisted = true
		phase = "hint"
		elapsed = 0
	elif kind == "frisbee" and phase == "flight" and not jumped:
		jumped = true
		jump_at = elapsed
		# The jump peaks 0.3 seconds after the player's tap.
		var error := absf((elapsed + 0.3) / flight_duration() - catch_progress())
		shot_score = 2 if error <= 0.08 else (1 if error <= 0.18 else 0)
	elif kind not in EXTRA: super.cue()

func press(point: Vector2) -> void:
	if kind not in EXTRA:
		super.press(point)
		return
	if held or not _valid_point(point) or phase == "result": return
	if (kind == "tag" and phase in ["run", "bow", "feint"]) or (kind == "cups2" and phase == "guess") or (kind == "frisbee" and phase == "aim"):
		held = true
		_press_point = point
		_pressed_cup = cup_at(point)

func move(point: Vector2) -> void:
	if kind not in EXTRA: super.move(point)

func release(point: Vector2, cancelled: bool = false) -> void:
	if kind not in EXTRA:
		super.release(point, cancelled)
		return
	if not held: return
	held = false
	if cancelled or not _valid_point(point): return
	if kind == "tag" and point.distance_to(_press_point) < 0.08:
		var bounds := Rect2(Vector2(tag_x - 0.14, 0.40), Vector2(0.28, 0.40))
		if not bounds.has_point(point) or not bounds.has_point(_press_point): return
		if phase == "bow":
			score += 1
			feedback = "Złapana! %d/3" % score
			if score == 3:
				result_time = total
				stars = 3 if total <= 20 else (2 if total <= 32 else 1)
				_finish(true)
				return
		else: feedback = "Unik! Poczekaj na ukłon."
		_tag_run()
	elif kind == "cups2" and phase == "guess" and point.distance_to(_press_point) < 0.06:
		if _pressed_cup < 0 or cup_at(point) != _pressed_cup: return
		selected_cup = _pressed_cup
		stars = (2 if assisted else 3) if selected_cup == treat_cup else 0
		_finish(stars > 0)
	elif kind == "frisbee" and phase == "aim":
		if point.distance_to(_press_point) < 0.12: return
		disk_power = clampf(point.distance_to(_press_point), 0.15, 0.85)
		jumped = false
		caught = false
		shot_score = 0
		phase = "flight"
		elapsed = 0

func hint() -> String:
	if kind == "freestyle":
		if phase == "ready": return "Układ %d s · %d komendy. Dotknij W rytm, gdy kółko dotrze do linii. Poznane sztuczki: od 50%%. Dźwięk jest opcjonalny." % [int(dance_duration()), dance_notes.size()]
		if phase == "result": return "%d/%d pkt · %d/3 gwiazdki · seria %d. Rekord układu: %d pkt." % [score, dance_notes.size() * 2, stars, dance_best_combo, int(best_record.get("score", 0))]
		var next: String = TrainingSystem.LABELS[dance_notes[dance_index]] if dance_index < dance_notes.size() else "Finał"
		return "%s · %s · seria %d · %d s" % [next, feedback, dance_combo, ceili(dance_duration() - total)]
	if kind not in EXTRA: return super.hint()
	if phase == "result":
		var detail := "Złapania: %d/3" % score if kind == "tag" else ("Chwyty: %d/10 pkt" % score if kind == "frisbee" else ("Dobry kubek!" if success else "Smakołyk był pod innym kubkiem."))
		var record_detail := ""
		if kind == "tag" and float(best_record.get("seconds", 0)) > 0: record_detail = " · %.1f s" % best_record.seconds
		elif kind == "frisbee": record_detail = " · %d/10 pkt" % int(best_record.get("score", 0))
		elif kind == "cups2": record_detail = " · poziom %d" % int(best_record.get("score", 0))
		return "%s · %d/3 gwiazdki. Rekord: %d/3%s." % [detail, stars, int(best_record.get("stars", 0)), record_detail]
	if kind == "tag": return "%d s · %d/3. %s" % [ceili(clock_left), score, "TERAZ! Dotknij pieska w ukłonie." if phase == "bow" else ("Zmyłka — poczekaj na napis TERAZ!" if phase == "feint" else "Poczekaj na pełny ukłon i napis TERAZ!")]
	if kind == "cups2": return {"show": "Zapamiętaj kubek ze smakołykiem.", "shuffle": "Śledź kubek podczas tasowania…", "guess": "Wskaż kubek lub poproś Glorię o pomoc (2 zamiast 3 gwiazdek).", "hint": "Gloria węszy przy właściwym kubku."}.get(phase, "")
	return "Rzut %d/5 · Wiatr %s %d%% · %s" % [mini(rounds + 1, 5), "→" if wind >= 0 else "←", roundi(absf(wind) * 100), {"aim": "Przeciągnij i puść, żeby rzucić dyskiem.", "flight": "Złapany! Lądujemy z dyskiem." if caught else ("Skok!" if jumped else "Dotknij Skacz, zanim dysk dotrze do znacznika!"), "land": feedback}.get(phase, "")]
