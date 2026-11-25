extends SceneTree
var passed := 0
var failed := 0
var day := 100
func check(ok: bool, label: String) -> void:
 if ok: passed += 1
 else:
  failed += 1
  push_error(label)
func make_game() -> GameSession:
 var s := GameSession.new()
 s.pet = PetState.create(42)
 s.storage = SaveSystem.new('/tmp/yuf-home-friends-%s/pet.json' % Time.get_ticks_usec())
 s.storage.save_pet(s.pet)
 s.active = true
 s.local_clock = func(): return day * 86400.0 + 12 * 3600
 return s
func _initialize() -> void:
 var s := make_game()
 var before := s.pet.to_dict()
 check(s.home_drink.start(s) and s.busy(), 'home drinking starts and blocks conflicting actions')
 s.home_drink.advance(s, 5)
 check(s.home_drink.phase == 'walk' and not s.pet.milestones.has('home_drink'), 'no completion before arrival')
 s.destination_reached()
 check(s.home_drink.phase == 'drink', 'arrival starts actual drinking')
 s.home_drink.advance(s, 4.3)
 check(not s.home_drink.active() and s.pet.milestones.has('home_drink'), 'drinking finishes and records memory')
 check(s.pet.needs == before.needs and s.pet.skills == before.skills and s.pet.bond == before.bond, 'drinking does not invent needs or farm progression')
 check(s.storage.load_pet().pet.milestones.has('home_drink'), 'memory survives reload')
 var count := s.pet.journal.size()
 s.home_drink.start(s)
 s.destination_reached()
 s.home_drink.advance(s, 4.3)
 check(s.pet.journal.size() == count, 'repeat does not duplicate memory')
 s.home_drink.start(s)
 s.home_drink.start(s)
 check(not s.home_drink.active(), 'second tap interrupts')
 s.pet.resting = true
 check(not s.home_drink.start(s), 'sleep respected')
 s.pet.resting = false
 s.home_drink.start(s)
 s.suspend_session()
 check(not s.home_drink.active(), 'background cancels drinking')
 s.free()
 s = make_game()
 s.in_yard = true
 check(not s.home_drink.start(s), 'home bowl unavailable outside')
 for d in [100, 101, 102]:
  day = d
  s.visitors.begin_visit()
  check(s.visitors.start(s, 'cat'), 'visitor appears')
  if d == 100: check(not s.visitors.respond(s, 'together'), 'shared time requires greeting first')
  check(s.visitors.respond(s, 'greet' if d == 100 else 'together'), 'interaction accepted')
  s.visitors.advance(s, 7)
  check(VisitorMemory.level(s.pet, 'cat') == d - 99, 'distinct day advances friendship')
 check(s.pet.milestones.has('visitor_cat_friend') and VisitorMemory.describe(s.pet, 'cat').contains('Przyjaciel'), 'three days form friendship')
 var restored: PetState = s.storage.load_pet().pet
 check(restored.milestones.has('visitor_cat_friend'), 'friendship survives save reload')
 var journal := s.pet.journal.size()
 s.visitors.begin_visit()
 s.visitors.start(s, 'cat')
 s.visitors.respond(s, 'greet')
 s.visitors.advance(s, 4)
 check(s.pet.journal.size() == journal, 'same-day interaction cannot farm memories')
 s.visitors.begin_visit()
 s.visitors.start(s, 'bird')
 s.visitors.respond(s, 'greet')
 s.suspend_session()
 check(VisitorMemory.level(s.pet, 'bird') == 0, 'interrupted greeting earns no friendship')
 s.free()
 print('HOME FRIENDS: %d passed, %d failed' % [passed, failed])
 quit(1 if failed else 0)
