import Foundation

struct PetReminder: Equatable {
    let date: Date
    let need: PetNeed?
    let name: String
    var wokeUp = false
    var body: String { (wokeUp ? "Już nie śpię! " : "") + request }
    private var request: String {
        guard let need else { return "Chcę wyjść się załatwić. Pójdziemy na podwórko?" }
        switch need {
        case .fullness: return "Burczy mi w brzuchu. Zjemy coś?"
        case .energy: return "Oczka mi się kleją. Pomożesz mi się ułożyć?"
        case .hygiene: return "Mam ochotę na czesanie. Znajdziesz chwilkę?"
        case .play: return "Piłka czeka obok mnie. Pobawimy się?"
        case .contact: return "Mam ochotę na głaskanie. Wpadniesz na chwilkę?"
        }
    }
}

/// Due reservations count even if Focus or the OS hid the alert. Cancelling a
/// future reservation frees it. Persisted separately from the read-only save.
struct PetReminderLedger: Codable {
    var version = 1
    var consumed: [Date] = []
    var pending: [Date] = []
    var lastObserved = Date(timeIntervalSince1970: 0)

    mutating func cancelPending(at now: Date) {
        consumed += pending.filter { $0 <= now }
        pending = []
        lastObserved = max(lastObserved, now)
        consumed = consumed.filter { $0 >= lastObserved.addingTimeInterval(-48 * 3600) }
    }

    var isValid: Bool {
        version == 1 && consumed.count <= 100 && pending.count <= PetReminderPlan.maximumPending &&
        ([lastObserved] + consumed + pending).allSatisfy { $0.timeIntervalSince1970.isFinite }
    }
}

enum PetReminderPlan {
    static let planningDays = 7
    static let maximumPending = planningDays * 4
    static let minimumDelay: TimeInterval = 30 * 60
    static let minimumGap: TimeInterval = 4 * 3600

    static func make(snapshot: PetSnapshot?, now: Date, consumed: [Date],
                     calendar: Calendar = .current) -> [PetReminder] {
        guard let snapshot, snapshot.isValid, snapshot.savedAt <= now.timeIntervalSince1970 else { return [] }
        if snapshot.rhythmOffset != nil {
            return wakePlan(snapshot: snapshot, now: now, consumed: consumed, calendar: calendar)
        }
        let savedAt = Date(timeIntervalSince1970: snapshot.savedAt)
        // The simulation freezes after eight hours, but its final state is still
        // useful next morning. Anchor the window to the save, never to a replan.
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: savedAt)),
              let end = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: nextDay) else { return [] }
        var date = now.addingTimeInterval(minimumDelay)
        var result: [PetReminder] = []
        while date < end && result.count < 2 {
            let hour = calendar.component(.hour, from: date)
            let history = consumed + result.map(\.date)
            let today = history.filter { calendar.isDate($0, inSameDayAs: date) }.count
            let recent = history.filter { $0 > date.addingTimeInterval(-24 * 3600) && $0 <= date }.count
            let spaced = history.allSatisfy { abs(date.timeIntervalSince($0)) >= minimumGap }
            if (9..<21).contains(hour) && today < 2 && recent < 2 && spaced {
                let status = snapshot.projected(at: date)
                // Match Godot's local calendar day. Existing saves without yard data
                // keep their old plan; a waiting mess must be cleaned in the game.
                let localDay = Int(floor((date.timeIntervalSince1970 + Double(calendar.timeZone.secondsFromGMT(for: date))) / 86400))
                let outingDue = snapshot.outingDay.map { localDay > $0 } ?? false
                if outingDue && snapshot.yardMess != true && !status.resting && !result.contains(where: { $0.need == nil }) {
                    result.append(PetReminder(date: date, need: nil, name: snapshot.name))
                    if date >= nextDay { break }
                } else if let need = status.priorities.first(where: { need in
                    status.value(need) < 30 && !result.contains(where: { $0.need == need })
                }) {
                    result.append(PetReminder(date: date, need: need, name: snapshot.name))
                    // At most one invitation on the morning after the save.
                    if date >= nextDay { break }
                }
            }
            date = date.addingTimeInterval(15 * 60)
        }
        return result
    }
}

extension PetReminderPlan {
    // Schedule the actual local wake boundaries, including half-hour habit offsets.
    // The existing opt-in, durable budget and quiet hours still apply.
    static func wakePlan(snapshot: PetSnapshot, now: Date, consumed: [Date], calendar: Calendar) -> [PetReminder] {
        let saved = Date(timeIntervalSince1970: snapshot.savedAt)
        // Anchor to the last saved visit, so reloading an old snapshot never
        // extends the absence. Calendar days preserve local time across DST.
        guard let end = calendar.date(byAdding: .day, value: planningDays, to: saved), now < end else { return [] }
        var result: [PetReminder] = []
        // Minute precision avoids dependence on the second at which the app closed.
        var date = Date(timeIntervalSince1970: ceil(now.addingTimeInterval(60).timeIntervalSince1970 / 60) * 60)
        while date < end && result.count < maximumPending {
            let local = date.timeIntervalSince1970 + Double(calendar.timeZone.secondsFromGMT(for: date))
            let shifted = local - Double(snapshot.rhythmOffset ?? 0) * 60
            let hour = (Int(floor(shifted / 3600)) % 24 + 24) % 24
            let history = consumed + result.map(\.date)
            if Int(shifted) % 3600 == 0 && PetSnapshot.wakeHours.contains(hour)
                && (9..<21).contains(calendar.component(.hour, from: date))
                && history.filter({ calendar.isDate($0, inSameDayAs: date) }).count < 4
                && history.filter({ $0 > date.addingTimeInterval(-24 * 3600) && $0 <= date }).count < 4
                && history.allSatisfy({ abs(date.timeIntervalSince($0)) >= 2 * 3600 }) {
                let status = snapshot.projected(at: date, calendar: calendar)
                let day = Int(floor(local / 86400))
                let outing = snapshot.outingDay.map { day > $0 } ?? false
                if outing && snapshot.yardMess != true {
                    result.append(PetReminder(date: date, need: nil, name: snapshot.name, wokeUp: true))
                } else if let need = status.priorities.first(where: { $0 != .energy && status.value($0) < 60 }) {
                    result.append(PetReminder(date: date, need: need, name: snapshot.name, wokeUp: true))
                }
            }
            date = date.addingTimeInterval(60)
        }
        return result
    }
}
