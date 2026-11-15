import Foundation
import UserNotifications
import OSLog

@MainActor protocol PetReminderCenter {
    func authorization() async -> UNAuthorizationStatus
    func requestAuthorization() async throws
    func add(_ request: UNNotificationRequest) async throws
    func removePending(_ identifiers: [String])
    func removeDelivered(_ identifiers: [String])
}

@MainActor final class SystemPetReminderCenter: PetReminderCenter {
    private let center = UNUserNotificationCenter.current()
    func authorization() async -> UNAuthorizationStatus { await center.notificationSettings().authorizationStatus }
    func requestAuthorization() async throws { _ = try await center.requestAuthorization(options: [.alert, .sound]) }
    func add(_ request: UNNotificationRequest) async throws { try await center.add(request) }
    func removePending(_ identifiers: [String]) { center.removePendingNotificationRequests(withIdentifiers: identifiers) }
    func removeDelivered(_ identifiers: [String]) { center.removeDeliveredNotifications(withIdentifiers: identifiers) }
}

/// File commands keep the generated Godot project free of a custom engine ABI.
/// All state and notification-center mutations are serialized on the main actor.
@MainActor final class PetReminderController {
    private struct Preference: Codable, Equatable { let enabled: Bool; let request: String }
    private let center: PetReminderCenter
    private let logger = Logger(subsystem: "YuFriend", category: "Reminders")
    private let documents: URL
    private let defaults: UserDefaults
    private let clock: () -> Date
    private let calendar: Calendar
    private let identifiers = ["yufriend.need.0", "yufriend.need.1"]
    private var snapshot: PetSnapshot?
    private var preference: Preference?
    private var foreground = true
    private var revision = 0
    private var working = false
    private var initialized = false
    private var ledger = PetReminderLedger()
    private var ledgerReadable = true

    init(documents: URL, center: PetReminderCenter? = nil, defaults: UserDefaults = .standard,
         clock: @escaping () -> Date = Date.init, calendar: Calendar = .autoupdatingCurrent) {
        self.documents = documents
        self.center = center ?? SystemPetReminderCenter()
        self.defaults = defaults
        self.clock = clock
        self.calendar = calendar
        let url = documents.appendingPathComponent("reminder-ledger.json")
        if FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url), data.count <= 32_768,
               let decoded = try? JSONDecoder().decode(PetReminderLedger.self, from: data), decoded.isValid {
                ledger = decoded
            } else { ledgerReadable = false }
        }
    }

    func update(snapshot: PetSnapshot?, foreground: Bool, force: Bool = false) {
        let url = documents.appendingPathComponent("reminders.json")
        let data = try? Data(contentsOf: url)
        let next = data.flatMap { $0.count <= 4096 ? try? JSONDecoder().decode(Preference.self, from: $0) : nil }
        guard force || !initialized || snapshot != self.snapshot || next != preference || foreground != self.foreground else { return }
        initialized = true
        self.snapshot = snapshot
        self.preference = next
        self.foreground = foreground
        revision += 1
        // Cancel immediately, including while an authorization dialog is open.
        center.removePending(identifiers)
        if foreground { center.removeDelivered(identifiers) }
        if !working {
            working = true
            Task { await drain() }
        }
    }

    private func persistLedger() -> Bool {
        guard ledgerReadable else { return false }
        do {
            try JSONEncoder().encode(ledger).write(to: documents.appendingPathComponent("reminder-ledger.json"),
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            logger.error("Could not persist reminder budget: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func status(_ value: String) {
        let object: [String: Any] = ["status": value, "enabled": preference?.enabled == true,
                                  "request": preference?.request ?? "", "pending": ledger.pending.count]
        let url = documents.appendingPathComponent("reminders-status.json")
        guard let data = try? JSONSerialization.data(withJSONObject: object),
              (try? Data(contentsOf: url)) != data else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func drain() async {
        while true {
            let current = revision
            await apply(current)
            if current == revision { break }
        }
        working = false
    }

    private func apply(_ current: Int) async {
        center.removePending(identifiers)
        let now = clock()
        let clockRolledBack = now < ledger.lastObserved
        ledger.cancelPending(at: now)
        guard persistLedger() else { status("storage_error"); return }
        guard preference?.enabled == true else { status("off"); return }
        var authorization = await center.authorization()
        guard current == revision else { return }
        // Only an explicit new toggle command may show the permission prompt.
        if authorization == .notDetermined && foreground,
           let request = preference?.request, !request.isEmpty,
           defaults.string(forKey: "YuFriendReminderPermissionRequest") != request {
            defaults.set(request, forKey: "YuFriendReminderPermissionRequest")
            do { try await center.requestAuthorization() }
            catch { status("error"); return }
            authorization = await center.authorization()
            guard current == revision else { return }
        }
        guard [UNAuthorizationStatus.authorized, .provisional].contains(authorization) else {
            status(authorization == .denied ? "denied" : "waiting")
            return
        }
        guard !foreground else { status("on"); return }
        guard !clockRolledBack else { status("clock_error"); return }
        let reminders = PetReminderPlan.make(snapshot: snapshot, now: now, consumed: ledger.consumed, calendar: calendar)
        // Reserve durably before adding requests: a crash cannot reset the cap.
        ledger.pending = reminders.map(\.date)
        guard persistLedger() else { status("storage_error"); return }
        for (index, reminder) in reminders.enumerated() {
            guard current == revision else { break }
            let content = UNMutableNotificationContent()
            content.title = reminder.name
            content.body = reminder.body
            content.sound = .default
            content.threadIdentifier = "yufriend.needs"
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, reminder.date.timeIntervalSinceNow), repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: identifiers[index], content: content, trigger: trigger))
            } catch {
                center.removePending(identifiers)
                ledger.pending = []
                _ = persistLedger()
                status("error")
                return
            }
        }
        if current != revision {
            center.removePending(identifiers)
        } else { status("on") }
    }
}
