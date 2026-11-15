import Foundation

struct PetReminder: Equatable {
    let date: Date
    let need: PetNeed
    let name: String
    var body: String {
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
        version == 1 && consumed.count <= 100 && pending.count <= 2 &&
        ([lastObserved] + consumed + pending).allSatisfy { $0.timeIntervalSince1970.isFinite }
    }
}

enum PetReminderPlan {
    static let minimumDelay: TimeInterval = 30 * 60
    static let minimumGap: TimeInterval = 4 * 3600

    static func make(snapshot: PetSnapshot?, now: Date, consumed: [Date],
                     calendar: Calendar = .current) -> [PetReminder] {
        guard let snapshot, snapshot.isValid, snapshot.savedAt <= now.timeIntervalSince1970 else { return [] }
        let end = Date(timeIntervalSince1970: snapshot.savedAt + PetSnapshot.maxOffline)
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
                if let need = status.priorities.first(where: { need in
                    status.value(need) < 30 && !result.contains(where: { $0.need == need })
                }) {
                    result.append(PetReminder(date: date, need: need, name: snapshot.name))
                }
            }
            date = date.addingTimeInterval(15 * 60)
        }
        return result
    }
}
