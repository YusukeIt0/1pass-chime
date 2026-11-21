import AVFoundation
import ChimeCore

/// Plays the chosen sound. Falls back to the built-in chime when the choice can't be played.
@MainActor
final class SoundPlayer {
    private var player: AVAudioPlayer?
    private var loaded: SoundChoice?
    private lazy var builtInData = ChimeSynth.wavData()

    var isPlaying: Bool { player?.isPlaying == true }

    /// Starts the sound unless it is still playing. Returns true when it started.
    @discardableResult
    func play(_ choice: SoundChoice, volume: Double) -> Bool {
        if isPlaying { return false }
        if loaded != choice || player == nil {
            player = Self.makePlayer(choice) ?? (try? AVAudioPlayer(data: builtInData))
            loaded = choice
        }
        guard let player else { return false }
        player.volume = Float(max(0, min(1, volume)))
        player.currentTime = 0
        return player.play()
    }

    /// Plays from the start even if it is already playing (for the preview button).
    func preview(_ choice: SoundChoice, volume: Double) {
        stop()
        play(choice, volume: volume)
    }

    func stop() {
        player?.stop()
    }

    /// True when the choice can be loaded (the built-in chime always can).
    static func canPlay(_ choice: SoundChoice) -> Bool {
        choice == .builtIn || makePlayer(choice) != nil
    }

    private static func makePlayer(_ choice: SoundChoice) -> AVAudioPlayer? {
        switch choice {
        case .builtIn:
            return try? AVAudioPlayer(data: ChimeSynth.wavData())
        case .system(let name):
            return SystemSounds.url(named: name).flatMap { try? AVAudioPlayer(contentsOf: $0) }
        case .file(let path):
            return try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path))
        }
    }
}
