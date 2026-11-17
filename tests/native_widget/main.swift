import Foundation

var checks = 0
func check(_ condition: Bool, _ message: String) {
    checks += 1
    if !condition { fatalError(message) }
}

let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
let fixtures = try JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL)) as! [[String: Any]]
for (index, fixture) in fixtures.enumerated() {
    let data = try JSONSerialization.data(withJSONObject: fixture["save"]!)
    guard let snapshot = PetSnapshot.fromGameSave(data) else { fatalError("Fixture \(index) rejected") }
    let at = fixture["at"] as! Double
    let status = snapshot.projected(at: Date(timeIntervalSince1970: at))
    let expected = fixture["needs"] as! [String: Double]
    for need in PetNeed.allCases {
        check(abs(status.value(need) - expected[need.rawValue]!) < 0.00001, "Godot parity fixture \(index): \(need)")
    }
    check(status.resting == fixture["resting"] as! Bool, "Wake threshold parity \(index)")
}

let sampleSave = fixtures[0]["save"] as! [String: Any]
var legacySave = sampleSave
legacySave["schema_version"] = 4
check(PetSnapshot.fromGameSave(try JSONSerialization.data(withJSONObject: legacySave)) != nil, "Keep reading v4 alongside v5")
var malformed = sampleSave
malformed["schema_version"] = 99
check(PetSnapshot.fromGameSave(try JSONSerialization.data(withJSONObject: malformed)) != nil, "Accept future schema with valid widget fields")
for version: Any in [0, 3, -1, 4.5, "15", NSNull()] {
    malformed["schema_version"] = version
    check(PetSnapshot.fromGameSave(try JSONSerialization.data(withJSONObject: malformed)) == nil, "Reject unsupported or invalid schema \(version)")
}
for version in [4, 15, 16, 99, 10000] {
    malformed = sampleSave
    malformed["schema_version"] = version
    malformed["new_game_system"] = ["anything": true]
    check(PetSnapshot.fromGameSave(try JSONSerialization.data(withJSONObject: malformed)) != nil, "Ignore additive fields in v\(version)")
    var invalidPet = sampleSave["pet"] as! [String: Any]
    invalidPet["needs"] = ["energy": 20]
    malformed["pet"] = invalidPet
    check(PetSnapshot.fromGameSave(try JSONSerialization.data(withJSONObject: malformed)) == nil, "Still validate required fields in v\(version)")
}
for invalid: Any in [-1, 101, "hungry", NSNull()] {
    malformed = sampleSave
    malformed["schema_version"] = 99
    var invalidPet = sampleSave["pet"] as! [String: Any]
    var needs = invalidPet["needs"] as! [String: Any]
    needs["energy"] = invalid
    invalidPet["needs"] = needs
    malformed["pet"] = invalidPet
    check(PetSnapshot.fromGameSave(try JSONSerialization.data(withJSONObject: malformed)) == nil, "Reject invalid future need \(invalid)")
}
var brokenPet = sampleSave["pet"] as! [String: Any]
brokenPet["needs"] = ["energy": 20]
malformed = sampleSave
malformed["pet"] = brokenPet
check(PetSnapshot.fromGameSave(try JSONSerialization.data(withJSONObject: malformed)) == nil, "Reject missing needs")
check(PetSnapshot.fromGameSave(Data("{partial".utf8)) == nil, "Reject partial write")

let example = PetSnapshot.example
let healthy = PetSnapshot(version: 1, petID: "healthy", name: "Piesek", savedAt: 0,
                          needs: Dictionary(uniqueKeysWithValues: PetNeed.allCases.map { ($0.rawValue, 90.0) }),
                          resting: false, sociability: 0.5, mood: "calm")
check(healthy.projected(at: Date(timeIntervalSince1970: 0)).urgentNeeds.isEmpty, "Healthy pet has no invented urgency")
check(example.projected(at: Date(timeIntervalSince1970: 0)).priorities.first == .fullness, "Lowest need comes first")
check(example.projected(at: Date(timeIntervalSince1970: 8 * 3600)).stale, "Stale state requires opening the game")
check(!example.projected(at: Date(timeIntervalSince1970: -100)).stale, "Clock rollback is not stale")
let sleeping = PetSnapshot(version: 1, petID: "sleep", name: "Śpioch", savedAt: 0,
                           needs: ["fullness": 20, "energy": 15, "hygiene": 70, "play": 20, "contact": 80],
                           resting: true, sociability: 1, mood: "sleepy").projected(at: Date(timeIntervalSince1970: 1))
check(!sleeping.priorities.contains(.energy), "No request to wake a sleeping pet")
check(sleeping.priorities.first == .fullness, "Tied needs have deterministic priority")

let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: temp) }
let shared = temp.appendingPathComponent(PetWidgetConfig.filename)
check(PetSnapshot.read(from: shared) == nil, "First launch without a snapshot")
try JSONEncoder().encode(example).write(to: shared, options: .atomic)
check(PetSnapshot.read(from: shared) == example, "Shared snapshot round trip")
try Data("{broken".utf8).write(to: shared)
check(PetSnapshot.read(from: shared) == nil, "Malformed shared snapshot is safe")
try Data(repeating: 32, count: 20_000).write(to: shared)
check(PetSnapshot.read(from: shared) == nil, "Oversized shared snapshot is safe")
print("Widget: \(checks) checks passed; \(fixtures.count) projections match Godot")
