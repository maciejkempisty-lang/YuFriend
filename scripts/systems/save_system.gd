class_name SaveSystem
extends RefCounted

const VERSION := 13
const MAX_BYTES := 1024 * 1024
var path: String
var last_error: String = ""

func _init(save_path: String = "user://pet.json") -> void:
	path = save_path

func _read(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"status": "missing"}
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null or file.get_length() > MAX_BYTES:
		return {"status": "invalid"}
	var parsed := JSON.new()
	if parsed.parse(file.get_as_text()) != OK or not parsed.data is Dictionary:
		return {"status": "invalid"}
	var data: Dictionary = parsed.data
	var version: Variant = data.get("schema_version")
	if not PetState.valid_number(version) or (version != VERSION and version != 1 and version != 2 and version != 3 and version != 4 and version != 5 and version != 6 and version != 7 and version != 8 and version != 9 and version != 10 and version != 11 and version != 12):
		return {"status": "unsupported"}
	if not data.get("pet") is Dictionary:
		return {"status": "invalid"}
	var pet := PetState.from_dict(migrate(data.pet, int(version)))
	if pet == null:
		return {"status": "invalid"}
	return {"status": "ok", "pet": pet, "version": int(version)}

# Uzupełnia starszy zapis do bieżącego schematu, nie zmieniając istniejących pól.
static func migrate(pet_data: Dictionary, version: int) -> Dictionary:
	if version >= VERSION:
		return pet_data
	var result := pet_data.duplicate(true)
	# 1 → 2: dziennik zdarzeń, nawyki i znacznik przetworzonego dnia.
	if version == 1:
		for field in [["history", []], ["habits", []], ["reflected_day", 0]]:
			if not result.has(field[0]): result[field[0]] = field[1]
	# 2 → 3: deterministic quirks, discoveries, daily mood and the latest away report.
	if version < 3 and not result.has("life") and PetState.valid_number(result.get("personality_seed")):
		result.life = PetState.initial_life(int(result.personality_seed))
	# 3 → 4: responses to invitations and touch-play history. Existing life stays intact.
	if version < 4 and not result.has("social"): result.social = PetState.initial_social()
	# 4 → 5: persistent, gradual daily rhythm and bounded automatic naps.
	if version < 5 and not result.has("rhythm"): result.rhythm = DailyRhythm.initial()
	if result.get("skills") is Dictionary:
		for key in ["lie", "bow", "bark", "stay", "spin", "roll"]:
			if version < ({"lie": 6, "bow": 6, "bark": 6, "stay": 7, "spin": 8, "roll": 8}[key]) and not result.skills.has(key): result.skills[key] = {"mastery": 0.0, "attempts": 0, "successes": 0}
	if version < 8 and not result.has("photos"): result.photos = []
	if version < 8 and not result.has("decor"): result.decor = []
	if version < 10 and not result.has("yard_record"): result.yard_record = 0.0
	if version < 9 and not result.has("practice"): result.practice = PracticeSystem.initial()
	if version < 11 and not result.has("fetch_rewards"): result.fetch_rewards = FetchRewards.initial()
	if version < 12 and not result.has("yard_routines"): result.yard_routines = YardRoutines.initial()
	if version < 13 and not result.has("exploration"): result.exploration = DiggingSystem.initial()
	return result

