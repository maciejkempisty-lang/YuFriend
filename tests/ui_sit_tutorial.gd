extends SceneTree
var failed := 0
var app: GameUI
func check(ok: bool, label: String) -> void:
 if not ok:
  failed += 1
  push_error(label)
func _initialize() -> void:
 create_timer(60).timeout.connect(func(): quit(1))
 call_deferred("run")
func shot(label: String) -> void:
 await process_frame
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png("/tmp/yuf33-" + label + ".png")
func open_demo() -> SitTutorial:
 for attempt in 5:
  app._train(false)
  await shot("demo")
  if is_instance_valid(app.gesture_dialog) and app.gesture_dialog.visible:
   return app.gesture_dialog.find_children("*", "VBoxContainer", true, false).filter(func(node): return node is SitTutorial)[0]
 return null
func run() -> void:
 root.size = Vector2i(320, 640)
 root.content_scale_size = root.size
 app = load("res://scenes/Main.tscn").instantiate()
 app.save_path_override = preload("res://tests/helper_paths.gd").data_root() + "/sit-demo-%s/pet.json" % Time.get_ticks_usec()
 app.session.local_clock = func(): return 20000 * 86400.0 + 12 * 3600
 root.add_child(app)
 app.session.set_process(false)
 app.session.pet.skills.sit.mastery = 100
 app.session.pet.pet_name = "Gloria"
 app._select_tab("training")
 app._choose_trick("sit")
 var before := app.session.pet.to_dict()
 before.erase("last_seen_at")
 check(not app.sit_tutorial_seen and app.guided_button.text == "Zacznij od pokazu", "first attempt is clearly a demonstration")
 check(app._sit_explanation().contains("Gloria zna Siad (100%)"), "explains why mastered Gloria skips the gesture")
 root.grab_focus()
 await create_timer(0.5).timeout
 var demo := await open_demo()
 check(demo != null, "first press opens demo")
 if demo == null: quit(1); return
 app.gesture_dialog.hide()
 await process_frame
 check(not app.sit_tutorial_seen, "closing an incomplete demo does not mark it completed")
 demo = await open_demo()
 if demo == null: quit(1); return
 check(app.session.training.phase == "idle", "demo never starts a paid training trial")
 demo.press()
 demo.press()
 check(demo.phase == "moving" and demo.instruction.text.begins_with("Jeszcze nie"), "early click explains waiting without failure")
 demo._process(2)
 check(demo.phase == "contact" and demo.action.text == "TERAZ — klik!", "contact frame freezes with clear click cue")
 demo._process(60)
 check(demo.phase == "contact", "demonstration waits without a deadline")
 await shot("contact-320")
 check(app.gesture_dialog.position.y >= 0 and app.gesture_dialog.position.y + app.gesture_dialog.size.y <= root.size.y, "whole tutorial fits small phone")
 demo.press()
 check(demo.phase == "reward" and not app.sit_tutorial_seen, "marker leads to explicit reward step")
 demo.press()
 check(demo.phase == "done" and app.sit_tutorial_seen, "reward completes tutorial")
 await shot("done-320")
 var after := app.session.pet.to_dict()
 after.erase("last_seen_at")
 check(before == after, "demo preserves every gameplay field including fatigue and all skills")
 var config := ConfigFile.new()
 check(config.load(app.ui_settings_path) == OK and config.get_value("tutorial", "sit_marker_demo", false), "completion is persisted in UI preferences")
 app.sit_tutorial_seen = false
 app._load_ui_preferences()
 check(app.sit_tutorial_seen, "reloading remembers completed demo")
 app.gesture_dialog.hide()
 await process_frame
 app._refresh()
 await shot("training-320")
 check(app.guided_button.text == "Ćwicz Siad", "real training is a separate deliberate action")
 check(app.sit_help_button.get_global_rect().end.x <= 320, "help remains accessible on small phone")
 app._show_sit_tutorial()
 check(is_instance_valid(app.gesture_dialog), "completed demo can be replayed")
 app.gesture_dialog.hide()
 await process_frame
 app.session.pet.skills.sit.mastery = 10
 check(app._sit_explanation().contains("smakołyk"), "new learner receives lure explanation")
 app.session.pet.skills.sit.mastery = 50
 check(app._sit_explanation().contains("krótki"), "middle mastery receives short gesture explanation")
 app.queue_free()
 await process_frame
 print("SIT TUTORIAL UI FAILURES: ", failed)
 quit(1 if failed else 0)
