import Foundation

/// The built-in sound: a short two-note chime (B5 → E6), made in code so it is the app's own.
/// Each note is a soft bell: a few partials with an exponential decay and a 4 ms attack.
public enum ChimeSynth {
    public static let sampleRate = 44_100
    public static let duration = 1.25

    struct Note { var frequency: Double; var start: Double; var gain: Double }
    /// (frequency ratio, level, decay time constant in seconds)
    static let partials: [(Double, Double, Double)] = [(1, 1, 0.42), (2, 0.32, 0.22), (3, 0.12, 0.14), (4.2, 0.05, 0.09)]
    static let notes = [Note(frequency: 987.77, start: 0, gain: 0.85), Note(frequency: 1318.51, start: 0.17, gain: 1)]

    /// Mono samples in -1...1, peak normalized to 0.8.
    public static func samples() -> [Float] {
        let count = Int(duration * Double(sampleRate))
        var out = [Double](repeating: 0, count: count)
        let attack = 0.004
        for note in notes {
            let first = Int(note.start * Double(sampleRate))
            for i in first..<count {
                let t = Double(i - first) / Double(sampleRate)
                let env = min(1, t / attack)
                var v = 0.0
                for (ratio, level, tau) in partials {
                    v += level * exp(-t / tau) * sin(2 * .pi * note.frequency * ratio * t)
                }
                out[i] += note.gain * env * v
            }
        }
        // Fade the last 30 ms to silence so the file never ends on a click.
        let fade = Int(0.03 * Double(sampleRate))
        for i in 0..<fade { out[count - 1 - i] *= Double(i) / Double(fade) }
        let peak = out.map(abs).max() ?? 1
        return out.map { Float($0 / peak * 0.8) }
    }

    /// 16-bit PCM mono WAV.
    public static func wavData() -> Data {
        let pcm = samples().map { Int16(max(-1, min(1, $0)) * Float(Int16.max)) }
        var d = Data()
        func u32(_ v: UInt32) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        func u16(_ v: UInt16) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        let dataBytes = UInt32(pcm.count * 2)
        d.append(contentsOf: Array("RIFF".utf8)); u32(36 + dataBytes)
        d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); u32(16); u16(1); u16(1)
        u32(UInt32(sampleRate)); u32(UInt32(sampleRate * 2)); u16(2); u16(16)
        d.append(contentsOf: Array("data".utf8)); u32(dataBytes)
        for s in pcm { u16(UInt16(bitPattern: s)) }
        return d
    }
}
