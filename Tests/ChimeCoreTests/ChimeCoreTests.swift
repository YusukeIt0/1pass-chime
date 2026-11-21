import CoreGraphics
import Foundation
import XCTest
@testable import ChimeCore

final class PromptDetectorTests: XCTestCase {
    let op = PromptDetector.bundleID

    func w(_ bundle: String?, layer: Int, title: String?, _ width: Double, _ height: Double, number: Int = 1) -> WindowInfo {
        WindowInfo(number: number, ownerPID: 2770, bundleID: bundle, layer: layer, title: title, width: width, height: height)
    }

    // Values observed with 1Password 8.12.44 on macOS 27.2.1.
    func testApprovalPromptsAreDetected() {
        XCTAssertTrue(PromptDetector.isApprovalPrompt(w(op, layer: 101, title: "1Password", 400, 371)), "SSH key")
        XCTAssertTrue(PromptDetector.isApprovalPrompt(w(op, layer: 101, title: "1Password", 400, 325)), "op sign-in")
    }

    func testApprovalPromptsAreDetectedWithoutTitles() {
        XCTAssertTrue(PromptDetector.isApprovalPrompt(w(op, layer: 101, title: nil, 400, 371)))
        XCTAssertTrue(PromptDetector.isApprovalPrompt(w(op, layer: 101, title: nil, 400, 325)))
    }

    func testOtherOnePasswordWindowsAreIgnored() {
        // Quick Access (its height grows with results).
        XCTAssertFalse(PromptDetector.isApprovalPrompt(w(op, layer: 101, title: "クイックアクセス — 1Password", 550, 108)))
        XCTAssertFalse(PromptDetector.isApprovalPrompt(w(op, layer: 101, title: nil, 550, 108)))
        XCTAssertFalse(PromptDetector.isApprovalPrompt(w(op, layer: 101, title: nil, 550, 188)))
        XCTAssertFalse(PromptDetector.isApprovalPrompt(w(op, layer: 101, title: nil, 550, 420)))
        // A 1Password window on level 3 (seen once, 416 × 312).
        XCTAssertFalse(PromptDetector.isApprovalPrompt(w(op, layer: 3, title: "1Password", 416, 312)))
        XCTAssertFalse(PromptDetector.isApprovalPrompt(w(op, layer: 3, title: nil, 416, 312)))
        // Main window.
        XCTAssertFalse(PromptDetector.isApprovalPrompt(w(op, layer: 0, title: "1Password", 400, 600)))
        XCTAssertFalse(PromptDetector.isApprovalPrompt(w(op, layer: 0, title: nil, 1000, 700)))
    }

    func testOtherAppsAreIgnored() {
        XCTAssertFalse(PromptDetector.isApprovalPrompt(w("com.google.Chrome", layer: 101, title: "1Password", 400, 371)))
        XCTAssertFalse(PromptDetector.isApprovalPrompt(w(nil, layer: 101, title: nil, 400, 371)))
    }

    func testInvisibleWindowIsIgnored() {
        var x = w(op, layer: 101, title: nil, 400, 371)
        x.alpha = 0
        XCTAssertFalse(PromptDetector.isApprovalPrompt(x))
    }

    func testPromptIDs() {
        let list = [w(op, layer: 101, title: nil, 400, 371, number: 7), w(op, layer: 101, title: nil, 550, 108, number: 8),
                    w(op, layer: 3, title: nil, 416, 312, number: 9)]
        XCTAssertEqual(PromptDetector.promptIDs(list), [7])
    }

    func testReadsWindowListEntry() {
        let entry: [String: Any] = [
            kCGWindowNumber as String: 17670, kCGWindowOwnerPID as String: 2770, kCGWindowLayer as String: 101,
            kCGWindowName as String: "1Password", kCGWindowAlpha as String: 1.0,
            kCGWindowBounds as String: ["X": -740.0, "Y": -284.0, "Width": 400.0, "Height": 371.0],
        ]
        let info = WindowInfo(windowList: entry) { $0 == 2770 ? PromptDetector.bundleID : nil }
        XCTAssertEqual(info, WindowInfo(number: 17670, ownerPID: 2770, bundleID: PromptDetector.bundleID, layer: 101,
                                        title: "1Password", width: 400, height: 371))
        var noTitle = entry
        noTitle[kCGWindowName as String] = ""
        XCTAssertNil(WindowInfo(windowList: noTitle) { _ in nil }?.title, "empty title counts as hidden")
        XCTAssertNil(WindowInfo(windowList: [:]) { _ in nil })
    }
}

