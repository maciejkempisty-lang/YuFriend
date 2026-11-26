class_name SceneLayers
extends Node2D
## Shared world structure for home and yard. HUD stays outside this world.
## All layers use the same origin: changing a layer never moves an asset.

var background := Node2D.new()
var middle_ground := Node2D.new()
var foreground := Node2D.new()

func _init() -> void:
	name = "World"
	background.name = "Background"
	middle_ground.name = "MiddleGround"
	foreground.name = "Foreground"
	background.z_index = -100
	foreground.z_index = 100
	middle_ground.y_sort_enabled = true
	add_child(background)
	add_child(middle_ground)
	add_child(foreground)
