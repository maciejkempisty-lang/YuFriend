import Foundation

var checks = 0
func check(_ condition: Bool, _ message: String) {
    checks += 1
    if !condition { fatalError(message) }
}
var calendar = Calendar(identifier: .gregorian)
calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
func date(_ text: String) -> Date { ISO8601DateFormatter().date(from: text)! }
let now = date("2026-11-15T09:00:00+01:00")
func pet(at: Date = now, low: [PetNeed] = [.fullness, .play], resting: Bool = false) -> PetSnapshot {
    PetSnapshot(version: 1, petID: "test", name: "Gloria", savedAt: at.timeIntervalSince1970,
                needs: Dictionary(uniqueKeysWithValues: PetNeed.allCases.map { ($0.rawValue, low.contains($0) ? 20.0 : 100.0) }),
                resting: resting, sociability: 0.5, mood: "calm")
}
func plan(_ snapshot: PetSnapshot?, at: Date = now, consumed: [Date] = []) -> [PetReminder] {
    PetReminderPlan.make(snapshot: snapshot, now: at, consumed: consumed, calendar: calendar)
}
let two = plan(pet())
check(two.count == 2, "Two distinct low needs can invite twice")
check(two[0].date == now.addingTimeInterval(1800), "No immediate nag on leaving")
check(two[1].date.timeIntervalSince(two[0].date) == 4 * 3600, "Four hours between invites")
check(two[0].need == .fullness && two[1].need == .play, "Stable priority, distinct need per absence")
check(two.allSatisfy { $0.name == "Gloria" && $0.body.contains("?") }, "Dog name and inviting first-person copy")
check(plan(nil).isEmpty, "Missing save is silent")
check(plan(pet(at: now.addingTimeInterval(60))).isEmpty, "Future save is silent")
check(plan(pet(at: now.addingTimeInterval(-48 * 3600))).isEmpty, "Old save cannot extend the planning window")
check(plan(pet(low: [])).isEmpty, "Healthy dog has no fabricated urgency")
check(plan(pet(low: [.energy], resting: true)).isEmpty, "Sleeping dog never asks to wake")
check(plan(pet(low: [.energy])).first?.need == .energy, "Awake low energy invites rest")
check(plan(pet(low: [.fullness])).count == 1, "Same need is not repeated during one absence")
let crossing = PetSnapshot(version: 1, petID: "crossing", name: "Gloria", savedAt: now.timeIntervalSince1970,
    needs: ["fullness": 51, "energy": 100, "hygiene": 100, "play": 100, "contact": 100], resting: false, sociability: 0.5, mood: "calm")
check(plan(crossing).first?.date == now.addingTimeInterval(3.25 * 3600), "Strictly below thirty, checked every quarter-hour")
check(plan(pet(), consumed: [now.addingTimeInterval(-3600), now.addingTimeInterval(-5 * 3600)]).allSatisfy {
    !calendar.isDate($0.date, inSameDayAs: now)
}, "Reopening cannot reset the daily budget")
let one = plan(pet(), consumed: [now.addingTimeInterval(-3600)])
check(one.filter { calendar.isDate($0.date, inSameDayAs: now) }.count == 1 && one[0].date >= now.addingTimeInterval(3 * 3600), "One used slot and spacing survive reopen")
let evening = date("2026-11-15T20:45:00+01:00")
check(plan(pet(at: evening), at: evening).map(\.date) == [date("2026-11-16T09:00:00+01:00")], "Evening departure gets exactly one morning invite")
let morning = date("2026-11-15T06:00:00+01:00")
check(plan(pet(at: morning), at: morning).first?.date == date("2026-11-15T09:00:00+01:00"), "Night wait resumes at nine")
let late = date("2026-11-15T20:00:00+01:00")
check(plan(pet(at: late), at: late).map(\.date) == [date("2026-11-15T20:30:00+01:00"), date("2026-11-16T09:00:00+01:00")], "Second invite waits until morning")

