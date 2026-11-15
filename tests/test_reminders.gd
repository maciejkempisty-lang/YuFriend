extends SceneTree

var passed := 0
var failed := 0

func check(value: bool, message: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error(message)

func _initialize() -> void:
	var test_root := OS.get_environment("YUFRIEND_TEST_ROOT")
	var directory := ("user://" if test_root.is_empty() else test_root).path_join("qa-reminders-%s" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	var path := directory.path_join("pet.json")
	var save := FileAccess.open(path, FileAccess.WRITE)
	save.store_string("untouched-game-save")
	save.close()
	var reminders := LocalReminders.new()
	reminders.start(path, true)
	check(not reminders.enabled and not FileAccess.file_exists(directory.path_join("reminders.json")), "No permission request or file on first launch")
	check(reminders.set_enabled(true), "Explicit opt-in saved")
	var token := reminders.request
	check(reminders.status_text().contains("Czekam"), "Wait for native acknowledgement")
	var restored := LocalReminders.new()
	restored.start(path, true)
	check(restored.enabled and restored.request == token, "Preference survives restart without new request")
	var status := FileAccess.open(directory.path_join("reminders-status.json"), FileAccess.WRITE)
	status.store_string(JSON.stringify({"request": "old", "status": "on"}))
	status.close()
	check(restored.status_text().contains("Czekam"), "Old native reply cannot acknowledge new request")
	status = FileAccess.open(directory.path_join("reminders-status.json"), FileAccess.WRITE)
	status.store_string(JSON.stringify({"request": token, "status": "denied"}))
	status.close()
	check(restored.status_text().contains("Ustawieniach iPhone"), "Denied permission has actionable copy")
	check(restored.set_enabled(false) and not restored.enabled and restored.request != token, "Opt-out is an explicit new command")
	var desktop := LocalReminders.new()
	desktop.start(path, false)
	check(not desktop.set_enabled(true), "Unsupported platform cannot enqueue commands")
	check(FileAccess.get_file_as_string(path) == "untouched-game-save", "Preference changes never touch the game save")
	var broken := LocalReminders.new()
	broken.start(directory.path_join("missing/pet.json"), true)
	check(not broken.set_enabled(true) and not broken.enabled and broken.write_error, "Write failure does not pretend to enable")
	for filename in DirAccess.get_files_at(directory): DirAccess.remove_absolute(directory.path_join(filename))
	DirAccess.remove_absolute(directory)
	print("REMINDER SETTINGS RESULTS: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)
