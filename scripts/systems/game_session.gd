class_name GameSession
extends Node

signal changed
signal feedback(text: String)
signal clip_requested(clip: String)
signal destination_requested(ratio: float)
signal performance_requested(clip: String, trial_id: int)
signal save_status(ok: bool)

var pet: PetState
var training := TrainingSystem.new()
var storage: SaveSystem
var writable: bool = true
var save_ok: bool = true
var suspended: bool = false
var active: bool = false
var pose: String = "stand"
var activity: String = "idle"
var activity_left: float = 0.0
var cooldowns: Dictionary = {}
var last_message: String = "Dotknij pieska, żeby go pogłaskać. Miska i legowisko też czekają."
var _refresh_left: float = 0.0
var _save_left: float = 25.0
var _brain_left: float = 8.0
var performance_done: bool = true

func start(save_path: String = "user://pet.json") -> void:
	storage = SaveSystem.new(save_path)
	var loaded := storage.load_pet()
	pet = loaded.pet
	writable = loaded.writable
	var away := NeedsSystem.catch_up(pet, Time.get_unix_time_from_system())
	var news := _reflect()
	if writable and (loaded.status == "new" or away > 300): _note("visit")
	if loaded.status == "migration_failed":
		last_message = storage.last_error
	elif not writable:
		last_message = "Nie udało się odczytać postępu. Dotychczasowy zapis pozostaje zachowany."
	elif loaded.status == "recovered":
		last_message = "Postęp został odzyskany z kopii. Możecie grać dalej."
	elif not news.is_empty():
		last_message = news
	elif away > 300:
		last_message = _greeting()
	active = true
	if pet.resting:
		activity = "sleep"
		clip_requested.emit("sleep")
	flush()
	changed.emit()

func _process(delta: float) -> void:
	if not active or suspended: return
	NeedsSystem.advance(pet, delta)
	for key in cooldowns:
		cooldowns[key] = maxf(0, float(cooldowns[key]) - delta)
	var result := training.advance(delta, performance_done)
	if not result.is_empty():
		say(result.message)
		if result.event == "miss": _note("miss")
		elif result.event == "expired": _note("reward_missed")
		if result.event == "ready":
			clip_requested.emit("sit_idle" if pose == "sit" else "idle")
		elif result.event in ["miss", "expired"]:
			clip_requested.emit("sit_idle" if pose == "sit" else "head_tilt_stand")
		changed.emit()
	if activity_left > 0:
		activity_left -= delta
		if activity_left <= 0:
			activity = "idle"
			clip_requested.emit("sit_idle" if pose == "sit" else "idle")
	if training.phase == "idle" and activity == "idle" and not pet.resting:
		_brain_left -= delta
		if _brain_left <= 0:
			_brain_left = randf_range(9, 15)
			_spontaneous()
	_refresh_left -= delta
	if _refresh_left <= 0:
		_refresh_left = 0.15
		changed.emit()
	_save_left -= delta
	if _save_left <= 0:
		# Gra otwarta przez północ też zamyka poprzedni dzień.
		var news := _reflect()
		if not news.is_empty() and not busy(): say(news)
		flush()

func _local_now() -> float:
	return PersonalitySystem.local_now()

func _note(event: String) -> void:
	if writable: PersonalitySystem.record(pet, event, _local_now())

func _reflect() -> String:
	if not writable: return ""
	var notes := PersonalitySystem.reflect(pet, _local_now())
	return "" if notes.is_empty() else "%s: %s" % [notes[0].title, notes[0].detail]

func _lively() -> bool:
	return pet.habits.has("time_" + PersonalitySystem.part_of(_local_now()))

func _greeting() -> String:
	if _lively(): return "%s czekał na Ciebie o swojej ulubionej porze!" % pet.pet_name
	return "Dobrze, że jesteś. %s czeka na wspólną chwilę." % pet.pet_name

