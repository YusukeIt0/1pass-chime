import Foundation

/// How often to play while a prompt is waiting.
public enum PlayMode: String, CaseIterable, Sendable {
    case once
    case repeatUntilDismissed = "repeat"
}

public struct AlertPolicy: Equatable, Sendable {
    public var mode: PlayMode
    /// Seconds from one start of the sound to the next, in repeat mode.
    public var interval: TimeInterval

    public init(mode: PlayMode, interval: TimeInterval) {
        self.mode = mode
        self.interval = interval
    }

    public static let intervals: [TimeInterval] = [2, 3, 5, 10, 20]
    public static let defaultInterval: TimeInterval = 3
}

/// Tracks the approval prompts on screen and says when the sound is due.
///
/// A prompt that appears is due at once. In repeat mode it is due again every `interval`
/// until it closes or is silenced. A new prompt (a window not seen before) is due at once
/// and clears an earlier silence. When every prompt closes, the state resets.
public struct AlertState: Equatable, Sendable {
    public private(set) var promptIDs: Set<Int> = []
    public private(set) var lastPlayed: Date?
    public private(set) var silenced = false

    public init() {}

    public var isPromptVisible: Bool { !promptIDs.isEmpty }

    /// Updates the visible prompts and returns whether the sound should start now.
    public mutating func update(prompts ids: Set<Int>, now: Date, policy: AlertPolicy) -> Bool {
        let appeared = !ids.subtracting(promptIDs).isEmpty
        promptIDs = ids
        if ids.isEmpty {
            lastPlayed = nil
            silenced = false
            return false
        }
        if appeared {
            silenced = false
            lastPlayed = nil
        }
        if silenced { return false }
        guard let lastPlayed else { return true }
        return policy.mode == .repeatUntilDismissed && now.timeIntervalSince(lastPlayed) >= policy.interval
    }

    /// Call when the sound actually started.
    public mutating func markPlayed(_ now: Date) { lastPlayed = now }

    /// Stops the sound for the prompts on screen now. A new prompt plays again.
    public mutating func silence() {
        if isPromptVisible { silenced = true }
    }
}
