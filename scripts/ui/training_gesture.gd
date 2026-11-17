class_name TrainingGesture
extends Control

signal completed
var hold_mode := false
var pointer := -2
var elapsed := 0.0
var progress := 0.0
var finished := false
var message := ""

func _ready() -> void:
	custom_minimum_size = Vector2(260, 240)
	mouse_filter = Control.MOUSE_FILTER_STOP
	reset()

func reset() -> void:
	pointer = -2
	elapsed = 0
	progress = 0
	message = "Przytrzymaj koło. Puść na zielonym." if hold_mode else "Przeciągnij smakołyk w dół po ścieżce."
	queue_redraw()

func point(ratio: float) -> Vector2:
	return Vector2(size.x / 2, 70 + ratio * 110)

func press(at: Vector2, id: int) -> void:
	if finished or pointer != -2: return
	if at.distance_to(point(0.5 if hold_mode else 0.0)) > 40: return
	pointer = id
	elapsed = 0
	progress = 0
	queue_redraw()

func move(at: Vector2, id: int) -> void:
	if pointer != id or finished: return
	if hold_mode:
		if at.distance_to(point(0.5)) > 55: reset()
	else:
		var ratio := clampf((at.y - 70) / 110, 0, 1)
		if absf(at.x - size.x / 2) > 45 or ratio < progress - 0.25:
			reset()
		else:
			progress = maxf(progress, ratio)
	queue_redraw()

func release(at: Vector2, id: int, canceled: bool = false) -> void:
	if pointer != id or finished: return
	if canceled:
		reset()
		return
	var success := elapsed >= 2 and elapsed <= 3 and at.distance_to(point(0.5)) <= 55 if hold_mode else progress >= 0.9 and at.distance_to(point(1)) <= 40
	reset()
	if success:
		finished = true
		completed.emit()
	else:
		message = "Spróbuj jeszcze raz — bez utraty postępu."
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed: press(event.position, event.index)
		else: release(event.position, event.index, event.canceled)
	elif event is InputEventScreenDrag: move(event.position, event.index)
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: press(event.position, -1)
		else: release(event.position, -1)
	elif event is InputEventMouseMotion and event.device != -1: move(event.position, -1)
	accept_event()

func _process(delta: float) -> void:
	if pointer == -2 or not hold_mode or finished: return
	elapsed += minf(delta, 0.1)
	message = "Puść teraz!" if elapsed >= 2 else "Jeszcze chwila… %.1f s" % (2 - elapsed)
	if elapsed > 3:
		reset()
		message = "Za długo. Spróbuj ponownie."
	queue_redraw()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]: reset()

func _draw() -> void:
	var green := Color("668957")
	var sand := Color("c6c7a7")
	var font := ThemeDB.fallback_font
	draw_string(font, Vector2(0, 25), message, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("294b40"))
	if hold_mode:
		draw_circle(point(0.5), 40, green if elapsed >= 2 else sand)
		draw_arc(point(0.5), 46, -PI / 2, -PI / 2 + TAU * minf(elapsed / 2, 1), 48, green, 5)
	else:
		draw_line(point(0), point(1), sand, 20)
		draw_circle(point(1), 25, green)
		draw_circle(point(progress), 22, Color("b98247"))
		draw_string(font, Vector2(0, 225), "Start u góry → nagroda na dole", HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color("294b40"))