// Representative needs from the audit: evening visits allow a next-day return.
for hour in [8, 13, 17, 19, 20, 22] {
    let departure = date(String(format: "2026-11-15T%02d:00:00+01:00", hour))
    let snapshot = PetSnapshot(version: 1, petID: "default", name: "Gloria", savedAt: departure.timeIntervalSince1970,
        needs: ["fullness": 78, "energy": 76, "hygiene": 85, "play": 50, "contact": 65],
        resting: false, sociability: 0.5, mood: "calm")
    let results = plan(snapshot, at: departure)
    let expectedHours = hour == 8 ? [11, 15] : hour == 13 ? [16, 20] : hour == 17 ? [20, 9] : [9]
    check(results.map { calendar.component(.hour, from: $0.date) } == expectedHours, "Typical needs after departure at \(hour)")
    if hour >= 17 {
        check(results.last?.date == date("2026-11-16T09:00:00+01:00"), "Evening departure reaches next morning")
        check(snapshot.projected(at: results.last!.date).needs == snapshot.projected(at: departure.addingTimeInterval(8 * 3600)).needs,
              "Morning invitation does not add overnight decay")
    }
}
let nextMorning = date("2026-11-16T09:00:00+01:00")
let nightPet = pet(at: evening)
check(plan(nightPet, at: evening).count == 1, "Only one next-day invitation even with several low needs")
let blocked = [date("2026-11-15T13:00:00+01:00"), date("2026-11-15T18:00:00+01:00")]
check(plan(nightPet, at: evening, consumed: blocked).isEmpty, "Rolling budget can block the entire morning")
let releasing = [date("2026-11-15T10:00:00+01:00"), date("2026-11-15T18:00:00+01:00")]
check(plan(nightPet, at: evening, consumed: releasing).map(\.date) == [date("2026-11-16T10:00:00+01:00")], "Morning waits for rolling budget to free a slot")
check(plan(nightPet, at: nextMorning, consumed: [date("2026-11-16T07:00:00+01:00")]).map(\.date) == [date("2026-11-16T11:00:00+01:00")], "Morning respects four-hour spacing")
check(plan(nightPet, at: date("2026-11-16T11:30:00+01:00")).isEmpty, "No invitation at noon or beyond")
check(plan(pet(at: evening, low: []), at: evening).isEmpty, "Frozen healthy needs do not produce next-day urgency")
var ledger = PetReminderLedger()
ledger.pending = two.map(\.date)
ledger.cancelPending(at: now.addingTimeInterval(3600))
check(ledger.consumed == [two[0].date] && ledger.pending.isEmpty, "Past reservation consumed, future cancelled")
let restored = try JSONDecoder().decode(PetReminderLedger.self, from: JSONEncoder().encode(ledger))
check(restored.consumed == ledger.consumed && restored.isValid, "Budget survives process restart")
ledger.cancelPending(at: now)
check(ledger.lastObserved == now.addingTimeInterval(3600) && ledger.consumed.count == 1, "Clock rollback cannot erase consumed history")
ledger.cancelPending(at: now.addingTimeInterval(3 * 86400))
check(ledger.consumed.isEmpty, "Old budget history is bounded")
ledger.version = 2
check(!ledger.isValid, "Unknown ledger fails closed")

// Across both DST changes and every hour of a day, all requests stay inside
// local quiet hours, the save horizon, daily and rolling budgets.
for start in ["2026-03-28T00:00:00+01:00", "2026-03-29T00:00:00+01:00", "2026-10-24T00:00:00+02:00", "2026-10-25T00:00:00+02:00", "2026-11-15T00:00:00+01:00"] {
    for hour in 0..<24 {
        let time = date(start).addingTimeInterval(Double(hour) * 3600)
        let results = plan(pet(at: time, low: PetNeed.allCases), at: time)
        check(results.count <= 2, "Maximum two planned at \(time)")
        let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: time))!
        let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: nextDay)!
        check(results.filter { $0.date >= nextDay }.count <= 1, "Only one next-morning invite across DST")
        if results.count == 2 {
            check(results[1].date.timeIntervalSince(results[0].date) >= 4 * 3600, "Spacing across days and DST")
        }
        for item in results {
            check((9..<21).contains(calendar.component(.hour, from: item.date)), "Local quiet hours at \(item.date)")
            check(item.date >= time.addingTimeInterval(1800) && item.date < end, "Bounded horizon")
            check(pet(at: time, low: PetNeed.allCases).projected(at: item.date).value(item.need!) < 30, "Real projected need")
        }
    }
}
print("Reminders: \(checks) checks passed")

