extends SceneTree
var failed := 0
var now := 10.0
func check(ok: bool, label: String) -> void:
	if not ok:
		failed += 1
		push_error(label)
func trial(gentle := false) -> Array:
	var pet := PetState.create(123)
	pet.needs.energy = 100
	pet.needs.fullness = 100
	var training := TrainingSystem.new()
	training.marker_clock = func(): return now
	check(training.begin(pet, "sit", false, 0.99, true, gentle).ok and training.will_succeed, "marker trial does not roll for success")
	return [pet, training]
func _initialize() -> void:
	for entry in [[0.0, "perfect", 10.0], [0.18, "perfect", 10.0], [0.4, "good", 6.0], [0.64, "good", 6.0]]:
		now = 10
		var pair := trial()
		var pet: PetState = pair[0]
		var training: TrainingSystem = pair[1]
		training.sitting_contact(training.trial_id - 1)
		check(training.marker_contact_at < 0, "stale animation cannot open marker")
		training.sitting_contact(training.trial_id)
		now += entry[0]
		training.sitting_contact(training.trial_id)
		check(training.mark_sit().ok and training.marker_grade == entry[1], "timing grade " + str(entry[0]))
		now += 120
		training.advance(120, true)
		check(training.phase == "reward", "reward has no second reflex deadline")
		var before: float = pet.skills.sit.mastery
		check(training.reward(pet, "treat").ok and pet.skills.sit.mastery == before + entry[2], "grade controls mastery gain")
		check(not training.reward(pet, "treat").ok, "duplicate reward rejected")
	for delay in [-1.0, 0.8]:
		now = 10
		var pair := trial()
		var pet: PetState = pair[0]
		var training: TrainingSystem = pair[1]
		if delay >= 0: training.sitting_contact(training.trial_id); now += delay
		var before := pet.to_dict()
		check(not training.mark_sit().ok and not training.reward(pet, "treat").ok, "early/late marker earns no reward")
		check(pet.to_dict() == before, "mistake removes no progress")
	now = 10
	var pair := trial(true)
	var training: TrainingSystem = pair[1]
	training.sitting_contact(training.trial_id)
	now += 0.8
	check(training.mark_sit().ok, "gentle setting widens good window")
	training.cancel()
	check(not training.reward(pair[0], "treat").ok, "cancel consumes pending reward")
	var pet: PetState = pair[0]
	pet.skills.sit.mastery = 100
	pet.fatigue = 0
	training.begin(pet, "sit", false, 1.0, true)
	training.sitting_contact(training.trial_id)
	training.mark_sit()
	training.reward(pet, "praise")
	check(pet.skills.sit.mastery == 100, "mastered Gloria trick stays mastered")
	now = 10
	pair = trial()
	training = pair[1]
	training.sitting_contact(training.trial_id)
	now += 0.7
	check(training.advance(0.7).get("event") == "marker_miss" and training.phase == "idle", "unmarked sit expires without reward")
	pair = trial()
	training = pair[1]
	check(training.advance(20).get("event") == "marker_miss", "missing animation cannot leave a stuck trial")
	var gesture := SitLure.new()
	gesture.size = Vector2(260, 230)
	var completed := [0]
	gesture.completed.connect(func(): completed[0] += 1)
	gesture.press(gesture.point(0), 1)
	gesture.move(gesture.point(1), 1)
	check(gesture.pointer == -2 and completed[0] == 0, "teleport gesture rejected")
	gesture.press(gesture.point(0), 1)
	for i in range(1,11):
		gesture._process(0.1)
		gesture.move(gesture.point(i / 10.0), 1)
	gesture.release(gesture.point(1), 2)
	check(completed[0] == 0, "second finger cannot finish")
	gesture.release(gesture.point(1), 1)
	gesture.release(gesture.point(1), 1)
	check(completed[0] == 1, "smooth correctly paced lure completes once")
	gesture.free()
	var short_lure := SitLure.new()
	short_lure.short_signal = true
	short_lure.size = Vector2(260, 230)
	short_lure.press(short_lure.point(0), 0)
	short_lure._process(1.6)
	check(short_lure.pointer == -2 and not short_lure.finished, "slow lure loses attention without success")
	short_lure.press(short_lure.point(0), 0)
	for i in range(1, 11):
		short_lure._process(0.04)
		short_lure.move(short_lure.point(i / 10.0), 0)
	short_lure.release(short_lure.point(1), 0)
	check(short_lure.finished, "short learned signal accepts smooth shorter movement")
	short_lure.free()
	print("SIT MARKER FAILURES: ", failed)
	quit(1 if failed else 0)
