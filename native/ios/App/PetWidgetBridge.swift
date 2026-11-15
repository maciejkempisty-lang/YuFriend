import Foundation
import UIKit
import WidgetKit
import OSLog

/// Godot commits Documents/pet.json atomically. Observe the directory so a rename
/// cannot detach the watcher. Startup, a foreground timer and background flush
/// also recover missed notifications. All bridge state stays on the main queue.
final class PetWidgetBridge {
    static let shared = PetWidgetBridge()
    private let logger = Logger(subsystem: "YuFriend", category: "Widget")
    private var watcher: DispatchSourceFileSystemObject?
    private var timer: Timer?
    private var observers: [NSObjectProtocol] = []
    private var pending: DispatchWorkItem?
    private var lastPublished: PetSnapshot?
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private var sourceURL: URL?

    func start() {
        guard sourceURL == nil,
              let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        sourceURL = documents.appendingPathComponent("pet.json")
        let descriptor = open(documents.path, O_EVTONLY)
        if descriptor >= 0 {
            let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename], queue: .main)
            source.setEventHandler { [weak self] in self?.schedulePublish() }
            source.setCancelHandler { close(descriptor) }
            watcher = source
            source.resume()
        }
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            self?.publish()
        })
        observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in
            self?.flushInBackground()
        })
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            if UIApplication.shared.applicationState == .active { self?.publish() }
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
        finishBackgroundTask()
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "Pet widget snapshot") { [weak self] in
            self?.finishBackgroundTask()
        }
        publish()
        // The engine's pause notification may commit after the UIKit observer.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.publish()
            self?.finishBackgroundTask()
        }
    }

    private func publish() {
        guard let sourceURL,
              let size = try? sourceURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 1_048_576,
              let data = try? Data(contentsOf: sourceURL),
              let snapshot = PetSnapshot.fromGameSave(data), snapshot != lastPublished else { return }
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