final class ClickAttributionTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000)

    func testMenuBarPanelLooksLikeAPromptOnItsOwn() {
        // Observed: the menu bar panel is 405 × 291 on level 101 with no title.
        let panel = WindowInfo(number: 17861, ownerPID: 2770, bundleID: PromptDetector.bundleID, layer: 101,
                               title: nil, width: 405, height: 291)
        XCTAssertTrue(PromptDetector.isApprovalPrompt(panel), "size alone can't tell; ClickAttribution does")
    }

    func testWindowRightAfterMenuBarClickIsIgnoredWhileOpen() {
        var c = ClickAttribution()
        c.menuBarClicked(at: t0)
        XCTAssertEqual(c.prompts(from: [17861], now: t0 + 0.5), [])
        XCTAssertEqual(c.prompts(from: [17861], now: t0 + 5), [], "stays ignored while open")
        XCTAssertEqual(c.prompts(from: [], now: t0 + 6), [])
        XCTAssertEqual(c.ignored, [])
    }

    func testPromptWithoutClickCounts() {
        var c = ClickAttribution()
        XCTAssertEqual(c.prompts(from: [1], now: t0), [1])
    }

    func testPromptLongAfterClickCounts() {
        var c = ClickAttribution()
        c.menuBarClicked(at: t0)
        XCTAssertEqual(c.prompts(from: [1], now: t0 + ClickAttribution.window + 0.1), [1])
    }

    func testPromptAlreadyOnScreenBeforeClickStillCounts() {
        var c = ClickAttribution()
        XCTAssertEqual(c.prompts(from: [1], now: t0), [1])
        c.menuBarClicked(at: t0 + 1)
        XCTAssertEqual(c.prompts(from: [1, 2], now: t0 + 1.4), [1], "only the new window is the user's panel")
    }
}

final class MenuBarHitTests: XCTestCase {
    // The Mac this was built on: built-in display with the menu bar, one display to the left,
    // one above (AppKit coordinates).
    let screens: [(frame: CGRect, visible: CGRect)] = [
        (CGRect(x: 0, y: 0, width: 1728, height: 1117), CGRect(x: 0, y: 0, width: 1728, height: 1080)),
        (CGRect(x: -1080, y: -41, width: 1080, height: 1920), CGRect(x: -1080, y: -41, width: 1080, height: 1895)),
        (CGRect(x: 0, y: 1117, width: 1920, height: 1080), CGRect(x: 0, y: 1117, width: 1920, height: 1055)),
    ]

    func testMenuBars() {
        XCTAssertTrue(MenuBarHit.isInMenuBar(CGPoint(x: 1400, y: 1105), screens: screens))
        XCTAssertTrue(MenuBarHit.isInMenuBar(CGPoint(x: -500, y: 1870), screens: screens))
        XCTAssertTrue(MenuBarHit.isInMenuBar(CGPoint(x: 1800, y: 2190), screens: screens))
    }

    func testElsewhere() {
        XCTAssertFalse(MenuBarHit.isInMenuBar(CGPoint(x: 1400, y: 900), screens: screens))
        XCTAssertFalse(MenuBarHit.isInMenuBar(CGPoint(x: -500, y: 1000), screens: screens))
        XCTAssertFalse(MenuBarHit.isInMenuBar(CGPoint(x: 1800, y: 1500), screens: screens))
    }

    func testHiddenMenuBarUsesMinimumHeight() {
        let s = [(frame: CGRect(x: 0, y: 0, width: 1000, height: 800), visible: CGRect(x: 0, y: 0, width: 1000, height: 800))]
        XCTAssertTrue(MenuBarHit.isInMenuBar(CGPoint(x: 10, y: 790), screens: s))
        XCTAssertFalse(MenuBarHit.isInMenuBar(CGPoint(x: 10, y: 700), screens: s))
    }
}

final class AlertStateTests: XCTestCase {
    let t0 = Date(timeIntervalSince1970: 1_000)
    let repeat3 = AlertPolicy(mode: .repeatUntilDismissed, interval: 3)
    let once = AlertPolicy(mode: .once, interval: 3)

    func testRepeatsUntilPromptCloses() {
        var a = AlertState()
        XCTAssertFalse(a.update(prompts: [], now: t0, policy: repeat3))
        XCTAssertTrue(a.update(prompts: [1], now: t0, policy: repeat3))
        a.markPlayed(t0)
        XCTAssertFalse(a.update(prompts: [1], now: t0 + 2.5, policy: repeat3))
        XCTAssertTrue(a.update(prompts: [1], now: t0 + 3, policy: repeat3))
        a.markPlayed(t0 + 3)
        XCTAssertFalse(a.update(prompts: [], now: t0 + 4, policy: repeat3))
        XCTAssertFalse(a.isPromptVisible)
        XCTAssertNil(a.lastPlayed)
    }

    func testOncePlaysOnlyOnce() {
        var a = AlertState()
        XCTAssertTrue(a.update(prompts: [1], now: t0, policy: once))
        a.markPlayed(t0)
        XCTAssertFalse(a.update(prompts: [1], now: t0 + 60, policy: once))
    }

    func testStaysDueUntilSoundStarts() {
        // The player was busy: nothing was marked as played, so it is still due.
        var a = AlertState()
        XCTAssertTrue(a.update(prompts: [1], now: t0, policy: once))
        XCTAssertTrue(a.update(prompts: [1], now: t0 + 0.5, policy: once))
    }

