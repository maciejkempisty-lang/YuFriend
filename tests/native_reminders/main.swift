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
            check(pet(at: time, low: PetNeed.allCases).projected(at: item.date).value(item.need) < 30, "Real projected need")
        }
    }
}
print("Reminders: \(checks) checks passed")