func _preserve_legacy(source: String, version: int, pet_id: String) -> bool:
	if version >= VERSION: return true
	var keep := "%s.v%d" % [ProjectSettings.globalize_path(path), version]
	if FileAccess.file_exists(keep):
		var retained := _read(keep)
		if retained.status == "ok" and retained.version == version and retained.pet.pet_id == pet_id and FileAccess.get_sha256(keep) == FileAccess.get_sha256(source):
			return true
		# A foreign snapshot belongs to its owner. Retain our source alongside it.
		var source_hash := FileAccess.get_sha256(source)
		if source_hash.is_empty():
			last_error = "Nie udało się odczytać starszego zapisu do kopii."
			return false
		keep += "." + source_hash
		if FileAccess.file_exists(keep):
			var alternate := _read(keep)
			if alternate.status == "ok" and alternate.version == version and alternate.pet.pet_id == pet_id and FileAccess.get_sha256(keep) == source_hash:
				return true
			last_error = "Nie udało się sprawdzić dodatkowej kopii. Dotychczasowe pliki zachowano."
			return false
	if DirAccess.dir_exists_absolute(keep):
		last_error = "Nie udało się zabezpieczyć starszego zapisu. Dotychczasowy postęp zachowano."
		return false
	var temporary := keep + ".tmp"
	if DirAccess.copy_absolute(ProjectSettings.globalize_path(source), temporary) != OK:
		last_error = "Nie udało się zabezpieczyć starszego zapisu. Dotychczasowy postęp zachowano."
		return false
	var copied := _read(temporary)
	if copied.status != "ok" or copied.version != version or copied.pet.pet_id != pet_id:
		last_error = "Nie udało się sprawdzić kopii starszego zapisu. Dotychczasowy postęp zachowano."
		return false
	if DirAccess.rename_absolute(temporary, keep) != OK:
		last_error = "Nie udało się zatwierdzić kopii starszego zapisu. Dotychczasowy postęp zachowano."
		return false
	return true

func load_pet() -> Dictionary:
	last_error = ""
	var primary := _read(path)
	if primary.status == "ok":
		if not _preserve_legacy(path, primary.version, primary.pet.pet_id):
			return {"pet": primary.pet, "status": "migration_failed", "writable": false}
		return {"pet": primary.pet, "status": "loaded", "writable": true}
	if primary.status == "unsupported":
		return {"pet": PetState.create(), "status": "unsupported", "writable": false}
	var backup := _read(path + ".bak")
	if backup.status == "ok":
		if not _preserve_legacy(path + ".bak", backup.version, backup.pet.pet_id):
			return {"pet": backup.pet, "status": "migration_failed", "writable": false}
		return {"pet": backup.pet, "status": "recovered", "writable": true}
	if primary.status == "missing" and backup.status == "missing":
		return {"pet": PetState.create(), "status": "new", "writable": true}
	return {"pet": PetState.create(), "status": "invalid", "writable": false}

func save_pet(pet: PetState) -> bool:
	last_error = ""
	if PetState.from_dict(pet.to_dict()) == null:
		last_error = "Nieprawidłowy stan pieska."
		return false
	var absolute := ProjectSettings.globalize_path(path)
	var directory := absolute.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(directory) != OK:
		last_error = "Nie udało się otworzyć miejsca na zapis."
		return false
	var temporary := absolute + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		last_error = "Nie udało się zapisać postępu."
		return false
	file.store_string(JSON.stringify({"schema_version": VERSION, "pet": pet.to_dict()}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or _read(temporary).status != "ok":
		last_error = "Nie udało się sprawdzić zapisu."
		return false
	# Keep the last validated primary as the backup. If primary is corrupt,
	# retain the recovery backup instead of replacing it with corrupt bytes.
	var primary := _read(absolute)
	if primary.status == "unsupported":
		last_error = "Ten zapis pochodzi z innej wersji gry."
		return false
	# Również bez wcześniejszego load_pet() nie wolno utracić kopii v1.
	var backup := _read(absolute + ".bak")
	for candidate in [[absolute, primary], [absolute + ".bak", backup]]:
		var state: Dictionary = candidate[1]
		if state.status == "ok" and not _preserve_legacy(candidate[0], state.version, state.pet.pet_id):
			return false
	if primary.status == "ok":
		if DirAccess.copy_absolute(absolute, absolute + ".bak.tmp") != OK:
			last_error = "Nie udało się przygotować kopii zapisu."
			return false
		if DirAccess.rename_absolute(absolute + ".bak.tmp", absolute + ".bak") != OK:
			last_error = "Nie udało się zachować kopii zapisu."
			return false
	if DirAccess.rename_absolute(temporary, absolute) != OK:
		last_error = "Nie udało się zatwierdzić zapisu."
		return false
	return true
