class_name PetSkin
extends Resource

## Drop a completed SpriteFrames resource here. Missing clips use the references.
@export var frames: SpriteFrames
@export_file("*.res") var animation_pack_path: String = ""
@export var frame_anchor := Vector2(256, 430)
@export var frame_height: float = 512.0
@export var display_height: float = 245.0
@export var pixel_art: bool = false
@export var standing: Texture2D
@export var sitting: Texture2D
