extends SceneTree
var passed := 0
var failed := 0
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func game() -> GameSession:
 var s := GameSession.new()
 s.pet = PetState.create(42)
 s.storage = SaveSystem.new('/tmp/yuf-timed-%s/pet.json' % Time.get_ticks_usec())
 s.pet.skills.sit.mastery = 100
 s.pet.needs.energy = 95
 s.pet.needs.fullness = 95
 s.local_clock = func(): return 100 * 86400.0 + 12 * 3600
 s.in_yard = true
 s.active = true
 s.flush()
 return s
func command(s: GameSession, miss := false) -> void:
 var t := s.timed_course
 check(t.phase == 'cue', 'command offered at station')
 t.advance(s, 0.2 if miss else 1.5)
 check(t.cue(s) and not t.cue(s), 'one input per station')
 t.advance(s, 3.2 if miss else 0.36)
func route(s: GameSession, errors := 0) -> void:
 var t := s.timed_course
 t.advance(s, 3.01)
 t.advance(s, 2)
 check(t.elapsed == 0, 'approach from different garden positions does not affect record')
 s.destination_reached()
 command(s, errors > 0)
 for i in 4: s.destination_reached()
 command(s, errors > 1)
 s.destination_reached()
 s.destination_reached()
 command(s, errors > 2)
 t.advance(s, 0.7)
func _initialize() -> void:
 var s := game()
 var skills := s.pet.skills.duplicate(true)
 var energy: float = s.pet.needs.energy
 check(s.timed_course.start(s), 'timed course starts')
 check(s.pet.needs.energy == energy - 3, 'start cost once')
 check(not s.course.start(s) and not s.start_touch_game('bubbles'), 'other games blocked')
 route(s)
 check(not s.timed_course.active() and s.timed_course.stars == 3, 'clean finish three stars')
 check(s.pet.skills == skills and s.pet.needs.energy == energy - 3, 'no training progression or duplicate energy cost')
 check(s.pet.milestones.has('timed_course'), 'first finish memory')
 var record := SkillRecords.read(s.storage.path, 'agility')
 check(record.seconds > 0 and record.stars == 3, 'record persists')
 var bond := s.pet.bond
 var games: int = s.pet.social.games.ball
 s.timed_course._complete(s)
 check(s.pet.bond == bond and s.pet.social.games.ball == games, 'completion idempotent')
 for errors in [1, 2, 3]:
  check(s.timed_course.start(s), 'repeat starts')
  route(s, errors)
  check(s.timed_course.mistakes == errors and s.timed_course.stars == (2 if errors == 1 else 1), 'penalties grade completed course')
  check(s.pet.bond == bond, 'shared reward cooldown')
  check(SkillRecords.read(s.storage.path, 'agility').seconds == record.seconds, 'slower round preserves record')
 s.timed_course.start(s)
 s.timed_course.advance(s, 3.01)
 s.destination_reached()
 s.timed_course.advance(s, 1.86)
 check(s.timed_course.phase == 'penalty' and s.timed_course.mistakes == 1, 'missing input incurs one penalty')
 s.timed_course.advance(s, 1.4)
 check(s.timed_course.phase == 'penalty', 'penalty actually pauses')
 s.timed_course.advance(s, 0.11)
 check(s.timed_course.phase == 'slalom', 'penalty resumes route')
 s.suspend_session()
 check(not s.timed_course.active(), 'background cancels')
 s.suspended = false
 s.activity = 'idle'
 s.activity_left = 0
 s.timed_course.start(s)
 s.timed_course.advance(s, 64)
 check(not s.timed_course.active() and not s.timed_course.settled, 'stalled route times out without reward')
 s.pet.needs.energy = 20
 check(not s.timed_course.start(s), 'low energy blocks start')
 s.pet.needs.energy = 95
 s.pet.skills.sit.mastery = 0
 check(not s.timed_course.start(s), 'same training unlock as old course')
 s.pet.skills.sit.mastery = 100
 s.in_yard = false
 check(not s.timed_course.start(s), 'requires yard')
 check(SkillRecords.write_course(s.storage.path, 50, 1), 'agility supports times over 45 seconds')
 check(not SkillRecords.write_course(s.storage.path, NAN, 3), 'invalid record rejected')
 s.free()
 print('TIMED COURSE: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)
