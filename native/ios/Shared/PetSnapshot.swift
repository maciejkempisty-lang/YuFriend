import Foundation

enum PetWidgetConfig {
    static let kind = "YuFriendPetWidget"
    static let filename = "pet-widget.json"
    static var appGroup: String? {
        Bundle.main.object(forInfoDictionaryKey: "YuFriendAppGroup") as? String
    }
    static var sharedURL: URL? {
        guard let group = appGroup else { return nil }
        return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group)?
            .appendingPathComponent(filename)
    }
}

enum PetNeed: String, CaseIterable, Codable {
    case fullness, energy, hygiene, play, contact

    var title: String {
        switch self {
        case .fullness: return "Sytość"
        case .energy: return "Energia"
        case .hygiene: return "Czystość"
        case .play: return "Zabawa"
        case .contact: return "Bliskość"
        }
    }
    var suggestion: String {
        switch self {
        case .fullness: return "Pora na jedzenie"
        case .energy: return "Czas na drzemkę"
        case .hygiene: return "Przyda się czesanie"
        case .play: return "Chwila zabawy?"
        case .contact: return "Pora na głaskanie"
        }
    }
    var symbol: String {
        switch self {
        case .fullness: return "fork.knife"
        case .energy: return "moon.fill"
        case .hygiene: return "sparkles"
        case .play: return "tennisball.fill"
        case .contact: return "heart.fill"
        }
    }
    var hourlyLoss: Double {
        switch self {
        case .fullness, .play: return 7
        case .energy, .contact: return 5
        case .hygiene: return 3
        }
    }
}

/// A separate, read-only widget contract. The widget never writes the game save.
struct PetSnapshot: Codable, Equatable {
    let version: Int
    let petID: String
    let name: String
    let savedAt: Double
    let needs: [String: Double]
    let resting: Bool
    let sociability: Double
    let mood: String

    var isValid: Bool {
        version == 1 && !petID.isEmpty && petID.count <= 200 &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && name.count <= 100 &&
        savedAt.isFinite && savedAt >= 0 && sociability.isFinite && (0...1).contains(sociability) &&
        Self.moods[mood] != nil && PetNeed.allCases.allSatisfy {
            guard let value = needs[$0.rawValue] else { return false }
            return value.isFinite && (0...100).contains(value)
        }
    }

    static let moods = ["calm": "Spokojny dzień", "playful": "Ochota na psoty",
                        "cuddly": "Blisko Ciebie", "sleepy": "Senny dzień", "curious": "Czas na odkrycia"]
    static let maxOffline: TimeInterval = 8 * 3600

    static func read(from url: URL) -> PetSnapshot? {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 16_384,
              let data = try? Data(contentsOf: url),
              let snapshot = try? JSONDecoder().decode(Self.self, from: data), snapshot.isValid else { return nil }
        return snapshot
    }

    /// Decode only the fields needed by the widget; reject unknown save versions.
    static func fromGameSave(_ data: Data) -> PetSnapshot? {
        struct Save: Decodable {
            struct Pet: Decodable {
                struct Traits: Decodable { let sociability: Double }
                struct Life: Decodable { let mood: String }
                let pet_id: String
                let pet_name: String
                let last_seen_at: Double
                let needs: [String: Double]
                let resting: Bool
                let traits: Traits
                let life: Life
            }
            let schema_version: Int
            let pet: Pet
        }
        guard data.count <= 1_048_576,
              let save = try? JSONDecoder().decode(Save.self, from: data), [4, 5, 6, 7, 8, 9, 10, 11, 12].contains(save.schema_version) else { return nil }
        let pet = save.pet
        let result = Self(version: 1, petID: pet.pet_id, name: pet.pet_name, savedAt: pet.last_seen_at,
                          needs: pet.needs, resting: pet.resting, sociability: pet.traits.sociability, mood: pet.life.mood)
        return result.isValid ? result : nil
    }

    /// Mirrors NeedsSystem.advance(..., offline: true), including the wake threshold.
    func projected(at date: Date) -> PetStatus {
        let elapsed = min(Self.maxOffline, max(0, date.timeIntervalSince1970 - savedAt))
        var values = needs
        var sleeping = resting
        func advance(_ seconds: Double) {
            guard seconds > 0 else { return }
            for need in PetNeed.allCases {
                var rate = need.hourlyLoss
                if need == .contact { rate *= 0.7 + sociability * 0.6 }
                if need == .energy && sleeping { rate -= 18 }
                values[need.rawValue] = min(100, max(15, values[need.rawValue, default: 0] - rate * seconds / 3600))
            }
        }
        if sleeping && elapsed > 0 {
            let sleepTime = min(elapsed, max(0, (85 - values["energy", default: 0]) / 13 * 3600))
            advance(sleepTime)
            if values["energy", default: 0] >= 85 - 0.001 { sleeping = false }
            advance(elapsed - sleepTime)
        } else {
            advance(elapsed)
        }
        return PetStatus(snapshot: self, needs: values, resting: sleeping,
                         stale: date.timeIntervalSince1970 - savedAt >= Self.maxOffline)
    }

    static let example = Self(version: 1, petID: "preview", name: "Gloria", savedAt: 0,
                              needs: ["fullness": 27, "energy": 76, "hygiene": 85, "play": 42, "contact": 65],
                              resting: false, sociability: 0.5, mood: "calm")
}

struct PetStatus {
    let snapshot: PetSnapshot
    let needs: [String: Double]
    let resting: Bool
    let stale: Bool

    func value(_ need: PetNeed) -> Double { needs[need.rawValue, default: 0] }
    var priorities: [PetNeed] {
        // Energy is being replenished during sleep; do not ask the user to wake the dog.
        PetNeed.allCases.filter { !resting || $0 != .energy }.sorted {
            if value($0) == value($1) {
                return PetNeed.allCases.firstIndex(of: $0)! < PetNeed.allCases.firstIndex(of: $1)!
            }
            return value($0) < value($1)
        }
    }
    var urgentNeeds: [PetNeed] { priorities.filter { value($0) < 60 } }
    var headline: String {
        if stale { return "Zajrzyj do pieska" }
        return urgentNeeds.first?.suggestion ?? "Wszystko w porządku"
    }
    var moodLabel: String { resting ? "Odpoczywa" : PetSnapshot.moods[snapshot.mood, default: "Spokojny dzień"] }
}
