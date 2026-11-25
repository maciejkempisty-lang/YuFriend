class_name HapticFeedback
extends RefCounted

# Feedback follows accepted game events, never animation frames or footsteps.
var enabled := false
var supported := OS.has_feature("ios") or OS.has_feature("android")
var backgrounded := false
var settings_path := ""
var clock: Callable = func(): return Time.get_ticks_msec()
var output: Callable = func(duration: int): Input.vibrate_handheld(duration)
var last_pulse := -1000

func start(path: String) -> void:
	settings_path = path
	var config := ConfigFile.new()
	if config.load(path) == OK:
		enabled = config.get_value("feedback", "vibrations", false) == true

func set_enabled(value: bool) -> void:
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("feedback", "vibrations", value)
	if config.save(settings_path) != OK:
		push_warning("Could not save vibration preference.")
		return
	enabled = value

func play_event(kind: String) -> void:
	if not enabled or not supported or backgrounded: return
	if kind not in ["pet", "success"]: return
	var now := int(clock.call())
	if now - last_pulse < 250: return
	last_pulse = now
	output.call(20 if kind == "pet" else 40)