    func testSilenceLastsUntilANewPrompt() {
        var a = AlertState()
        XCTAssertTrue(a.update(prompts: [1], now: t0, policy: repeat3))
        a.markPlayed(t0)
        a.silence()
        XCTAssertFalse(a.update(prompts: [1], now: t0 + 10, policy: repeat3))
        XCTAssertTrue(a.update(prompts: [1, 2], now: t0 + 11, policy: repeat3), "a second request plays again")
        a.markPlayed(t0 + 11)
        a.silence()
        _ = a.update(prompts: [], now: t0 + 12, policy: repeat3)
        XCTAssertFalse(a.silenced)
        XCTAssertTrue(a.update(prompts: [3], now: t0 + 13, policy: repeat3))
    }

    func testNewPromptReplacingAnotherPlaysAtOnce() {
        var a = AlertState()
        _ = a.update(prompts: [1], now: t0, policy: repeat3)
        a.markPlayed(t0)
        XCTAssertTrue(a.update(prompts: [2], now: t0 + 0.5, policy: repeat3))
    }

    func testSilenceWithoutPromptDoesNothing() {
        var a = AlertState()
        a.silence()
        XCTAssertFalse(a.silenced)
    }
}

final class ChimeSynthTests: XCTestCase {
    func testSamples() {
        let s = ChimeSynth.samples()
        XCTAssertEqual(s.count, Int(ChimeSynth.duration * Double(ChimeSynth.sampleRate)))
        let peak = s.map(abs).max() ?? 0
        XCTAssertEqual(peak, 0.8, accuracy: 0.001)
        XCTAssertLessThan(abs(s.last ?? 1), 0.001, "ends in silence")
        XCTAssertLessThan(abs(s.first ?? 1), 0.01, "starts softly")
    }

    func testWAVHeader() {
        let d = ChimeSynth.wavData()
        XCTAssertEqual(String(decoding: d[0..<4], as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: d[8..<12], as: UTF8.self), "WAVE")
        XCTAssertEqual(String(decoding: d[36..<40], as: UTF8.self), "data")
        XCTAssertEqual(d.count, 44 + ChimeSynth.samples().count * 2)
    }
}

final class SoundChoiceTests: XCTestCase {
    func testStoredValues() {
        for c in [SoundChoice.builtIn, .system("Glass"), .file("/Users/a/b c.wav")] {
            XCTAssertEqual(SoundChoice(storedValue: c.storedValue), c)
        }
        XCTAssertEqual(SoundChoice(storedValue: ""), .builtIn)
        XCTAssertEqual(SoundChoice(storedValue: "system:"), .builtIn)
        XCTAssertEqual(SoundChoice(storedValue: "nonsense"), .builtIn)
    }

    func testSystemSoundsInFolder() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        for f in ["Pop.aiff", "Bell.wav", "notes.txt", "Pop.caf"] {
            FileManager.default.createFile(atPath: dir.appendingPathComponent(f).path, contents: Data())
        }
        XCTAssertEqual(SystemSounds.names(in: [dir]), ["Bell", "Pop"])
        XCTAssertEqual(SystemSounds.url(named: "Bell", in: [dir])?.lastPathComponent, "Bell.wav")
        XCTAssertNil(SystemSounds.url(named: "notes", in: [dir]))
    }
}

final class LanguageTests: XCTestCase {
    var directory: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Languages")
    }

    func testLanguageFilesAreComplete() {
        XCTAssertEqual(LanguageCatalog.problems(directory: directory), [])
    }

    func testResolve() throws {
        let c = try LanguageCatalog.load(directory: directory)
        XCTAssertEqual(c.resolve(.automatic, preferred: ["ja-JP"]).code, "ja")
        XCTAssertEqual(c.resolve(.automatic, preferred: ["xx"]).code, "en")
        XCTAssertEqual(c.resolve(.fixed("ja"), preferred: ["en"]).code, "ja")
        XCTAssertEqual(c.resolve(.fixed("gone"), preferred: ["ja"]).code, "ja")
    }

    func testPlaceholders() throws {
        let c = try LanguageCatalog.load(directory: directory)
        let s = Strings(c.language(code: "en")!)
        XCTAssertEqual(s.seconds(3), "3 s")
        XCTAssertEqual(s.updateAvailable("0.2.0"), "Version 0.2.0 is available")
    }
}

final class VersionTests: XCTestCase {
    func testCompare() {
        XCTAssertLessThan(AppVersion("0.1.9")!, AppVersion("0.1.10")!)
        XCTAssertEqual(AppVersion("v0.2"), AppVersion("0.2.0"))
        XCTAssertNil(AppVersion("0.1.0-beta"))
        XCTAssertTrue(ReleaseInfo.isUpdate(latest: AppVersion("0.2.0"), current: AppVersion("0.1.0")))
        XCTAssertFalse(ReleaseInfo.isUpdate(latest: nil, current: AppVersion("0.1.0")))
        XCTAssertEqual(ReleaseInfo.installerURL(for: AppVersion("0.1.0")!).absoluteString,
                       "https://raw.githubusercontent.com/YusukeIt0/1pass-chime/v0.1.0/install.sh")
    }
}
