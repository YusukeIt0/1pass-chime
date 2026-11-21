import Foundation

/// Sets aside 1Password windows that the user opened from the menu bar.
///
/// 1Password's menu bar panel looks like an approval prompt in the window list (pop-up level,
/// about 400 pt wide; observed 405 × 291 against 400 × 325–371). What tells them apart is how
/// they open: the panel right after a click in the menu bar, a prompt on a request from
/// another program. A prompt-like window that appears within `window` seconds after a menu bar
/// click is treated as the user's own and ignored for as long as it stays on screen.
public struct ClickAttribution: Equatable, Sendable {
    public static let window: TimeInterval = 1.5

    public private(set) var lastMenuBarClick: Date?
    public private(set) var ignored: Set<Int> = []
    private var known: Set<Int> = []

    public init() {}

    public mutating func menuBarClicked(at time: Date) {
        lastMenuBarClick = time
    }

    /// The windows that count as approval prompts, out of the prompt-like ones on screen now.
    public mutating func prompts(from ids: Set<Int>, now: Date) -> Set<Int> {
        let appeared = ids.subtracting(known)
        if let click = lastMenuBarClick, now.timeIntervalSince(click) <= Self.window, now >= click {
            ignored.formUnion(appeared)
        }
        known = ids
        ignored.formIntersection(ids)
        return ids.subtracting(ignored)
    }
}

/// Whether a click lands in a menu bar. `screens` are (frame, visibleFrame) pairs in AppKit
/// coordinates; the menu bar is the strip between the top of the visible frame and the top of
/// the screen. When the menu bar hides itself that strip is empty, so a minimum height is used.
public enum MenuBarHit {
    public static let minimumHeight: Double = 40

    public static func isInMenuBar(_ point: CGPoint, screens: [(frame: CGRect, visible: CGRect)]) -> Bool {
        for s in screens where point.x >= s.frame.minX && point.x <= s.frame.maxX {
            let height = max(minimumHeight, s.frame.maxY - s.visible.maxY)
            if point.y <= s.frame.maxY && point.y >= s.frame.maxY - height { return true }
        }
        return false
    }
}