# Samodzielna decyzja psa: odpoczynek, zachowanie wynikające z nawyku albo spacer.
func _spontaneous(roll: float = -1.0) -> void:
	if float(pet.needs.energy) < 28:
		act("rest", false)
		return
	var lively := _lively()
	var options: Array = []
	if pet.habits.has("cuddler") and float(pet.needs.contact) < 80: options.append("cuddler")
	if pet.habits.has("playful") and float(pet.needs.play) < 80: options.append("playful")
	if pet.habits.has("student") and pose != "sit" and training.readiness(pet, "sit").is_empty(): options.append("student")
	var chance := randf() if roll < 0 else roll
	if not options.is_empty() and chance < (0.6 if lively else 0.35):
		show_habit(options[randi() % options.size()])
	elif randf() < float(pet.traits.curiosity) + (0.15 if lively else 0.0):
		move_to(randf_range(0.25, 0.75), false)

func show_habit(id: String) -> void:
	activity = "habit"
	activity_left = 1.5
	match id:
		"cuddler":
			pose = "stand"
			clip_requested.emit("tail_wag_stand")
			say("%s macha ogonem i czeka na głaskanie." % pet.pet_name)
		"playful":
			pose = "stand"
			clip_requested.emit("play_bow")
			say("%s sam zaprasza Cię do zabawy." % pet.pet_name)
		"student":
			pose = "sit"
			clip_requested.emit("sit_down")
			say("%s siada sam z siebie i czeka na komendę." % pet.pet_name)
		_:
			activity = "idle"
			activity_left = 0
			return
	changed.emit()

func say(text: String) -> void:
	last_message = text
	feedback.emit(text)

func busy() -> bool:
	# Zachowanie z nawyku jest zaproszeniem — gracz może na nie od razu odpowiedzieć.
	return training.phase != "idle" or (activity_left > 0 and activity != "habit") or activity == "walk"

func act(action: String, by_player: bool = true) -> bool:
	if not writable or suspended: return false
	if busy():
		say("Jeszcze chwilka — kończymy tę czynność.")
		return false
	if float(cooldowns.get(action, 0)) > 0:
		say("Daj mu chwilę nacieszyć się tą chwilą.")
		return false
	if action == "rest":
		pet.resting = not pet.resting
		pose = "stand"
		activity = "sleep" if pet.resting else "idle"
		clip_requested.emit("sleep" if pet.resting else "idle")
		say("Miękkie legowisko i spokojny odpoczynek." if pet.resting else "Wyspany i gotowy na Wasz dzień.")
		if pet.resting: pet.remember("rest", "Własne miejsce", "Pierwsza spokojna drzemka w nowym domu.")
		if pet.resting and by_player: _note("rest")
		flush()
		changed.emit()
		return true
	if pet.resting:
		say("Najpierw delikatnie obudź pieska.")
		return false
	pose = "stand"
	activity = action
	activity_left = 2.0
	match action:
		"feed":
			NeedsSystem.change(pet, {"fullness": 22})
			cooldowns[action] = 10.0
			clip_requested.emit("eat_loop")
			say("Mała porcja. %s zajada z apetytem." % pet.pet_name)
			pet.remember("feed", "Pierwsza wspólna miska", "Małe rytuały budują poczucie bezpieczeństwa.")
		"pet":
			NeedsSystem.change(pet, {"contact": 18, "play": 3})
			pet.bond = minf(100, pet.bond + 0.6)
			cooldowns[action] = 4.0
			clip_requested.emit("petted_stand")
			say("Przymyka oczy. Lubi być blisko Ciebie.")
			pet.remember("pet", "Coraz bliżej", "Pierwsze głaskanie i odrobina zaufania.")
		"play":
			NeedsSystem.change(pet, {"play": 24, "contact": 8, "energy": -5, "hygiene": -3})
			cooldowns[action] = 8.0
			clip_requested.emit("play_bow")
			say("Przednie łapki nisko… zaprasza Cię do zabawy!")
			pet.remember("play", "Zabawa we dwoje", "Pierwszy wspólny czas na zabawę.")
		"clean":
			NeedsSystem.change(pet, {"hygiene": 25, "contact": 5})
			cooldowns[action] = 12.0
			clip_requested.emit("petted_stand")
			say("Kilka ruchów szczotką i sierść znów jest miękka.")
			pet.remember("clean", "Mały rytuał pielęgnacji", "Spokojne czesanie i chwila bliskości.")
		_:
			activity = "idle"
			activity_left = 0
			return false
	_note(action)
	flush()
	changed.emit()
	return true

func move_to(ratio: float, announce: bool = true) -> void:
	if not writable or busy() or pet.resting or suspended: return
	pose = "stand"
	activity = "walk"
	activity_left = 0
	destination_requested.emit(clampf(ratio, 0.23, 0.77))
	clip_requested.emit("walk")
	if announce: say("Już idę! Małe łapki odkrywają pokój.")

func destination_reached() -> void:
	if activity != "walk": return
	activity = "idle"
	clip_requested.emit("idle")
	changed.emit()

func performance_finished(trial_id: int) -> void:
	if trial_id == training.trial_id and training.phase == "attempt" and not suspended:
		performance_done = true

func begin_training(key: String, guided: bool) -> bool:
	if not writable or suspended: return false
	if (activity_left > 0 and activity != "habit") or activity == "walk":
		say("Poczekaj, aż piesek skończy tę czynność.")
		return false
	var tired := pet.fatigue >= 50
	var result := training.begin(pet, key, guided)
	if not result.ok:
		say(result.message)
		return false
	activity_left = 0
	_note("train_guided" if guided else "train_free")
	if tired: _note("train_tired")
	activity = "idle"
	performance_done = false
	pose = "sit" if key in ["sit", "paw"] and training.will_succeed else "stand"
	var clip: String = {"come": "walk", "sit": "sit_down", "paw": "give_paw"}[key] if training.will_succeed else "head_tilt_stand"
	if key == "come" and training.will_succeed: destination_requested.emit(0.62)
	performance_requested.emit(clip, training.trial_id)
	say(result.message)
	flush()
	changed.emit()
	return true

func give_reward(kind: String) -> bool:
	if suspended or not writable: return false
	var result := training.reward(pet, kind)
	if not result.ok:
		say(result.message)
		return false
	_note("reward_" + kind)
	activity = "happy"
	activity_left = 1.4
	clip_requested.emit("tail_wag_sit" if pose == "sit" else "tail_wag_stand")
	say(result.message)
	flush()
	changed.emit()
	return true

func rename_pet(value: String) -> bool:
	var clean := value.strip_edges().replace("\n", " ").replace("\t", " ")
	if not writable or clean.is_empty(): return false
	pet.pet_name = clean.left(24)
	flush()
	changed.emit()
	return true

func change_skin(value: String) -> void:
	if not writable or not ["simple", "pixel"].has(value): return
	pet.skin = value
	flush()
	changed.emit()

func flush() -> bool:
	if pet == null or storage == null: return false
	_save_left = 25.0
	if not writable:
		save_ok = false
		return false
	pet.last_seen_at = maxf(pet.last_seen_at, Time.get_unix_time_from_system())
	save_ok = storage.save_pet(pet)
	save_status.emit(save_ok)
	return save_ok

func suspend_session() -> void:
	if not active or suspended: return
	training.cancel()
	activity_left = 0
	activity = "sleep" if pet.resting else "idle"
	suspended = true
	flush()

func resume_session() -> void:
	if not active or not suspended: return
	var away := NeedsSystem.catch_up(pet, Time.get_unix_time_from_system())
	suspended = false
	clip_requested.emit("sleep" if pet.resting else "idle")
	pose = "stand"
	var news := _reflect()
	if away > 300:
		_note("visit")
		say(news if not news.is_empty() else _greeting())
	elif not news.is_empty():
		say(news)
	flush()
	changed.emit()
