import Foundation
import UIKit
import WidgetKit
import OSLog

/// Godot commits Documents/pet.json atomically. Observe the directory so a rename
/// cannot detach the watcher. Startup, a foreground timer and background flush
/// also recover missed notifications. All bridge state stays on the main queue.
@MainActor final class PetWidgetBridge {
    static let shared = PetWidgetBridge()
    private let logger = Logger(subsystem: "YuFriend", category: "Widget")
    private var watcher: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var pending: DispatchWorkItem?
    private var lastPublished: PetSnapshot?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var sourceURL: URL?
    private var reminders: PetReminderController?
    private var foreground = true

    func start() {
        guard sourceURL == nil,
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        sourceURL = documents.appendingPathComponent("pet.json")
        foreground = UIApplication.shared.applicationState != .background
        reminders = PetReminderController(documents: documents)
        let descriptor = open(documents.path, O_EVTONLY)
        if descriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename], queue: .main)
            source.setEventHandler { [weak self] in self?.schedulePublish() }
            source.setCancelHandler { close(descriptor) }
            watcher = source
            source.resume()
        }
        let center = NotificationCenter.default
        for name in [UIApplication.didBecomeActiveNotification, UIScene.didActivateNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.foreground = true
                    self?.publish(forceReminders: true)
                }
            })
        }
        for name in [UIApplication.didEnterBackgroundNotification, UIScene.didEnterBackgroundNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                // Claim background execution before UIKit's callback returns;
                // deferring this to a Task can let iOS suspend us first.
                MainActor.assumeIsolated { self?.flushInBackground() }
            })
        }
        observers.append(center.addObserver(forName: UIApplication.significantTimeChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.publish(forceReminders: true) }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if UIApplication.shared.applicationState == .active { self?.publish() }
            }
        }
        publish()
    }

    private func schedulePublish() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.publish() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func finishBackgroundTask() {
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
    }

    private func flushInBackground() {
        // The scene event is authoritative. UIApplication.applicationState can
        // still be inactive while the scene is already entering the background.
        foreground = false
        finishBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Pet widget snapshot") { [weak self] in
            self?.finishBackgroundTask()
        }
        publish()
        // The engine's pause notification may commit after the UIKit observer.
        let task = backgroundTask
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.backgroundTask == task else { return }
            self.publish()
            Task { @MainActor in
                await self.reminders?.finishPendingUpdates()
                // A second scene callback may have opened a newer task.
                if self.backgroundTask == task { self.finishBackgroundTask() }
            }
        }
    }

    private func publish(forceReminders: Bool = false) {
        var snapshot: PetSnapshot?
        if let sourceURL,
           let size = try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 1_048_576,
           let data = try? Data(contentsOf: sourceURL) { snapshot = PetSnapshot.fromGameSave(data) }
        reminders?.update(snapshot: snapshot, foreground: foreground, force: forceReminders)
        guard let snapshot, snapshot != lastPublished else { return }
        guard let destination = PetWidgetConfig.sharedURL else {
            logger.error("Widget App Group unavailable; check signing and entitlements.")
            return
        }
        do {
            let encoded = try JSONEncoder().encode(snapshot)
            try encoded.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            lastPublished = snapshot
            WidgetCenter.shared.reloadTimelines(ofKind: PetWidgetConfig.kind)
        } catch {
            logger.error("Could not publish widget snapshot: \(error.localizedDescription, privacy: .public)")
        }
    }
}

@_cdecl("yufriend_widget_start")
func yufriendWidgetStart() {
    DispatchQueue.main.async { PetWidgetBridge.shared.start() }
}
