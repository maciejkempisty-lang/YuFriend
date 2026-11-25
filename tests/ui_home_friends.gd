extends SceneTree
var app: GameUI
var passed := 0
var failed := 0
func _initialize() -> void:
 create_timer(60).timeout.connect(func(): quit(1))
 call_deferred('run')
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func settle() -> void:
 for i in 4: await process_frame
 app.app_foreground = true
 app._refresh()
 app._fit_room()
 for i in 4: await process_frame
func run() -> void:
 for width in [320, 390]:
  root.size = Vector2i(width, 640 if width == 320 else 844)
  root.content_scale_size = root.size
  app = load('res://scenes/Main.tscn').instantiate()
  app.save_path_override = '/tmp/yuf-home-ui-%s/pet.json' % Time.get_ticks_usec()
  app.session.local_clock = func(): return 100 * 86400.0 + 12 * 3600
  root.add_child(app)
  app.session.set_process(false)
  app.room.set_process(false)
  app.session.pet.resting = false
  app.session.pet.needs.energy = 95
  app.session._brain_left = INF
  await settle()
  app.room.pet_world = Vector2(800, 319)
  app.room.look_at_world(HomeDrink.BOWL)
  await settle()
  var point := app.room.world_to_screen(HomeDrink.BOWL)
  check(app.room.action_at(point) == 'drink', 'water bowl has separate touch target')
  check(app.room.action_at(app.room.world_to_screen(Vector2(485, 303))) == 'feed', 'food bowl keeps feeding target')
  app.room._interact(point)
  check(app.session.home_drink.active(), 'touch starts drinking')
  app.room.pet_world = HomeDrink.STAND
  app.session.destination_reached()
  app.session.home_drink.advance(app.session, 1)
  app.room._sync_layers()
  await create_timer(1.2).timeout
  await settle()
  app.room._sync_layers()
  check(app.room.animator.facing_left and app.session.home_drink.phase == 'drink', 'dog faces water while drinking')
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png('/tmp/yuf-home-drink-%d.png' % width)
  app.session.home_drink.finish(app.session, '')
  app._toggle_yard(false)
  app.session.activity = 'idle'
  app.session.activity_left = 0
  app.session.pet.resting = false
  app.session.visitors.begin_visit()
  check(app.session.visitors.start(app.session, 'cat'), 'cat appears')
  await settle()
  app.room.look_at_world(YardVisitors.FENCE)
  await settle()
  var guest_touch := app.room.visitor_touch_rect().get_center()
  check(app.room.action_at(guest_touch) == 'visitor', 'NPC can be touched')
  app.room._interact(guest_touch)
  await settle()
  check(is_instance_valid(app.visitor_dialog) and app.visitor_dialog.visible, 'NPC touch opens interactions')
  check(app.safe_rect.encloses(Rect2(Vector2(app.visitor_dialog.position), Vector2(app.visitor_dialog.size))), 'interaction dialog fits narrow screen')
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png('/tmp/yuf-friends-menu-%d.png' % width)
  check(app.visitor_interact_button.is_visible_in_tree() and app.visitor_interact_button.size.y >= 44, 'toolbar also exposes accessible interaction')
  var greeting: Button
  for child in app.visitor_dialog.get_children():
   if child is VBoxContainer:
    for control in child.get_children():
     if control is Button and control.text == 'Przywitaj się spokojnie': greeting = control
  check(is_instance_valid(greeting) and greeting.size.y >= 44, 'greeting has a touch target')
  if is_instance_valid(greeting): greeting.pressed.emit()
  check(app.session.visitors.phase == 'greet' and not app.visitor_dialog.visible, 'menu button starts greeting')
  app.session.visitors.advance(app.session, 3.1)
  await settle()
  check(VisitorMemory.level(app.session.pet, 'cat') == 1 and not app.visitor_dialog.visible, 'greeting advances relationship and closes menu')
  app.music.stop()
  app.effects.stop_all()
  app.queue_free()
  await process_frame
 print('HOME FRIENDS UI: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)
