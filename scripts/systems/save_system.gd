class_name SaveSystem
extends RefCounted

const VERSION := 2
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
	if not PetState.valid_number(version) or (version != VERSION and version != 1):
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
	for field in [["history", []], ["habits", []], ["reflected_day", 0]]:
		if not result.has(field[0]): result[field[0]] = field[1]
	return result

func _preserve_legacy(source: String, version: int, pet_id: String) -> bool:
	if version >= VERSION: return true
	var keep := "%s.v%d" % [ProjectSettings.globalize_path(path), version]
	if FileAccess.file_exists(keep):
		var retained := _read(keep)
		if retained.status == "ok" and retained.version == version and retained.pet.pet_id == pet_id:
			return true
		last_error = "Kopia starszego zapisu wymaga sprawdzenia. Dotychczasowe pliki zachowano."
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
