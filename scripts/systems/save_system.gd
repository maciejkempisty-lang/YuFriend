class_name SaveSystem
extends RefCounted

const VERSION := 1
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
	if data.get("schema_version") != VERSION:
		return {"status": "unsupported"}
	if not data.get("pet") is Dictionary:
		return {"status": "invalid"}
	var pet := PetState.from_dict(data.pet)
	return {"status": "ok", "pet": pet} if pet != null else {"status": "invalid"}

func load_pet() -> Dictionary:
	var primary := _read(path)
	if primary.status == "ok":
		return {"pet": primary.pet, "status": "loaded", "writable": true}
	if primary.status == "unsupported":
		return {"pet": PetState.create(), "status": "unsupported", "writable": false}
	var backup := _read(path + ".bak")
	if backup.status == "ok":
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
	if _read(absolute).status == "unsupported":
		last_error = "Ten zapis pochodzi z innej wersji gry."
		return false
	if _read(absolute).status == "ok":
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
