import Foundation
import ServiceManagement
import ChimeCore

enum AppInfo {
    static let name = "1PassChime"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
}

/// User preferences, stored in UserDefaults so they survive updates and restarts.
@MainActor
final class AppSettings: ObservableObject {
    private let defaults: UserDefaults

    @Published var sound: SoundChoice { didSet { save() } }
    @Published var volume: Double { didSet { save() } }
    @Published var playMode: PlayMode { didSet { save() } }
    @Published var interval: TimeInterval { didSet { save() } }
    @Published var paused: Bool { didSet { save() } }
    @Published var language: LanguageSetting { didSet { save() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        sound = SoundChoice(storedValue: defaults.string(forKey: "sound") ?? "")
        volume = defaults.object(forKey: "volume") as? Double ?? 1
        playMode = PlayMode(rawValue: defaults.string(forKey: "playMode") ?? "") ?? .repeatUntilDismissed
        let stored = defaults.double(forKey: "interval")
        interval = AlertPolicy.intervals.contains(stored) ? stored : AlertPolicy.defaultInterval
        paused = defaults.bool(forKey: "paused")
        language = LanguageSetting(storedValue: defaults.string(forKey: "language") ?? "")
    }

    var policy: AlertPolicy { AlertPolicy(mode: playMode, interval: interval) }
    var appLanguage: AppLanguage { LanguageCatalog.main.resolve(language) }
    var strings: Strings { Strings(appLanguage) }

    private func save() {
        defaults.set(sound.storedValue, forKey: "sound")
        defaults.set(volume, forKey: "volume")
        defaults.set(playMode.rawValue, forKey: "playMode")
        defaults.set(interval, forKey: "interval")
        defaults.set(paused, forKey: "paused")
        defaults.set(language.storedValue, forKey: "language")
    }

    // MARK: Launch at login

    /// Turned on once at first launch: the app only helps while it is running.
    func setUpLoginItemOnFirstLaunch() {
        guard !defaults.bool(forKey: "loginItemSetUp") else { return }
        defaults.set(true, forKey: "loginItemSetUp")
        launchAtLogin = true
    }

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            objectWillChange.send()
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                NSLog("1PassChime: login item change failed: \(error.localizedDescription)")
            }
        }
    }

    var launchAtLoginNeedsApproval: Bool { SMAppService.mainApp.status == .requiresApproval }
}