// Toilet reminders share the same consent, quiet hours and budget as all reminders.
var outingPet = pet(low: [])
outingPet.outingDay = -1
outingPet.yardMess = false
let outingPlan = plan(outingPet)
check(outingPlan.filter { $0.need == nil }.count == 1, "One toilet reminder per absence")
check(outingPlan.first?.need == nil && outingPlan.first?.body.contains("załatwić") == true, "Clear toilet invitation")
check(outingPlan.first?.date == now.addingTimeInterval(1800), "Toilet respects minimum delay")
outingPet.yardMess = true
check(plan(outingPet).allSatisfy { $0.need != nil }, "Pending cleanup never asks for another toilet trip")
outingPet.yardMess = false
outingPet.outingDay = Int(floor((now.timeIntervalSince1970 + Double(calendar.timeZone.secondsFromGMT(for: now))) / 86400))
check(plan(outingPet).filter { $0.need == nil }.allSatisfy { !calendar.isDate($0.date, inSameDayAs: now) }, "Today's trip is not repeated")
outingPet.outingDay! += 1
check(plan(outingPet).allSatisfy { $0.need != nil }, "Future outing day cannot reset after clock rollback")
var lateOuting = pet(at: evening, low: [])
lateOuting.outingDay = -1
check(plan(lateOuting, at: evening).first?.date == date("2026-11-16T09:00:00+01:00"), "Toilet respects quiet night")
check(plan(outingPet, consumed: [now, now.addingTimeInterval(-3600)]).filter { calendar.isDate($0.date, inSameDayAs: now) }.isEmpty, "Toilet shares daily budget")
print("Including toilet: \(checks) planner checks passed")

let saveObject: [String: Any] = ["schema_version": 15, "pet": [
    "pet_id": "legacy", "pet_name": "Gloria", "last_seen_at": now.timeIntervalSince1970,
    "needs": pet(low: []).needs, "resting": false, "traits": ["sociability": 0.5],
    "life": ["mood": "calm"], "yard_routines": ["outday": -1, "mess": true]
]]
let parsedOuting = PetSnapshot.fromGameSave(try! JSONSerialization.data(withJSONObject: saveObject))
check(parsedOuting?.outingDay == -1 && parsedOuting?.yardMess == true, "Native bridge reads persisted outing and cleanup")
check(plan(parsedOuting).allSatisfy { $0.need != nil }, "Saved mess suppresses toilet notification through the real decoder")
let snapshotRoundtrip = try! JSONDecoder().decode(PetSnapshot.self, from: JSONEncoder().encode(parsedOuting!))
check(snapshotRoundtrip == parsedOuting, "Shared snapshot roundtrip retains toilet state")
print("Toilet decoder included: \(checks) checks passed")

// Scheduled sleep: notifications coincide with wake time, never during a nap.
var scheduled = pet(at: date("2026-11-15T08:00:00+01:00"), low: [.fullness])
scheduled.rhythmOffset = 0
scheduled.awakeUntil = 0
let wakes = plan(scheduled, at: date("2026-11-15T08:00:00+01:00"))
check(wakes.filter { calendar.isDate($0.date, inSameDayAs: now) }.map { calendar.component(.hour, from: $0.date) } == [9, 12, 15, 18], "Four daytime wake notices each day")
check(wakes.allSatisfy { $0.body.hasPrefix("Już nie śpię!") && !$0.body.contains("ułożyć") }, "Wake notice reports care, not manual bedtime")
check(wakes.allSatisfy { !scheduled.projected(at: $0.date, calendar: calendar).resting }, "No alert while asleep")
check(plan(scheduled, at: date("2026-11-15T08:00:00+01:00"), consumed: wakes.map(\.date)).allSatisfy { !wakes.map(\.date).contains($0.date) }, "Durable budget prevents rescheduling consumed wake alerts")
scheduled.rhythmOffset = 90
check(plan(scheduled, at: date("2026-11-15T08:00:00+01:00")).first?.date == date("2026-11-15T10:30:00+01:00"), "Habit offset moves real wake notification")
var rested = pet(at: date("2026-11-15T08:59:00+01:00"), low: [])
rested.rhythmOffset = 0
rested.awakeUntil = 0
check(plan(rested, at: date("2026-11-15T08:59:00+01:00")).isEmpty, "Healthy wake does not invent an unmet need")
var sleepLedger = PetReminderLedger()
sleepLedger.pending = wakes.map(\.date)
check(sleepLedger.isValid, "Four wake reservations persist")
sleepLedger.cancelPending(at: wakes[1].date)
check(sleepLedger.consumed.count == 2 && sleepLedger.pending.isEmpty, "Wake reservations survive return to foreground")
for offset in [-30, 0, 90, 180] {
    for stamp in ["2026-03-29T00:00:00+01:00", "2026-10-25T00:00:00+02:00"] {
        let departure = date(stamp)
        var snapshot = pet(at: departure, low: [.fullness])
        snapshot.rhythmOffset = offset
        for reminder in plan(snapshot, at: departure) {
            check(!snapshot.projected(at: reminder.date, calendar: calendar).resting, "DST wake is awake")
            check((9..<21).contains(calendar.component(.hour, from: reminder.date)), "DST respects quiet hours")
        }
    }
}
print("Automatic sleep: \(checks) planner checks passed")

