class_name BondLevels
extends RefCounted

const THRESHOLDS := [0, 25, 50, 75, 100]
const NAMES := ["Poznajecie się", "Zaufanie", "Przyjaźń", "Bliskość", "Nierozłączni"]
static func level(pet: PetState) -> int:
	var result := 0
	for i in THRESHOLDS.size():
		if pet.bond >= THRESHOLDS[i]: result = i
	return result
# Hearts are earned at 100, 140, 190, 250, 320, 400, then every 80 points.
const HEART_THRESHOLDS := [100.0, 140.0, 190.0, 250.0, 320.0, 400.0]
const HEART_REWARDS := ["Nowa myśl i pamiątka w Albumie", "Spokojna chwila: blisko serca", "Ramka zdjęcia: Nasze serca", "Dekoracja: Serce przyjaźni"]
const HEART_THOUGHTS := ["Z Tobą zwykły dzień jest moim ulubionym.", "Znam już tyle Twoich gestów. Najbardziej lubię ten: chodź bliżej.", "Tyle wspólnych chwil, a ja wciąż cieszę się na następną."]
const HEART_RITUALS := ["Wtula się w Twoją dłoń. Przez chwilę słychać tylko spokojny oddech.", "Kładzie pyszczek blisko Ciebie. Nigdzie nie trzeba się spieszyć.", "Przymyka oczy przy Twoim boku. Dobrze mieć swój wspólny kącik."]

static func initial() -> Dictionary:
	return {"day": -1, "earned": 0.0}

static func valid(value: Variant) -> bool:
	return value is Dictionary and PetState.valid_number(value.get("day")) and value.day >= -1 and value.day == floor(value.day) and PetState.valid_number(value.get("earned")) and value.earned >= 0 and (value.day >= 0 or value.earned == 0)

static func heart(pet: PetState) -> int:
	if pet.bond < 100: return 0
	if pet.bond >= 400: return 6 + int(floor((pet.bond - 400) / 80.0))
	var result := 1
	for i in HEART_THRESHOLDS.size():
		if pet.bond >= HEART_THRESHOLDS[i]: result = i + 1
	return result

static func threshold(number: int) -> float:
	return HEART_THRESHOLDS[maxi(0, number - 1)] if number <= 6 else 400.0 + (number - 6) * 80.0

static func progress(pet: PetState) -> float:
	var current := heart(pet)
	if current == 0:
		var index := level(pet)
		return clampf((pet.bond - THRESHOLDS[index]) / 25.0 * 100.0, 0, 100)
	return clampf((pet.bond - threshold(current)) / (threshold(current + 1) - threshold(current)) * 100.0, 0, 100)

static func summary(pet: PetState) -> String:
	return "Nierozłączni ♥%d" % heart(pet) if heart(pet) > 0 else NAMES[level(pet)]

static func today(pet: PetState, local_seconds: float) -> float:
	return float(pet.bond_progress.earned) if int(pet.bond_progress.day) == PersonalitySystem.day_of(local_seconds) else 0.0

static func detail(pet: PetState, local_seconds: float) -> String:
	var target: String = "♥%d" % (heart(pet) + 1) if heart(pet) > 0 else NAMES[level(pet) + 1]
	# Never show 100% before actually crossing the threshold.
	return ("Do %s: %d%% · dziś +%.1f" % [target, mini(99, int(floor(progress(pet)))), today(pet, local_seconds)]).replace(".", ",")

static func add(pet: PetState, amount: float, local_seconds: float = -1.0) -> void:
	if not is_finite(amount) or amount <= 0: return
	if local_seconds < 0: local_seconds = PersonalitySystem.local_now()
	if not is_finite(local_seconds): return
	var previous := heart(pet)
	var total := snappedf(pet.bond + amount, 0.000001)
	if not is_finite(total) or total <= pet.bond: return
	var gained := total - pet.bond
	pet.bond = total
	var day := PersonalitySystem.day_of(local_seconds)
	if day > int(pet.bond_progress.day):
		pet.bond_progress = {"day": day, "earned": 0.0}
	# A clock rollback adds to the latest recorded day; it never resets its ledger.
	pet.bond_progress.earned = snappedf(float(pet.bond_progress.earned) + gained, 0.000001)
	var current := heart(pet)
	if current <= previous: return
	# A large gain can cross multiple rewards, but never creates unbounded entries.
	for number in range(maxi(2, previous + 1), mini(current, 5) + 1):
		pet.remember("bond_heart_%d" % number, "Nierozłączni ♥%d" % number, HEART_REWARDS[number - 2])
	if current >= 6:
		var title := "Nierozłączni ♥%d" % current
		var text: String = "Kolejne serce naszej wspólnej historii. " + HEART_THOUGHTS[(current - 6) % HEART_THOUGHTS.size()]
		if not pet.remember("bond_heart_latest", title, text):
			pet.add_journal_entry("bond_heart_latest", title, text, Time.get_unix_time_from_system())

static func thought(pet: PetState) -> String:
	return HEART_THOUGHTS[maxi(0, heart(pet) - 2) % HEART_THOUGHTS.size()]

# Existing daily history persists the budget without a save migration.
# Touch keeps responding after the bond budget is spent.
static func petting_gain(pet: PetState, now: float) -> float:
	var count := 0
	var day := PersonalitySystem.day_of(now)
	if not pet.history.is_empty():
		var bucket: Dictionary = pet.history[-1]
		if int(bucket.day) >= day: count = int(bucket.events.get("pet", 0))
	return 0.6 if count < 5 else (0.1 if count < 10 else 0.0)

static func ritual(s: GameSession) -> bool:
	var day := PersonalitySystem.day_of(s._local_now())
	if not s.writable or s.suspended or s.busy(false) or s.is_sleeping() or s.pet.bond < 75 or day <= int(s.pet.exploration.ritual_day): return false
	var before := s.pet.to_dict()
	s.pet.exploration.ritual_day = day
	NeedsSystem.change(s.pet, {"contact": 8})
	if not s.flush():
		s.pet = PetState.from_dict(before)
		return false
	if s.visitors.active(): s.visitors.finish(s, "Gość rusza dalej. Teraz czas dla Was.")
	s.clip_requested.emit("petted_stand")
	s.say(HEART_RITUALS[posmod(day, HEART_RITUALS.size())] if heart(s.pet) >= 3 else "Nasza spokojna chwila. Dobrze być razem.")
	s.changed.emit()
	return true
