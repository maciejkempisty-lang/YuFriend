class_name PetAnimationSet
extends Resource

## Generated from a sprite manifest. Gameplay never writes this resource.
@export var frames: SpriteFrames
@export var frame_size := Vector2i(512, 512)
@export var anchor := Vector2(256, 430)
@export var display_height: float = 245.0
## Optional source-pixel anchors and uniform scale for independently drawn clips.
@export var clip_layouts: Dictionary = {}
