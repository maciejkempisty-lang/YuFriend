class_name PetAnimator
extends Node2D

signal request_completed(request_id: int)
signal clip_started(clip: String)
signal sitting_contact(request_id: int)
const SIT_CONTACT_FRAME := 3 # First authored sit_down frame with the rump on the floor.
var _sit_contact_sent := false

# start pose, end pose, seconds, loop. These IDs match the sprite brief.
const CLIPS := {
	"dig": ["stand", "stand", 0.75, true],
	"spin": ["stand", "stand", 0.8, false], "roll": ["stand", "stand", 0.8, false],
	"shake": ["stand", "stand", 0.9, false],
	"run": ["stand", "stand", 0.45, true], "sniff": ["stand", "stand", 0.8, true],
	"ball_play": ["stand", "stand", 2.044, false], "aport": ["stand", "stand", 2.333, true],
	"idle": ["stand", "stand", 2.0, true], "walk": ["stand", "stand", 0.8, true],
	"sit_down": ["stand", "sit", 0.6, false], "sit_idle": ["sit", "sit", 1.6, true],
	"stand_up": ["sit", "stand", 0.6, false], "tail_wag_stand": ["stand", "stand", 0.8, true],
	"tail_wag_sit": ["sit", "sit", 0.8, true], "give_paw": ["sit", "sit", 1.5, false],
	"bark_stand": ["stand", "stand", 0.5, false], "head_tilt_stand": ["stand", "stand", 1.0, false],
	"petted_stand": ["stand", "stand", 1.0, false], "lie_down": ["stand", "lie", 0.8, false],
	"idle_lie": ["lie", "lie", 2.0, true], "fall_asleep": ["lie", "sleep", 1.0, false],
	"sleep": ["sleep", "sleep", 3.0, true], "wake_up": ["sleep", "lie", 0.8, false],
	"get_up": ["lie", "stand", 0.8, false], "eat_enter": ["stand", "eat", 0.6, false],
	"eat_loop": ["eat", "eat", 0.8, true], "eat_exit": ["eat", "stand", 0.6, false],
	"treat_take_stand": ["stand", "stand", 1.0, false], "play_bow": ["stand", "stand", 1.0, false]
}
const BASE := {"stand": "idle", "sit": "sit_idle", "lie": "idle_lie", "sleep": "sleep", "eat": "eat_loop"}
const TRANSITIONS := {"stand": {"sit": "sit_down", "lie": "lie_down", "eat": "eat_enter"},
	"sit": {"stand": "stand_up"}, "lie": {"stand": "get_up", "sleep": "fall_asleep"},
	"sleep": {"lie": "wake_up"}, "eat": {"stand": "eat_exit"}}
var sprite := AnimatedSprite2D.new()
var skin: PetSkin
var pose: String = "stand"
var current: String = "idle"
var pending: String = ""
var remaining: float = 0.0
var clock: float = 0.0
var facing_left: bool = false
var real_clip: bool = false
var pending_id: int = 0
var current_id: int = 0

func _ready() -> void:
	add_child(sprite)
	sprite.centered = false
	sprite.frame_changed.connect(_apply_transform)
	sprite.frame_changed.connect(_check_sitting_contact)

func set_skin(value: PetSkin) -> void:
	skin = value.duplicate()
	if skin.frames == null and not skin.animation_pack_path.is_empty() and ResourceLoader.exists(skin.animation_pack_path):
		var pack: Resource = load(skin.animation_pack_path)
		if pack is PetAnimationSet:
			skin.frames = pack.frames
			skin.frame_anchor = pack.anchor
			skin.frame_height = pack.frame_size.y
			skin.display_height = pack.display_height
			skin.clip_layouts = pack.clip_layouts
	# Partial packs can fall back to their own poses, without loading old references.
	if skin.frames != null:
		if skin.standing == null and skin.frames.has_animation("idle") and skin.frames.get_frame_count("idle") > 0:
			skin.standing = skin.frames.get_frame_texture("idle", 0)
		if skin.sitting == null and skin.frames.has_animation("sit_idle") and skin.frames.get_frame_count("sit_idle") > 0:
			skin.sitting = skin.frames.get_frame_texture("sit_idle", 0)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST if skin.pixel_art else CanvasItem.TEXTURE_FILTER_LINEAR
	if skin.alpha_cutoff > 0:
		var material := ShaderMaterial.new()
		material.shader = preload("res://scripts/pet/sprite_alpha.gdshader")
		material.set_shader_parameter("cutoff", skin.alpha_cutoff)
		sprite.material = material
	else:
		sprite.material = null
	_start(current, current_id)

func request_clip(name: String, request_id: int = 0) -> void:
	if not CLIPS.has(name): name = "idle"
	pending = name
	pending_id = request_id
	if remaining <= 0:
		_route()

func _route() -> void:
	if pending.is_empty(): return
	var wanted: String = CLIPS[pending][0]
	if wanted != pose:
		# The pose graph is tiny; route through standing or lying as needed.
		var next_pose := wanted
		if not TRANSITIONS[pose].has(wanted):
			next_pose = "lie" if pose == "sleep" or (pose == "stand" and wanted == "sleep") else "stand"
		_start(TRANSITIONS[pose][next_pose])
	else:
		var next := pending
		var next_id := pending_id
		pending = ""
		pending_id = 0
		_start(next, next_id)

