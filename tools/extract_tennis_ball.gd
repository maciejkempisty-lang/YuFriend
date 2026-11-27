extends SceneTree

func _initialize() -> void:
	var source := Image.new()
	var path := "res://level-editor/assets/sprites-Golden-spritesheet-playing_with_the_ball-frames-0001.png"
	if source.load(path) != OK:
		quit(1)
		return
	# First frame contains an unobscured tennis ball at the puppy's nose.
	var ball := source.get_region(Rect2i(180, 153, 54, 54))
	var destination := "res://level-editor/assets/ball.png"
	var status := ball.save_png(destination)
	quit(0 if status == OK else 1)
