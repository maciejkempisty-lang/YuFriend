class_name TugRecord
extends RefCounted

static func read(save_path: String) -> Dictionary:
	var config := ConfigFile.new()
	if config.load(save_path + ".tug.cfg") != OK: return {"best": 0, "seen": false}
	var value: Variant = config.get_value("tug", "best", 0)
	return {"best": value if value is int and value >= 0 and value <= 5 else 0, "seen": config.get_value("tug", "seen", false) == true}

static func write(save_path: String, best: int, seen: bool) -> bool:
	var previous := read(save_path)
	var config := ConfigFile.new()
	config.set_value("tug", "best", maxi(int(previous.best), clampi(best, 0, 5)))
	config.set_value("tug", "seen", seen or previous.seen)
	var path := save_path + ".tug.cfg"
	if config.save(path + ".tmp") != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK
