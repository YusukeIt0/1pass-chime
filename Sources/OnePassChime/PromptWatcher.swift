import AppKit
import ChimeCore

/// Looks at the on-screen window list twice a second for 1Password approval prompts.
/// Uses only what macOS shares without any permission: owner, level and size of each window.
@MainActor
final class PromptWatcher {
    struct Observation: Equatable {
        var onePasswordRunning: Bool
        var promptIDs: Set<Int>
    }

    var onObserve: ((Observation) -> Void)?
    private var timer: Timer?
    static let interval: TimeInterval = 0.5

    func start() {
        let t = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.poll() }
        }
        t.tolerance = 0.1
        RunLoop.main.add(t, forMode: .common)
        timer = t
        poll()
    }

    func poll() {
        onObserve?(Self.observe())
    }

    static func observe() -> Observation {
        let apps = NSRunningApplication.runningApplications(withBundleIdentifier: PromptDetector.bundleID)
        guard !apps.isEmpty else { return Observation(onePasswordRunning: false, promptIDs: []) }
        let pids = Set(apps.map { Int($0.processIdentifier) })
        let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        let windows = list.compactMap { entry in
            WindowInfo(windowList: entry) { pids.contains($0) ? PromptDetector.bundleID : nil }
        }
        return Observation(onePasswordRunning: true, promptIDs: PromptDetector.promptIDs(windows))
    }
}
