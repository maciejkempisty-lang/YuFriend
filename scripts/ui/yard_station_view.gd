class_name YardStationView
extends Node2D

# Presentation only: input, discovery and actions stay in RoomView/GameSession.
# Dynamic overlays, such as growing plants, remain separate nodes.
const SPRITES := {
	"gate": preload("res://level-editor/assets/yard-gate.png"),
	"garden": preload("res://level-editor/assets/yard-garden.png"),
	"dig": preload("res://level-editor/assets/yard-dig.png"),
	"fetch": preload("res://level-editor/assets/yard-fetch.png"),
	"bush_0": preload("res://level-editor/assets/yard-bush_0.png"),
	"bush_1": preload("res://level-editor/assets/yard-bush_1.png"),
	"bush_2": preload("res://level-editor/assets/yard-bush_2.png"),
	"outing": preload("res://level-editor/assets/yard-outing.png"),
	"shade": preload("res://level-editor/assets/yard-shade.png"),
	"course": preload("res://level-editor/assets/yard-course.png"),
	"puddle": preload("res://level-editor/assets/yard-puddle.png"),
	"sprinkler": preload("res://level-editor/assets/yard-sprinkler.png")
}
const GATE_OPEN = preload("res://level-editor/assets/yard-gate_open.png")
const PUDDLE_DRY = preload("res://level-editor/assets/yard-puddle_dry.png")
const GLOW_SHADER = preload("res://scripts/ui/yard_sprite_glow.gdshader")

var station_id := ""
var sprite := Sprite2D.new()
var highlight := Sprite2D.new()
var glow_material := ShaderMaterial.new()
var weather_material := ShaderMaterial.new()
var weather_key := ""
var art: RoomArtwork
var clock := 0.0

func configure(id: String) -> void:
	station_id = id
	name = id.to_pascal_case()
	position = YardSpriteLayout.SORT_ORIGINS.get(id, Vector2.ZERO)
	clock = float(abs(id.hash()) % 40) / 10.0
	if id == "garden":
		art = RoomArtwork.new()
		art.kind = "yard_garden"
		art.yard_overlay_only = true
	var bounds: Rect2i = YardSpriteLayout.CROPS[id]
	for layer in [sprite, highlight]:
		layer.texture = SPRITES[id]
		layer.centered = false
		layer.position = Vector2(bounds.position) - position
		layer.scale = Vector2.ONE * RoomLayout.PIXEL_SIZE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.show_behind_parent = true
		add_child(layer)
	weather_material.shader = preload("res://scripts/ui/yard_weather_tint.gdshader")
	sprite.material = weather_material
	if art != null: art.material = weather_material
	glow_material.shader = GLOW_SHADER
	highlight.material = glow_material

func _ready() -> void:
	if art != null:
		art.position = -position
		art.show_behind_parent = true
		add_child(art)

func set_gate_open(value: bool) -> void:
	if station_id != "gate": return
	_set_texture(GATE_OPEN if value else SPRITES.gate)

func set_puddle_wet(value: bool) -> void:
	if station_id != "puddle": return
	_set_texture(SPRITES.puddle if value else PUDDLE_DRY)

func _set_texture(value: Texture2D) -> void:
	if sprite.texture == value: return
	sprite.texture = value
	highlight.texture = value

func _process(delta: float) -> void:
	if not visible: return
	clock += delta
	var pulse := pow(maxf(0.0, sin(clock * 2.4)), 2.0)
	glow_material.set_shader_parameter("strength", 0.20 + 0.42 * pulse)

func set_weather(kind: String, night: bool) -> void:
	# Ground sprites already receive the background weather overlay.
	if YardSpriteLayout.GROUND_ONLY.has(station_id): return
	var key := kind + str(night)
	if key == weather_key: return
	weather_key = key
	var tint := Color(0, 0, 0, 0)
	if kind == "rain": tint = Color(0.23, 0.35, 0.39, 0.24)
	elif kind == "after_rain": tint = Color(0.45, 0.55, 0.55, 0.08)
	var darkness := Color(0.10, 0.16, 0.28, 0.42) if night else Color(0, 0, 0, 0)
	for mat in [weather_material, glow_material]:
		mat.set_shader_parameter("weather_tint", tint)
		mat.set_shader_parameter("night_tint", darkness)
