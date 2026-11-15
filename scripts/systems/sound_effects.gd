class_name SoundEffects
extends Node

# One-shots only. Missing optional recordings remain silent while art/audio is in production.
const DIRECTORY := "res://assets/audio/sfx/"
const GROUPS := {
	"bark": ["puppy_bark", 3, -14.0, 2.0],
	"step": ["paw_wood", 4, -24.0, 0.16],
	"eat": ["kibble", 2, -18.0, 0.5],
	"treat": ["treat", 1, -17.0, 0.5],
	"pet": ["pet_stroke", 2, -20.0, 0.4],
	"brush": ["brush", 2, -20.0, 0.5],
	"ball_bounce": ["ball_bounce", 3, -20.0, 0.15],
	"ball_roll": ["ball_roll", 1, -20.0, 0.5],
	"success": ["training_success", 0, -18.0, 0.5],
	"ui": ["ui_tap", 0, -24.0, 0.08],
}
const MAX_VOICES := 4
var enabled := true
var backgrounded := false
var settings_path := ""
var recordings: Dictionary = {}
var players: Array[AudioStreamPlayer] = []
var _last_played: Dictionary = {}
var _last_variant: Dictionary = {}
var _random := RandomNumberGenerator.new()

func start(path: String) -> void:
	settings_path = path
	var config := ConfigFile.new()
	if config.load(path) == OK:
		enabled = config.get_value("audio", "effects_enabled", true) == true
	_random.randomize()
	for id in GROUPS:
		var group: Array = GROUPS[id]
		var variants: Array[AudioStream] = []
		for index in maxi(1, group[1]):
			var filename: String = group[0] + ("_%02d" % (index + 1) if group[1] > 0 else "") + ".wav"
			if not ResourceLoader.exists(DIRECTORY + filename): continue
			var recording := load(DIRECTORY + filename) as AudioStream
			if recording == null or recording.get_length() <= 0 or recording.get_length() > 3: continue
			# Import settings must not accidentally make a short effect play forever.
			if recording is AudioStreamWAV:
				recording = recording.duplicate()
				recording.loop_mode = AudioStreamWAV.LOOP_DISABLED
			variants.append(recording)
		recordings[id] = variants
	if players.is_empty():
		for index in MAX_VOICES:
			var player := AudioStreamPlayer.new()
			add_child(player)
			players.append(player)

func play_effect(id: String) -> bool:
	if not enabled or backgrounded or not GROUPS.has(id): return false
	var variants: Array = recordings.get(id, [])
	if variants.is_empty(): return false
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(_last_played.get(id, -INF)) < float(GROUPS[id][3]): return false
	var available: AudioStreamPlayer
	for player in players:
		if not player.playing:
			available = player
			break
	# Drop excess sounds instead of layering an unbounded pile of effects.
	if available == null: return false
	var index := _random.randi_range(0, variants.size() - 1)
	if variants.size() > 1 and index == _last_variant.get(id, -1):
		index = (index + 1) % variants.size()
	available.stream = variants[index]
	available.volume_db = GROUPS[id][2]
	available.play()
	_last_played[id] = now
	_last_variant[id] = index
	return true

func set_enabled(value: bool) -> void:
	enabled = value
	if not enabled: stop_all()
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("audio", "effects_enabled", enabled)
	if config.save(settings_path) != OK:
		push_warning("Could not save sound effects preference.")

func set_backgrounded(value: bool) -> void:
	backgrounded = value
	# Finished interactions must not replay when the app returns to the foreground.
	if backgrounded: stop_all()

func stop_all() -> void:
	for player in players: player.stop()
