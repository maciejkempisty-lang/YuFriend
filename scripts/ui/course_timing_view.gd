class_name CourseTimingView
extends Control
var model: TimedCourse
func _ready() -> void:
 custom_minimum_size.y = 32
 mouse_filter = Control.MOUSE_FILTER_IGNORE
func _process(_delta: float) -> void:
 queue_redraw()
func _draw() -> void:
 if model == null or model.phase != 'cue': return
 var width := size.x - 24
 var duration := TimedCourse.CUE_AT + TimedCourse.WINDOW
 var x0 := 12 + width * (TimedCourse.CUE_AT - TimedCourse.WINDOW) / duration
 draw_line(Vector2(12, 16), Vector2(size.x - 12, 16), Color('9bb399'), 4)
 draw_rect(Rect2(x0, 3, size.x - 12 - x0, 26), Color('f3d798'))
 var x := 12 + width * clampf(model.phase_time / duration, 0, 1)
 draw_circle(Vector2(x, 16), 8, Color('315d49'))
