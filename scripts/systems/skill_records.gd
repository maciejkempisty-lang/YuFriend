class_name SkillRecords
extends RefCounted

static func read(save_path: String, kind: String) -> Dictionary:
	var result := {"stars": 0, "score": 0, "seconds": 0.0}
	var config := ConfigFile.new()
	if config.load(save_path + ".games.cfg") != OK: return result
	for key in ["stars", "score"]:
		var value: Variant = config.get_value(kind, key, 0)
		var limit := 3 if key == "stars" else (24 if kind.begins_with("freestyle_") else (12 if kind == "bubbles" else 10))
		if value is int and value >= 0 and value <= limit: result[key] = value
	var seconds: Variant = config.get_value(kind, "seconds", 0.0)
	if (seconds is int or seconds is float) and is_finite(seconds) and seconds >= 0 and seconds <= 45: result.seconds = float(seconds)
	return result

static func write(save_path: String, game: SkillPlaySystem) -> bool:
	if game.kind not in SkillPlaySystem.EXTRA or game.phase != "result" or not game.settled: return false
	var path := save_path + ".games.cfg"
	var config := ConfigFile.new()
	var error := config.load(path)
	# Never overwrite an unreadable previous record with an empty file.
	if error not in [OK, ERR_FILE_NOT_FOUND]: return false
	var section := game.record_key()
	var old := read(save_path, section)
	config.set_value(section, "stars", maxi(old.stars, game.stars))
	var score := game.level + 1 if game.kind == "cups2" and game.success else game.score
	config.set_value(section, "score", maxi(old.score, score))
	var seconds: float = old.seconds
	if game.kind == "tag" and game.score == 3 and game.result_time > 0:
		seconds = game.result_time if seconds <= 0 else minf(seconds, game.result_time)
	config.set_value(section, "seconds", seconds)
	if config.save(path + ".tmp") != OK: return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK
