class_name LevelRoom
extends Control
## Game shell that drives YuFriend from a LevelProject on disk. Boots a
## GameSession (loads the real save), renders the world via LevelPreview,
## and forwards script interactions to session.act(). Yard-specific
## features (bath, invite, visitor, cuddle, hide, fetch, timed course, drink)
## have NOT been ported yet — they stay in scripts/ui/main.gd (Main.tscn).
## When a project script fires here that session.act() cannot handle, we log
## it to room_state so follow-up work can wire the matching system.

signal unhandled_script(script_id: String, element_id: String)

@export var project_path: String = "res://level-editor/projects/starter.json"
@export var save_path: String = "user://pet.json"

var session := GameSession.new()
var preview := LevelPreview.new()
var hud := VBoxContainer.new()
var name_label := Label.new()
var needs_label := Label.new()
var status_label := Label.new()
var unhandled: PackedStringArray = []

const _CARE := {
	"feed": "feed", "pet": "pet", "clean": "clean", "rest": "rest", "ball": "play",
	"greet": "pet"
}

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(session)
	session.start(save_path)
	add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview.bind_pet(session.pet)
	var result := LevelProject.read_project(project_path)
	if not result.ok:
		_fatal("Projekt poziomów nie ładuje się: " + ", ".join(result.errors))
		return
	if not preview.open_project(result.project):
		_fatal("Nie udało się załadować grafik projektu.")
		return
	preview.interaction_requested.connect(_on_interaction)
	session.changed.connect(_refresh)
	session.feedback.connect(_say_feedback)
	_build_hud()
	_refresh()

func _build_hud() -> void:
	hud.position = Vector2(20, 14)
	hud.add_theme_constant_override("separation", 4)
	add_child(hud)
	for label in [name_label, needs_label, status_label]:
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("edf6d8"))
		label.add_theme_constant_override("outline_size", 2)
		label.add_theme_color_override("font_outline_color", Color("18251e"))
		hud.add_child(label)

func _refresh() -> void:
	if session.pet == null: return
	var p := session.pet
	name_label.text = p.pet_name if p.pet_name != "" else "Pies"
	var n: Dictionary = p.needs
	needs_label.text = "Sytość %d%%  ·  Energia %d%%  ·  Higiena %d%%  ·  Kontakt %d%%  ·  Zabawa %d%%" % [
		n.fullness, n.energy, n.hygiene, n.contact, n.play
	]
	status_label.text = session.last_message

func _on_interaction(element_id: String, script_id: String, props: Dictionary) -> void:
	# portal/message/thought/bark/greet/play_clip/walk_to are visual — LevelPreview
	# handles them in its own runtime. Care-type scripts become real session actions.
	var action: String = _CARE.get(script_id, "")
	if action.is_empty():
		if script_id not in ["none", "portal", "message", "thought", "walk_to", "play_clip", "bark"]:
			unhandled.append(script_id + "@" + element_id)
			unhandled_script.emit(script_id, element_id)
		return
	# Care actions fire when the dog reaches the element — LevelPreview emits the
	# signal at tap time, not after arrival. Delay to when _complete() runs instead:
	# we simply call act() now; cooldowns in GameSession prevent double-dipping.
	session.act(action, true)

func _say_feedback(text: String) -> void:
	if text.is_empty(): return
	status_label.text = text

func _fatal(message: String) -> void:
	status_label.text = message
	push_error(message)
