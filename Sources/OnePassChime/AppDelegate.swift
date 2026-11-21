import AppKit
import Combine
import SwiftUI
import ChimeCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    let settings = AppSettings()
    let updates = UpdateChecker()
    private let watcher = PromptWatcher()
    private let player = SoundPlayer()
    private var alert = AlertState()
    private var clicks = ClickAttribution()
    private var clickMonitor: Any?
    private var observation = PromptWatcher.Observation(onePasswordRunning: false, promptIDs: [])
    private var statusItem: NSStatusItem!
    private var shownWaiting: Bool?
    private var settingsWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []
    private let eventLog = ProcessInfo.processInfo.environment["ONEPASSCHIME_EVENT_LOG"]

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.autosaveName = "1passchime"
        statusItem.behavior = []
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateIcon()

        settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateIcon() }
            .store(in: &cancellables)

        // Mouse clicks elsewhere can be observed without any permission (keys can't, and aren't).
        // Only whether a click hit a menu bar is used, to recognise 1Password's own menu bar panel.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.mouseDown() }
        }
        watcher.onObserve = { [weak self] in self?.handle($0) }
        watcher.start()
        updates.start()
        // Test runs of a build folder set this so the build isn't added to Login Items.
        if ProcessInfo.processInfo.environment["ONEPASSCHIME_NO_LOGIN_ITEM"] == nil {
            settings.setUpLoginItemOnFirstLaunch()
        }
    }

    // MARK: Prompts

    private func mouseDown() {
        let screens = NSScreen.screens.map { (frame: $0.frame, visible: $0.visibleFrame) }
        guard MenuBarHit.isInMenuBar(NSEvent.mouseLocation, screens: screens) else { return }
        clicks.menuBarClicked(at: Date())
        log("menu bar click")
    }

    private func handle(_ obs: PromptWatcher.Observation) {
        let now = Date()
        let wasVisible = alert.isPromptVisible
        let prompts = clicks.prompts(from: obs.promptIDs, now: now)
        let due = alert.update(prompts: prompts, now: now, policy: settings.policy)
        if obs != observation {
            log("observed running=\(obs.onePasswordRunning) windows=\(obs.promptIDs.sorted()) prompts=\(prompts.sorted())")
        }
        observation = obs
        if due, !settings.paused, player.play(settings.sound, volume: settings.volume) {
            alert.markPlayed(now)
            log("played")
        }
        if wasVisible, !alert.isPromptVisible { player.stop() }
        updateIcon()
    }

    private func updateIcon() {
        guard let button = statusItem?.button else { return }
        let waiting = alert.isPromptVisible
        if shownWaiting != waiting {
            button.image = IconRenderer.image(waiting: waiting)
            shownWaiting = waiting
        }
        if button.appearsDisabled != settings.paused { button.appearsDisabled = settings.paused }
        let tip = statusText
        if button.toolTip != tip { button.toolTip = tip }
    }

    private var statusText: String {
        let s = settings.strings
        if alert.isPromptVisible { return s[.statusWaiting] }
        if settings.paused { return s[.statusPaused] }
        return observation.onePasswordRunning ? s[.statusWatching] : s[.statusNotRunning]
    }

    private func log(_ line: String) {
        guard let eventLog, let h = FileHandle(forWritingAtPath: eventLog) ?? {
            FileManager.default.createFile(atPath: eventLog, contents: nil)
            return FileHandle(forWritingAtPath: eventLog)
        }() else { return }
        h.seekToEndOfFile()
        h.write(Data("\(ISO8601DateFormatter().string(from: Date())) \(line)\n".utf8))
        try? h.close()
    }

    // MARK: Menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        let s = settings.strings
        menu.removeAllItems()
        let status = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        if alert.isPromptVisible, !alert.silenced, !settings.paused {
            menu.addItem(item(s[.silenceThisRequest], #selector(silence)))
        }
        menu.addItem(.separator())
        menu.addItem(item(s[.playSound], #selector(playSound)))
        menu.addItem(item(settings.paused ? s[.resumeSounds] : s[.pauseSounds], #selector(togglePause)))
        menu.addItem(.separator())
        if updates.updateAvailable, let v = updates.latest {
            menu.addItem(item(s.updateAvailable(v.description) + "…", #selector(installUpdate)))
        }
        menu.addItem(item(s[.settings], #selector(openSettings), key: ","))
        menu.addItem(item(s[.quit], #selector(quit), key: "q"))
    }

    private func item(_ title: String, _ action: Selector, key: String = "") -> NSMenuItem {
        let i = NSMenuItem(title: title, action: action, keyEquivalent: key)
        i.target = self
        return i
    }

    @objc private func silence() {
        alert.silence()
        player.stop()
    }

    @objc private func playSound() { player.preview(settings.sound, volume: settings.volume) }

    @objc private func togglePause() {
        settings.paused.toggle()
        if settings.paused { player.stop() }
    }

    @objc private func installUpdate() { updates.installUpdate() }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: Settings window

    @objc func openSettings() {
        if settingsWindow == nil {
            let view = SettingsView(settings: settings, updates: updates,
                                    preview: { [weak self] in
                                        guard let self else { return }
                                        self.player.preview(self.settings.sound, volume: self.settings.volume)
                                    })
            let w = NSWindow(contentViewController: NSHostingController(rootView: view))
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            settingsWindow = w
            settings.$language
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in self?.updateSettingsTitle() }
                .store(in: &cancellables)
        }
        updateSettingsTitle()
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    private func updateSettingsTitle() {
        let title = settings.strings[.settings].replacingOccurrences(of: "…", with: "")
        settingsWindow?.title = "\(AppInfo.name) – \(title)"
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }
}