func _start(name: String, request_id: int = 0) -> void:
	if skin == null: return
	current = name
	current_id = request_id
	_sit_contact_sent = false
	var spec: Array = CLIPS[name]
	remaining = 0.0 if spec[3] else float(spec[2])
	real_clip = skin.frames != null and skin.frames.has_animation(name) and skin.frames.get_frame_count(name) > 0
	if real_clip:
		sprite.sprite_frames = skin.frames
		sprite.play(name)
		sprite.set_frame_and_progress(0, 0)
		# Authored frame timing controls one-shot transitions when supplied.
		if not bool(spec[3]):
			var duration := 0.0
			for index in skin.frames.get_frame_count(name):
				duration += skin.frames.get_frame_duration(name, index) / maxf(0.01, skin.frames.get_animation_speed(name))
			remaining = duration
	else:
		var frames := SpriteFrames.new()
		var texture: Texture2D = skin.sitting if str(spec[1]) in ["sit", "lie", "sleep"] else skin.standing
		frames.add_frame("default", texture)
		sprite.sprite_frames = frames
		sprite.play("default")
	_apply_transform()
	clip_started.emit(current)
	if remaining <= 0 and current_id > 0:
		var finished := current_id
		current_id = 0
		request_completed.emit(finished)

func _check_sitting_contact() -> void:
	if current == "sit_down" and current_id > 0 and sprite.animation == "sit_down" and sprite.frame >= SIT_CONTACT_FRAME and not _sit_contact_sent:
		_sit_contact_sent = true
		sitting_contact.emit(current_id)

func _process(delta: float) -> void:
	clock += delta
	if remaining > 0:
		remaining -= delta
		if remaining <= 0:
			var finished := current_id
			pose = CLIPS[current][1]
			if pending.is_empty(): _start(BASE[pose])
			else: _route()
			if finished > 0: request_completed.emit(finished)
	_apply_transform()

func _apply_transform() -> void:
	if skin == null or sprite.sprite_frames == null: return
	if not sprite.sprite_frames.has_animation(sprite.animation): return
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null: return
	var ratio: float = skin.display_height / (skin.frame_height if real_clip else float(texture.get_height()))
	var anchor := skin.frame_anchor if real_clip else Vector2(texture.get_width() * 0.5, texture.get_height() * 0.85)
	if real_clip and skin.clip_layouts.has(current):
		var layout: Dictionary = skin.clip_layouts[current]
		ratio *= float(layout.get("scale", 1.0))
		var anchors: Array = layout.get("anchors", [])
		if sprite.frame < anchors.size(): anchor = anchors[sprite.frame]
	var breath := 1.0 if real_clip else 1.0 + sin(clock * 2.2) * 0.009
	sprite.scale = Vector2(ratio, ratio * breath)
	sprite.flip_h = facing_left
	if facing_left: anchor.x = texture.get_width() - anchor.x
	sprite.position = -anchor * sprite.scale
	if not real_clip and current == "walk": sprite.position.y -= absf(sin(clock * 10.0)) * 3.0
	if not real_clip and current.begins_with("tail_wag"):
		sprite.rotation = sin(clock * 9.0) * 0.015
	else:
		sprite.rotation = 0
	sprite.modulate = Color(0.8, 0.85, 0.9) if current == "sleep" and not real_clip else Color.WHITE

# Prop attachment follows the actual current frame, including mirrored poses.
var _prop_bounds: Dictionary = {}
func mouth_point() -> Vector2:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation): return Vector2.ZERO
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture == null: return Vector2.ZERO
	if not _prop_bounds.has(texture): _prop_bounds[texture] = Rect2(texture.get_image().get_used_rect())
	var bounds: Rect2 = _prop_bounds[texture]
	var point := bounds.position + bounds.size * Vector2(0.88, 0.48)
	if facing_left: point.x = texture.get_width() - point.x
	return sprite.position + point * sprite.scale

# Pixel coordinates in the authored frames, just below the nose. The ball is
# drawn behind the muzzle, so the lips cover its upper/inner edge.
const BALL_GRIPS := {
	"idle": [Vector2(420, 244), Vector2(420, 238), Vector2(420, 238), Vector2(420, 243), Vector2(420, 244), Vector2(420, 244)],
	"tail_wag_stand": [Vector2(429, 239), Vector2(429, 239), Vector2(429, 239), Vector2(429, 239), Vector2(429, 239), Vector2(429, 239)],
	"treat_take_stand": [Vector2(321, 243), Vector2(323, 258), Vector2(334, 286), Vector2(333, 285), Vector2(323, 267), Vector2(324, 250), Vector2(324, 237), Vector2(324, 237)]
}
func ball_grip_point() -> Vector2:
	if not real_clip or not BALL_GRIPS.has(sprite.animation): return mouth_point()
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	var points: Array = BALL_GRIPS[sprite.animation]
	var point: Vector2 = points[mini(sprite.frame, points.size() - 1)]
	if facing_left: point.x = texture.get_width() - point.x
	return sprite.transform * point
