import Foundation
import UserNotifications

@MainActor final class FakeCenter: PetReminderCenter {
    var allowed = UNAuthorizationStatus.notDetermined
    var prompts = 0
    var requests: [String: UNNotificationRequest] = [:]
    var holdAdd = false
    var continuation: CheckedContinuation<Void, Never>?
    var failAdd = false
    var failAfter: Int?
    func authorization() async -> UNAuthorizationStatus { allowed }
    func requestAuthorization() async throws { prompts += 1; allowed = .authorized }
    func add(_ request: UNNotificationRequest) async throws {
        if holdAdd { await withCheckedContinuation { continuation = $0 } }
        if failAdd || failAfter.map({ requests.count >= $0 }) == true { throw NSError(domain: "test", code: 1) }
        requests[request.identifier] = request
    }
    func removePending(_ identifiers: [String]) { for id in identifiers { requests.removeValue(forKey: id) } }
    func removeDelivered(_ identifiers: [String]) {}
}

@main struct ControllerTests {
    @MainActor static func main() async throws {
        var checks = 0
        func check(_ condition: Bool, _ message: String) {
            checks += 1
            if !condition { fatalError(message) }
        }
        func settle() async { for _ in 0..<20 { try? await Task.sleep(nanoseconds: 1_000_000) } }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let suite = "YuFriendReminderTest." + UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        var now = ISO8601DateFormatter().date(from: "2026-11-15T09:00:00Z")!
        let snapshot = PetSnapshot(version: 1, petID: "test", name: "Gloria", savedAt: now.timeIntervalSince1970,
            needs: ["fullness": 20, "energy": 90, "hygiene": 90, "play": 20, "contact": 90],
            resting: false, sociability: 0.5, mood: "calm")
        func preference(_ enabled: Bool, _ request: String) throws {
            try JSONSerialization.data(withJSONObject: ["enabled": enabled, "request": request])
                .write(to: directory.appendingPathComponent("reminders.json"), options: .atomic)
        }
        func status() -> String {
            let data = try! Data(contentsOf: directory.appendingPathComponent("reminders-status.json"))
            return (try! JSONSerialization.jsonObject(with: data) as! [String: Any])["status"] as! String
        }
        let center = FakeCenter()
        let controller = PetReminderController(documents: directory, center: center, defaults: defaults, clock: { now }, calendar: calendar)
        controller.update(snapshot: snapshot, foreground: true)
        await settle()
        check(center.prompts == 0 && status() == "off" && center.requests.isEmpty, "No prompt or schedule before opt-in")
        try preference(true, "enable-1")
        controller.update(snapshot: snapshot, foreground: true)
        await settle()
        check(center.prompts == 1 && status() == "on" && center.requests.isEmpty, "Explicit opt-in prompts once; no foreground reminders")
        controller.update(snapshot: snapshot, foreground: false)
        await settle()
        check(center.requests.count == 2 && center.requests.values.allSatisfy { $0.content.title == "Gloria" }, "Background schedules named reminders")
        controller.update(snapshot: snapshot, foreground: true)
        await settle()
        check(center.requests.isEmpty && center.prompts == 1, "Return cancels pending and does not repeat permission prompt")
        controller.update(snapshot: snapshot, foreground: false)
        await settle()
        now = now.addingTimeInterval(5 * 3600)
        controller.update(snapshot: snapshot, foreground: true)
        await settle()
        let restarted = PetReminderController(documents: directory, center: center, defaults: defaults, clock: { now }, calendar: calendar)
        restarted.update(snapshot: snapshot, foreground: false)
        await settle()
        check(center.requests.count == 1 && center.requests.values.allSatisfy {
            ($0.trigger as? UNTimeIntervalNotificationTrigger)?.timeInterval == 19.5 * 3600
        }, "Due budget survives restart: next invitation waits until the next morning's rolling slot")
        // Isolate the remaining lifecycle tests from the consumed budget.
        try FileManager.default.removeItem(at: directory.appendingPathComponent("reminder-ledger.json"))
        now = Date(timeIntervalSince1970: snapshot.savedAt)
        let fresh = PetReminderController(documents: directory, center: center, defaults: defaults, clock: { now }, calendar: calendar)
        fresh.update(snapshot: snapshot, foreground: false)
        await settle()
        check(center.requests.count == 2, "Fresh ledger schedules")
        fresh.update(snapshot: nil, foreground: false)
        await settle()
        check(center.requests.isEmpty, "Invalid or unsupported save cancels stale reminders")
        fresh.update(snapshot: snapshot, foreground: false)
        await settle()
        try preference(false, "off-1")
        fresh.update(snapshot: snapshot, foreground: false)
        await settle()
        check(center.requests.isEmpty && status() == "off", "Opt-out cancels existing requests")
        try preference(true, "enable-2")
        center.allowed = .denied
        fresh.update(snapshot: snapshot, foreground: true)
        await settle()
        check(status() == "denied" && center.prompts == 1 && center.requests.isEmpty, "Denied permission cannot prompt repeatedly")
        center.allowed = .authorized
        fresh.update(snapshot: snapshot, foreground: true, force: true)
        await settle()
        check(status() == "on", "Return from system settings refreshes authorization")
        center.holdAdd = true
        fresh.update(snapshot: snapshot, foreground: false)
        await settle()
        check(center.continuation != nil, "Race fixture has an in-flight add")
        var drained = false
        Task { await fresh.finishPendingUpdates(); drained = true }
        await settle()
        check(!drained, "Background completion waits for in-flight notification registration")
        try preference(false, "off-during-add")
        fresh.update(snapshot: snapshot, foreground: false)
        center.holdAdd = false
        center.continuation?.resume()
        center.continuation = nil
        await settle()
        check(center.requests.isEmpty && status() == "off", "Late add completion cannot undo opt-out")
        check(drained, "Background completion resumes after the revised queue finishes")
        await fresh.finishPendingUpdates()
        check(center.requests.isEmpty, "Already idle controller completes without another update")
        try preference(true, "enable-3")
        center.failAdd = true
        fresh.update(snapshot: snapshot, foreground: false)
        await settle()
        check(center.requests.isEmpty && status() == "error", "Scheduling failure removes partial schedule")
        center.failAdd = false
        now = ISO8601DateFormatter().date(from: "2026-11-15T20:45:00Z")!
        let eveningSnapshot = PetSnapshot(version: 1, petID: "test", name: "Gloria", savedAt: now.timeIntervalSince1970,
            needs: snapshot.needs, resting: false, sociability: 0.5, mood: "calm")
        fresh.update(snapshot: eveningSnapshot, foreground: false)
        await settle()
        check(center.requests.count == 1 && center.requests.values.allSatisfy {
            let trigger = $0.trigger as? UNTimeIntervalNotificationTrigger
            return trigger?.timeInterval == 12.25 * 3600 && trigger?.repeats == false
        }, "Evening departure registers one non-repeating request for nine next morning")
        let savedLedger = try JSONDecoder().decode(PetReminderLedger.self,
            from: Data(contentsOf: directory.appendingPathComponent("reminder-ledger.json")))
        check(savedLedger.pending == [now.addingTimeInterval(12.25 * 3600)], "Morning reservation is persisted")
        fresh.update(snapshot: eveningSnapshot, foreground: true)
        await settle()
        check(center.requests.isEmpty, "Return before morning cancels the overnight request")
        now = ISO8601DateFormatter().date(from: "2026-11-18T08:00:00Z")!
        let wakeSnapshot = PetSnapshot(version: 1, petID: "test", name: "Gloria", savedAt: now.timeIntervalSince1970,
            needs: snapshot.needs, resting: true, sociability: 0.5, mood: "calm", rhythmOffset: 0, awakeUntil: 0)
        fresh.update(snapshot: wakeSnapshot, foreground: false)
        await settle()
        check(center.requests.count == 28 && center.requests.values.allSatisfy { $0.content.body.hasPrefix("Już nie śpię!") },
              "All seven days of wake requests reach the notification center")
        let wakeLedger = try JSONDecoder().decode(PetReminderLedger.self,
            from: Data(contentsOf: directory.appendingPathComponent("reminder-ledger.json")))
        check(wakeLedger.isValid && wakeLedger.pending.count == 28, "Seven days of wake reservations are durable")
        let wakeRestart = PetReminderController(documents: directory, center: center, defaults: defaults, clock: { now }, calendar: calendar)
        wakeRestart.update(snapshot: wakeSnapshot, foreground: false)
        await settle()
        check(center.requests.count == 28 && status() == "on", "Restart reads and replans a 28-request ledger")
        wakeRestart.update(snapshot: wakeSnapshot, foreground: true)
        await settle()
        check(center.requests.isEmpty, "Foreground return cancels the entire seven-day queue")
        center.failAfter = 10
        wakeRestart.update(snapshot: wakeSnapshot, foreground: false)
        await settle()
        check(center.requests.isEmpty && status() == "error", "Failure deep in a weekly queue clears every partially scheduled request")
        center.failAfter = nil
        wakeRestart.update(snapshot: wakeSnapshot, foreground: false, force: true)
        await settle()
        check(center.requests.count == 28, "Weekly queue can be rebuilt after scheduling error")
        try preference(false, "disable-week")
        wakeRestart.update(snapshot: wakeSnapshot, foreground: false)
        await settle()
        check(center.requests.isEmpty && status() == "off", "Opt-out cancels every day of the queue")
        try preference(true, "restore-week")
        wakeRestart.update(snapshot: wakeSnapshot, foreground: false)
        await settle()
        now = now.addingTimeInterval(3 * 86400)
        let multiDayRestart = PetReminderController(documents: directory, center: center, defaults: defaults, clock: { now }, calendar: calendar)
        multiDayRestart.update(snapshot: wakeSnapshot, foreground: false)
        await settle()
        check(center.requests.count == 16 && status() == "on", "Restart after three days retains only the remaining four days")
        let afterDays = try JSONDecoder().decode(PetReminderLedger.self,
            from: Data(contentsOf: directory.appendingPathComponent("reminder-ledger.json")))
        check(afterDays.isValid && !afterDays.consumed.isEmpty && afterDays.pending.count == 16,
              "Multiday return preserves consumed budget and remaining reservations")
        try Data("broken-ledger".utf8).write(to: directory.appendingPathComponent("reminder-ledger.json"))
        let broken = PetReminderController(documents: directory, center: center, defaults: defaults, clock: { now }, calendar: calendar)
        broken.update(snapshot: snapshot, foreground: false)
        await settle()
        check(center.requests.isEmpty && status() == "storage_error", "Corrupt budget fails closed without resetting the cap")
        check(try String(contentsOf: directory.appendingPathComponent("reminder-ledger.json"), encoding: .utf8) == "broken-ledger", "Corrupt ledger is preserved")
        print("Reminder controller: \(checks) checks passed")
    }
}