// A single background transition must schedule the whole week, without
// refreshing the snapshot or simulating extra loss of needs after eight hours.
scheduled.rhythmOffset = 0
let weekStart = date("2026-11-15T08:00:00+01:00")
let week = plan(scheduled, at: weekStart)
check(week.count == 28, "Seven days of four requests are queued on departure")
check(week.last?.date == date("2026-11-21T18:00:00+01:00"), "Last day remains scheduled without another launch")
check(plan(scheduled, at: date("2026-11-22T08:00:00+01:00")).isEmpty, "Expired snapshot cannot start another week")
check(plan(scheduled, at: date("2026-11-20T08:00:00+01:00")).count == 8, "Late replan keeps the original end date")
check(scheduled.projected(at: week.last!.date, calendar: calendar).needs == scheduled.projected(at: weekStart.addingTimeInterval(8 * 3600), calendar: calendar).needs,
      "A week of alerts does not add a week of need decay")
var fullLedger = PetReminderLedger()
fullLedger.pending = week.map(\.date)
let fullRoundtrip = try! JSONDecoder().decode(PetReminderLedger.self, from: JSONEncoder().encode(fullLedger))
check(fullRoundtrip.isValid && fullRoundtrip.pending == fullLedger.pending, "All 28 reservations survive serialization")
fullLedger.pending.append(weekStart)
check(!fullLedger.isValid, "Oversized queue rejected")
fullLedger.pending = Array(week.prefix(4).map(\.date))
check(fullLedger.isValid, "Existing build-35 four-request ledger remains readable")
var toiletWeek = pet(at: weekStart, low: [])
toiletWeek.rhythmOffset = 0
toiletWeek.outingDay = -1
toiletWeek.yardMess = false
check(plan(toiletWeek, at: weekStart).contains { $0.date > weekStart.addingTimeInterval(5 * 86400) && $0.need == nil }, "Outdoor need reaches later days too")
toiletWeek.yardMess = true
check(plan(toiletWeek, at: weekStart).allSatisfy { $0.need != nil }, "Uncollected mess suppresses toilet alerts for the whole week")
for stamp in ["2026-03-28T08:00:00+01:00", "2026-10-24T08:00:00+02:00", "2026-11-15T20:45:00+01:00"] {
    for offset in [-30, 0, 90, 180] {
        let departure = date(stamp)
        var snapshot = pet(at: departure, low: [.fullness])
        snapshot.rhythmOffset = offset
        let end = calendar.date(byAdding: .day, value: 7, to: departure)!
        let used = [departure.addingTimeInterval(-3600), departure.addingTimeInterval(-4 * 3600), departure.addingTimeInterval(-7 * 3600)]
        let reminders = plan(snapshot, at: departure, consumed: used)
        let allDates = used + reminders.map(\.date)
        check(reminders.count <= 28 && reminders.last!.date > departure.addingTimeInterval(6 * 86400), "Bounded queue still reaches day seven across DST")
        check(reminders == plan(snapshot, at: departure, consumed: used), "Planning is deterministic")
        for reminder in reminders {
            check(reminder.date >= departure.addingTimeInterval(60) && reminder.date < end, "Every request lies in the seven-calendar-day window")
            check((9..<21).contains(calendar.component(.hour, from: reminder.date)), "Whole week respects local quiet hours")
            check(!snapshot.projected(at: reminder.date, calendar: calendar).resting, "Whole week respects wake times")
            check(allDates.filter { calendar.isDate($0, inSameDayAs: reminder.date) }.count <= 4, "Daily limit includes pre-existing consumed alerts")
            check(allDates.filter { $0 > reminder.date.addingTimeInterval(-86400) && $0 <= reminder.date }.count <= 4, "Rolling 24-hour budget across midnight and DST")
            check(allDates.filter { $0 != reminder.date }.allSatisfy { abs($0.timeIntervalSince(reminder.date)) >= 7200 }, "Two-hour minimum includes old reservations")
        }
    }
}
print("Seven-day reminders: \(checks) planner checks passed")
