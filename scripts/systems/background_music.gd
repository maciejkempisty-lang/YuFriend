class_name BackgroundMusic
extends AudioStreamPlayer

const TRACK = preload("res://assets/audio/music/room-video2.wav")
const LEVEL_DB := -18.0
var enabled := true
var backgrounded := false
var settings_path := ""
var fade: Tween

func start(path: String) -> void:
	settings_path = path
	var config := ConfigFile.new()
	if config.load(path) == OK:
		enabled = config.get_value("audio", "music_enabled", true) == true
	stream = TRACK
	volume_db = -60
	play()
	_update_playback()

func set_enabled(value: bool) -> void:
	enabled = value
	_update_playback()
	var config := ConfigFile.new()
	config.set_value("audio", "music_enabled", enabled)
	if config.save(settings_path) != OK:
		push_warning("Could not save music preference.")

func set_backgrounded(value: bool) -> void:
	backgrounded = value
	_update_playback()

func _update_playback() -> void:
	if fade != null: fade.kill()
	stream_paused = not enabled or backgrounded
	if not stream_paused:
		volume_db = -60
		fade = create_tween()
		fade.tween_property(self, "volume_db", LEVEL_DB, 1.0)
