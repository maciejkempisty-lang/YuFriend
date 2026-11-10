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
	if not writable:
		last_message = "Nie udało się odczytać postępu. Dotychczasowy zapis pozostaje zachowany."
	elif loaded.status == "recovered":
		last_message = "Postęp został odzyskany z kopii. Możecie grać dalej."
	elif away > 300:
		last_message = "Dobrze, że jesteś. %s czeka na wspólną chwilę." % pet.pet_name
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
			if float(pet.needs.energy) < 28:
				act("rest")
			elif randf() < float(pet.traits.curiosity):
				move_to(randf_range(0.25, 0.75), false)
	_refresh_left -= delta
	if _refresh_left <= 0:
		_refresh_left = 0.15
		changed.emit()
	_save_left -= delta
	if _save_left <= 0:
		flush()

func say(text: String) -> void:
	last_message = text
	feedback.emit(text)

func busy() -> bool:
	return training.phase != "idle" or activity_left > 0 or activity == "walk"

func act(action: String) -> bool:
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
	flush()
	changed.emit()
	return true

func move_to(ratio: float, announce: bool = true) -> void:
	if not writable or busy() or pet.resting or suspended: return
	pose = "stand"
	activity = "walk"
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
	if activity_left > 0 or activity == "walk":
		say("Poczekaj, aż piesek skończy tę czynność.")
		return false
	var result := training.begin(pet, key, guided)
	if not result.ok:
		say(result.message)
		return false
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
	NeedsSystem.catch_up(pet, Time.get_unix_time_from_system())
	suspended = false
	clip_requested.emit("sleep" if pet.resting else "idle")
	pose = "stand"
	flush()
	changed.emit()
