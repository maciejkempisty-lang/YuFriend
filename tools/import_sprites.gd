extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or not args[0] in ["simple", "pixel"] or args.size() > 3 or (args.size() == 3 and args[2] != "--replace"):
		fail("Użycie: --script res://tools/import_sprites.gd -- simple|pixel res://ścieżka/manifest.json [--replace]")
		return
	var source := FileAccess.open(args[1], FileAccess.READ)
	if source == null:
		fail("Nie można otworzyć manifestu: " + args[1])
		return
	var json := JSON.new()
	if json.parse(source.get_as_text()) != OK or not json.data is Dictionary:
		fail("Nieprawidłowy JSON: " + json.get_error_message())
		return
	var result := SpriteImporter.build(json.data)
	if not result.ok:
		fail(result.error)
		return
	var destination := "res://data/animations/puppy_%s.res" % args[0]
	if FileAccess.file_exists(destination) and not args.has("--replace"):
		fail("Pakiet już istnieje. Aby zaktualizować wygenerowany pakiet, dodaj --replace.")
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination.get_base_dir()))
	var temporary := destination.get_basename() + "_pending.res"
	var status := ResourceSaver.save(result.pack, temporary)
	if status == OK:
		status = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(destination))
	if status != OK:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(temporary))
		fail("Nie udało się zapisać pakietu (błąd %s)." % status)
		return
	print("Gotowe: %s — %d klipów." % [destination, result.pack.frames.get_animation_names().size()])
	if not result.missing.is_empty():
		print("Grafiki zastępcze dla: " + ", ".join(result.missing))
	print("Uruchom grę ponownie. W Profilu wybierz właściwy styl.")
	quit(0)

func fail(message: String) -> void:
	printerr(message)
	quit(1)
