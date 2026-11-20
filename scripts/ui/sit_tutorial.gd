class_name SitTutorial
extends VBoxContainer
signal completed
var phase := "ready"
var elapsed := 0.0
var pack: PetAnimationSet
var picture: TextureRect
var instruction: Label
var action: Button

func _ready() -> void:
	custom_minimum_size.x = 240
	add_theme_constant_override("separation", 8)
	pack = load("res://data/animations/puppy_pixel.res")
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(240, 144)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var cutout := ShaderMaterial.new()
	cutout.shader = preload("res://scripts/pet/sprite_alpha.gdshader")
	cutout.set_shader_parameter("cutoff", 0.5)
	picture.material = cutout
	add_child(picture)
	instruction = Label.new()
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.custom_minimum_size = Vector2(240, 60)
	instruction.add_theme_font_size_override("font_size", 14)
	add_child(instruction)
	action = Button.new()
	action.custom_minimum_size.y = 52
	action.button_down.connect(press)
	add_child(action)
	_frame(0)
	instruction.text = "Patrz na pupę pieska. Klik oznacza: właśnie ten ruch jest dobry."
	action.text = "Pokaż ruch w zwolnionym tempie"
	action.add_theme_font_size_override("font_size", 12)

func _frame(index: int) -> void:
	picture.texture = pack.frames.get_frame_texture("sit_down", index)

func press() -> void:
	match phase:
		"ready":
			phase = "moving"
			elapsed = 0
			action.text = "Klik!"
			instruction.text = "Jeszcze czekaj — pupa jest w górze."
		"moving":
			instruction.text = "Jeszcze nie. Poczekaj, aż pupa dotknie podłogi."
		"contact":
			phase = "reward"
			_frame(5)
			instruction.text = "Właśnie tak! Klik wskazał siad. Teraz podaj nagrodę — bez pośpiechu."
			action.text = "Podaj pokazową nagrodę"
			picture.modulate = Color.WHITE
		"reward":
			phase = "done"
			instruction.text = "Gotowe! W treningu ruch będzie szybszy i bez zatrzymania. Kliknij w tę samą chwilę."
			action.text = "Pokaz ukończony"
			action.disabled = true
			completed.emit()

func _process(delta: float) -> void:
	if phase != "moving": return
	elapsed += delta
	var index := mini(PetAnimator.SIT_CONTACT_FRAME, int(elapsed / 0.55))
	_frame(index)
	if index == PetAnimator.SIT_CONTACT_FRAME:
		phase = "contact"
		instruction.text = "TERAZ! Pupa dotknęła podłogi. Zatrzymaliśmy pokaz — naciśnij Klik!"
		action.text = "TERAZ — klik!"
		picture.modulate = Color(0.9, 1.0, 0.85)
