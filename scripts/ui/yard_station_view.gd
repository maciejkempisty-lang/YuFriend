class_name YardStationView
extends Node2D

# Presentation only: input, discovery and actions stay in RoomView/GameSession.
# Dynamic overlays, such as growing plants, remain separate nodes.
const SPRITES := {
	"gate": preload("res://assets/art/yard/sprites/gate.png"),
	"garden": preload("res://assets/art/yard/sprites/garden.png"),
	"dig": preload("res://assets/art/yard/sprites/dig.png"),
	"fetch": preload("res://assets/art/yard/sprites/fetch.png"),
	"bush_0": preload("res://assets/art/yard/sprites/bush_0.png"),
	"bush_1": preload("res://assets/art/yard/sprites/bush_1.png"),
	"bush_2": preload("res://assets/art/yard/sprites/bush_2.png"),
	"outing": preload("res://assets/art/yard/sprites/outing.png"),
	"shade": preload("res://assets/art/yard/sprites/shade.png"),
	"course": preload("res://assets/art/yard/sprites/course.png"),
	"puddle": preload("res://assets/art/yard/sprites/puddle.png"),
	"sprinkler": preload("res://assets/art/yard/sprites/sprinkler.png")
}
const GATE_OPEN = preload("res://assets/art/yard/sprites/gate_open.png")
const PUDDLE_DRY = preload("res://assets/art/yard/sprites/puddle_dry.png")
const GLOW_SHADER = preload("res://scripts/ui/yard_sprite_glow.gdshader")

var station_id := ""
var sprite := Sprite2D.new()
var highlight := Sprite2D.new()
var glow_material := ShaderMaterial.new()
var art: RoomArtwork
var clock := 0.0

func configure(id: String) -> void:
	station_id = id
	clock = float(abs(id.hash()) % 40) / 10.0
	if id == "garden":
		art = RoomArtwork.new()
		art.kind = "yard_garden"
		art.yard_overlay_only = true
	var bounds: Rect2i = YardSpriteLayout.CROPS[id]
	for layer in [sprite, highlight]:
		layer.texture = SPRITES[id]
		layer.centered = false
		layer.position = bounds.position
		layer.scale = Vector2.ONE * RoomLayout.PIXEL_SIZE
		layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer.show_behind_parent = true
		add_child(layer)
	glow_material.shader = GLOW_SHADER
	highlight.material = glow_material

func _ready() -> void:
	if art != null:
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
