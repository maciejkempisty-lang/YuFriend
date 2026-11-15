class_name LocalReminders
extends RefCounted

var directory := ""
var supported := false
var enabled := false
var request := ""
var write_error := false

func start(save_path: String, ios: bool = OS.get_name() == "iOS") -> void:
	directory = save_path.get_base_dir()
	supported = ios
	var preference := _read("reminders.json")
	enabled = preference.get("enabled", false) == true
	request = str(preference.get("request", ""))

func set_enabled(value: bool) -> bool:
	if not supported: return false
	var token := "%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	var path := directory.path_join("reminders.json")
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		write_error = true
		return false
	file.store_string(JSON.stringify({"enabled": value, "request": token}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(path + ".tmp", path) != OK:
		write_error = true
		return false
	enabled = value
	request = token
	write_error = false
	return true

func status_text() -> String:
	if not supported: return "Powiadomienia są dostępne na iPhonie."
	if write_error: return "Nie udało się zapisać ustawienia. Spróbuj ponownie."
	if not enabled: return "Do 2 dziennie, między 9:00 a 21:00."
	var response := _read("reminders-status.json")
	if response.get("request", "") != request:
		return "Czekam na potwierdzenie z iOS…"
	match response.get("status", ""):
		"on": return "Do 2 dziennie, między 9:00 a 21:00."
		"denied": return "Zezwól na powiadomienia YuFriend w Ustawieniach iPhone’a."
		"storage_error": return "Powiadomienia wstrzymane: nie można odczytać lub zapisać ich ustawień."
		"clock_error": return "Powiadomienia wstrzymane do wyrównania czasu urządzenia."
		"error": return "Nie udało się włączyć powiadomień. Spróbuj ponownie."
		_: return "Potwierdź zgodę na powiadomienia w iOS."

func _read(filename: String) -> Dictionary:
	var path := directory.path_join(filename)
	if not FileAccess.file_exists(path): return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 4096: return {}
	var value = JSON.parse_string(file.get_as_text())
	return value if value is Dictionary else {}
