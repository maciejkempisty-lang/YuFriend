extends SceneTree
var app: GameUI
var passed := 0
var failed := 0
func _initialize() -> void:
 create_timer(90).timeout.connect(func(): quit(1))
 call_deferred('run')
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func settle() -> void:
 for i in 3: await process_frame
 app.app_foreground = true
 app._refresh()
 app._fit_room()
 for i in 3: await process_frame
func touch(p: Vector2, end := Vector2.INF) -> void:
 var down := InputEventScreenTouch.new()
 down.index = 0
 down.position = p
 down.pressed = true
 app.play_view._on_input(down)
 await process_frame
 var up := InputEventScreenTouch.new()
 up.index = 0
 up.position = p if end == Vector2.INF else end
 up.pressed = false
 app.play_view._on_input(up)
 await settle()
func run() -> void:
 for width in [320, 390]:
  root.size = Vector2i(width, 640 if width == 320 else 844)
  root.content_scale_size = root.size
  app = load('res://scenes/Main.tscn').instantiate()
  app.save_path_override = '/tmp/yuf-skill-ui-%s/pet.json' % Time.get_ticks_usec()
  app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
  root.add_child(app)
  app.session.set_process(false)
  app.session._brain_left = INF
  app.session.visitors.wait_left = INF
  app.session.pet.needs.energy = 95
  app.session.pet.resting = false
  app._toggle_yard(false)
  await settle()
  app._show_play_menu()
  await settle()
  check(app.play_menu.visible and app.safe_rect.encloses(Rect2(Vector2(app.play_menu.position), Vector2(app.play_menu.size))), 'six-game menu fits screen')
  app.play_menu.hide()
  for kind in ['tag', 'cups2', 'frisbee']:
   app.session.cancel_touch_game()
   app.session.activity = 'idle'
   app.session.activity_left = 0
   app.session.pet.resting = false
   app.session.pet.needs.energy = 95
   app.session.in_yard = true
   check(app.session.start_touch_game(kind), 'start ' + kind)
   await settle()
   check(app.play_dialog.visible and app.play_view.is_visible_in_tree(), 'game view opens ' + kind)
   check(app.safe_rect.encloses(Rect2(Vector2(app.play_dialog.position), Vector2(app.play_dialog.size))), 'game dialog fits safe area ' + kind)
   check(app.play_dialog.get_ok_button().size.y >= 44, 'close target large enough: actual %s minimum %s' % [app.play_dialog.get_ok_button().size, app.play_dialog.get_ok_button().custom_minimum_size])
   if kind == 'tag':
    app.session.play.advance(1.81)
    await settle()
    await touch(Vector2(app.session.play.tag_x, 0.6) * app.play_view.size)
    check(app.session.play.score == 1, 'touch catches puppy in bow')
   elif kind == 'cups2':
    app.session.play.advance(10)
    await settle()
    check(app.play_cue.visible and app.play_cue.text == 'Pomóż, Gloria', 'hint available')
    await touch((app.session.play.cup_point(app.session.play.treat_cup) - Vector2(0, 0.1)) * app.play_view.size)
    check(app.session.play.stars == 3 and app.play_again.visible, 'cup touch scores and retry appears')
   else:
    await touch(Vector2(0.2, 0.6) * app.play_view.size, Vector2(0.7, 0.4) * app.play_view.size)
    check(app.session.play.phase == 'flight' and app.play_cue.visible and app.play_cue.text == 'Skacz!', 'drag launches disk and jump appears')
   await RenderingServer.frame_post_draw
   root.get_texture().get_image().save_png('/tmp/yuf-skill-%s-%d.png' % [kind, width])
   app.play_dialog.hide()
   await settle()
   check(app.session.play.kind.is_empty(), 'close cancels ' + kind)
  app.music.stop()
  app.effects.stop_all()
  app.queue_free()
  await process_frame
 print('SKILL UI: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)
