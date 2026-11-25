extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func _initialize() -> void:
 var path := '/tmp/yuf-record-%s/pet.json' % Time.get_ticks_usec()
 DirAccess.make_dir_recursive_absolute(path.get_base_dir())
 var g := SkillPlaySystem.new()
 g.start('tag', 4)
 check(not SkillRecords.write(path, g), 'unfinished round cannot save record')
 g.phase = 'result'
 g.settled = true
 g.stars = 3
 g.score = 3
 g.result_time = 12.5
 check(SkillRecords.write(path, g), 'record written')
 var best := SkillRecords.read(path, 'tag')
 check(best.stars == 3 and best.score == 3 and best.seconds == 12.5, 'record survives independent read')
 g.stars = 1
 g.score = 1
 g.result_time = 0
 SkillRecords.write(path, g)
 check(SkillRecords.read(path, 'tag') == best, 'worse round cannot erase best')
 g.start('frisbee', 4)
 g.wind = -1
 var left := g.disk_position_at(0.6)
 var early := g.catch_progress()
 g.wind = 1
 check(g.disk_position_at(0.6).x > left.x and g.catch_progress() > early, 'wind changes trajectory and required timing')
 g.press(Vector2(0.2, 0.6))
 g.release(Vector2(0.7, 0.4))
 g.advance(g.flight_duration() * g.catch_progress() - 0.3)
 g.cue()
 check(not g.caught, 'jump does not instantly attach disk')
 g.advance(0.31)
 check(g.caught and g.disk_attached(), 'successful jump attaches disk at contact')
 g.advance(g.flight_duration())
 check(g.phase == 'land' or g.phase == 'aim', 'round progresses after contact')
 g.start('tag', 4)
 g.feint_next = true
 g.advance(1.81)
 check(g.phase == 'feint', 'feint has distinct readable phase')
 g.press(Vector2(g.tag_x, 0.6))
 g.release(Vector2(g.tag_x, 0.6))
 check(g.score == 0 and not g.feint_next, 'feint touch cannot score or chain another feint')
 g.advance(1.81)
 check(g.phase == 'bow', 'genuine opportunity follows feint')
 var file := FileAccess.open(path + '.games.cfg', FileAccess.WRITE)
 file.store_string('[broken')
 file.close()
 g.phase = 'result'
 g.settled = true
 check(not SkillRecords.write(path, g), 'unreadable records are not overwritten')
 print('SKILL RECORDS: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)
