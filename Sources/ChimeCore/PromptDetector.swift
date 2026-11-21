import CoreGraphics
import Foundation

/// One on-screen window, as reported by the window server.
public struct WindowInfo: Equatable, Sendable {
    public var number: Int
    public var ownerPID: Int
    /// Bundle identifier of the owning app, when known.
    public var bundleID: String?
    public var layer: Int
    /// Nil when macOS hides window titles from this app (no Screen Recording permission).
    public var title: String?
    public var width: Double
    public var height: Double
    public var alpha: Double

    public init(number: Int, ownerPID: Int, bundleID: String?, layer: Int, title: String?,
                width: Double, height: Double, alpha: Double = 1) {
        self.number = number
        self.ownerPID = ownerPID
        self.bundleID = bundleID
        self.layer = layer
        self.title = title
        self.width = width
        self.height = height
        self.alpha = alpha
    }

    /// Reads one entry of `CGWindowListCopyWindowInfo`. `bundleID` maps an owner PID to its app.
    public init?(windowList entry: [String: Any], bundleID: (Int) -> String?) {
        guard let number = entry[kCGWindowNumber as String] as? Int,
              let pid = entry[kCGWindowOwnerPID as String] as? Int else { return nil }
        let bounds = entry[kCGWindowBounds as String] as? [String: Any] ?? [:]
        func num(_ key: String) -> Double { (bounds[key] as? NSNumber)?.doubleValue ?? 0 }
        let title = (entry[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 }
        self.init(number: number, ownerPID: pid, bundleID: bundleID(pid),
                  layer: entry[kCGWindowLayer as String] as? Int ?? 0, title: title,
                  width: num("Width"), height: num("Height"),
                  alpha: (entry[kCGWindowAlpha as String] as? NSNumber)?.doubleValue ?? 1)
    }
}

/// Decides which windows look like 1Password asking for approval (SSH key use, CLI sign-in, …).
///
/// Observed with 1Password 8.12 on macOS 27: the approval window is a 1Password window on the
/// pop-up level (101), 400 pt wide, titled "1Password". The main window is on the normal level
/// (0). Quick Access is on level 101 too but 550 pt wide and titled "Quick Access — 1Password"
/// (localized). The menu bar panel is also on level 101 and nearly the same size (405 × 291)
/// with an empty title; `ClickAttribution` sets it aside because it opens on a menu bar click.
/// Titles are only visible with Screen Recording permission, which this app doesn't ask for,
/// so the size decides when there is no title.
public enum PromptDetector {
    public static let bundleID = "com.1password.1password"
    public static let promptLevel = 101
    public static let promptTitle = "1Password"
    static let widthRange = 360.0...460.0
    static let minHeight = 200.0

    public static func isApprovalPrompt(_ w: WindowInfo) -> Bool {
        guard w.bundleID == bundleID, w.layer == promptLevel, w.alpha > 0 else { return false }
        if let title = w.title { return title == promptTitle }
        return widthRange.contains(w.width) && w.height >= minHeight
    }

    /// Window numbers of the approval prompts on screen.
    public static func promptIDs(_ windows: [WindowInfo]) -> Set<Int> {
        Set(windows.filter(isApprovalPrompt).map(\.number))
    }
}
