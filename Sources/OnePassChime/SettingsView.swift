import AppKit
import SwiftUI
import UniformTypeIdentifiers
import ChimeCore

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var updates: UpdateChecker
    var preview: () -> Void
    @State private var launchAtLogin = false
    @State private var systemSounds: [String] = []

    private var s: Strings { settings.strings }

    var body: some View {
        Form {
            Section(s[.sound]) {
                HStack {
                    Picker(s[.sound], selection: $settings.sound) {
                        Text(s[.builtInChime]).tag(SoundChoice.builtIn)
                        if case .file(let path) = settings.sound {
                            Text(URL(fileURLWithPath: path).lastPathComponent).tag(settings.sound)
                        }
                        Divider()
                        ForEach(systemSounds, id: \.self) { name in
                            Text(name).tag(SoundChoice.system(name))
                        }
                    }
                    Button { preview() } label: { Image(systemName: "play.fill") }
                        .help(s[.playSound])
                }
                HStack {
                    Spacer()
                    Button(s[.chooseFile]) { chooseFile() }
                }
                if !SoundPlayer.canPlay(settings.sound) {
                    Text(s[.fileUnavailable]).font(.caption).foregroundStyle(.orange)
                }
                HStack {
                    Text(s[.volume])
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $settings.volume, in: 0...1) { editing in
                        if !editing { preview() }
                    }
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
                Picker(s[.whenRequestAppears], selection: $settings.playMode) {
                    Text(s[.repeatUntilApproved]).tag(PlayMode.repeatUntilDismissed)
                    Text(s[.playOnce]).tag(PlayMode.once)
                }
                if settings.playMode == .repeatUntilDismissed {
                    Picker(s[.repeatEvery], selection: $settings.interval) {
                        ForEach(AlertPolicy.intervals, id: \.self) { v in
                            Text(s.seconds(v)).tag(v)
                        }
                    }
                }
            }

            Section(s[.general]) {
                Picker(s[.language], selection: $settings.language) {
                    Text(s[.automatic]).tag(LanguageSetting.automatic)
                    ForEach(LanguageCatalog.main.languages) { lang in
                        Text(lang.nativeName).tag(LanguageSetting.fixed(lang.code))
                    }
                }
                Toggle(s[.launchAtLogin], isOn: Binding(
                    get: { launchAtLogin },
                    set: { settings.launchAtLogin = $0; launchAtLogin = settings.launchAtLogin }))
                if settings.launchAtLoginNeedsApproval {
                    Text(s[.launchAtLoginNeedsApproval]).font(.caption).foregroundStyle(.secondary)
                }
            }

            Section {
                updateRow
            } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(s[.howItWorks])
                    Text(s[.unofficial])
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            Section {
                HStack {
                    Spacer()
                    Button(s[.quit]) { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            launchAtLogin = settings.launchAtLogin
            systemSounds = SystemSounds.names()
        }
    }

    @ViewBuilder private var updateRow: some View {
        if updates.updateAvailable, let v = updates.latest {
            HStack {
                Label(s.updateAvailable(v.description), systemImage: "arrow.down.circle")
                Spacer()
                if updates.installState == .installing {
                    Text(s[.updating]).foregroundStyle(.secondary)
                } else {
                    Button(s[.updateNow]) { updates.installUpdate() }
                }
            }
            if updates.installState == .failed {
                Text(s[.updateFailed]).font(.caption).foregroundStyle(.orange)
            }
        } else {
            HStack {
                Text("\(s[.version]) \(AppInfo.version)")
                Spacer()
                if updates.checking {
                    Text(s[.checkingForUpdates]).foregroundStyle(.secondary)
                } else {
                    if updates.lastChecked != nil, !updates.checkFailed {
                        Text(s[.upToDate]).foregroundStyle(.secondary)
                    }
                    Button(s[.checkForUpdates]) { Task { await updates.check() } }
                }
            }
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.sound = .file(url.path)
        preview()
    }
}
