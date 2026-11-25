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
func frames() -> void:
 for i in 4: await process_frame
 app.app_foreground = true
 app._refresh()
 for i in 4: await process_frame
func touch(point: Vector2, down: bool, id := 0, cancel := false) -> void:
 var e := InputEventScreenTouch.new()
 e.position = app.play_view._bubble_origin() + point * BubblePlay.WORLD * app.play_view._bubble_scale()
 e.index = id
 e.pressed = down
 e.canceled = cancel
 app.play_view._on_input(e)
func run() -> void:
 for width in [320, 390]:
  root.size = Vector2i(width, 640 if width == 320 else 844)
  root.content_scale_size = root.size
  app = load('res://scenes/Main.tscn').instantiate()
  app.save_path_override = '/tmp/yuf-soap-ui-%s/pet.json' % Time.get_ticks_usec()
  app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
  root.add_child(app)
  app.session.set_process(false)
  app.session.pet.resting = false
  app.session.pet.needs.energy = 95
  app.session._brain_left = INF
  app.session.in_yard = true
  await frames()
  app._show_play_menu()
  await frames()
  check(app.safe_rect.encloses(Rect2(Vector2(app.play_menu.position), Vector2(app.play_menu.size))), 'eight-game menu fits')
  app._choose_play('bubbles')
  await frames()
  check(app.play_dialog.visible and app.session.play.phase == 'ready', 'instructions open')
  check(app.play_cue.size.y >= 44 and app.play_dialog.get_ok_button().size.y >= 44, 'start and exit touch targets')
  app.play_cue.pressed.emit()
  await frames()
  var p := Vector2(0.55, 0.6)
  touch(p, true)
  app.session.play.advance(0.8)
  touch(Vector2(0.1, 0.4), true, 1)
  check(app.session.play.bubbles.holding and app.session.play.bubbles.hold_point.distance_to(p * BubblePlay.WORLD) < 0.1, 'second finger cannot steal bubble')
  await frames()
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png('/tmp/yuf-soap-hold-%d.png' % width)
  touch(p, false)
  check(app.session.play.bubbles.launched == 1, 'release creates bubble')
  app.session.play.advance(0.12)
  await frames()
  await RenderingServer.frame_post_draw
  var view := app.play_view
  var mouth := view.puppy.position + view.puppy.mouth_point() * view.puppy.scale
  var target := view._bubble_origin() + app.session.play.bubbles.mouth() * view._bubble_scale()
  check(mouth.distance_to(target) < 0.01, 'sprite mouth matches physics contact')
  app.session.play.advance(1)
  await frames()
  check(app.session.play.score == 1, 'visible game catches bubble')
  touch(p, true)
  app.session.play.advance(0.7)
  touch(p, false, 0, true)
  check(app.session.play.bubbles.launched == 1, 'cancel does not launch')
  app.session.play.advance(31)
  app.session._settle_touch_game()
  await frames()
  check(app.play_again.visible and app.session.play.settled, 'result offers replay')
  check(app.safe_rect.encloses(Rect2(Vector2(app.play_dialog.position), Vector2(app.play_dialog.size))), 'result fits screen')
  app.play_again.pressed.emit()
  app.session.play_cue()
  touch(p, true)
  app.session.suspend_session()
  await frames()
  check(not app.play_dialog.visible and app.session.play.bubbles.items.is_empty() and not app.session.play.bubbles.holding, 'background cleans scene')
  app.music.stop()
  app.effects.stop_all()
  app.queue_free()
  for i in 4: await process_frame
 print('SOAP UI: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)
