import AppKit
import ChimeCore

/// `--render-icons <dir>`: the app icon (1024 px) and menu bar images at 2x.
@MainActor
enum IconExport {
    static func run(outputDir: String) -> Int32 {
        let dir = URL(fileURLWithPath: outputDir, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        guard let icon = IconRenderer.appIconPNG() else { return 1 }
        do {
            try icon.write(to: dir.appendingPathComponent("AppIcon-1024.png"))
            for (name, waiting) in [("menubar", false), ("menubar-waiting", true)] {
                let img = IconRenderer.image(waiting: waiting)
                let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 36, pixelsHigh: 36, bitsPerSample: 8,
                                           samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                           bytesPerRow: 0, bitsPerPixel: 0)!
                rep.size = IconRenderer.size
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                img.draw(in: NSRect(origin: .zero, size: IconRenderer.size))
                NSGraphicsContext.restoreGraphicsState()
                try rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
            }
        } catch {
            print("could not write: \(error)")
            return 1
        }
        print("wrote icons to \(dir.path)")
        return 0
    }
}

/// `--watch [seconds]`: prints each change in what the watcher sees. Run from a terminal, the
/// app gets the terminal's permissions (window titles may be visible); the app itself has none.
@MainActor
enum WatchCheck {
    static func run(seconds: Double) {
        var last: PromptWatcher.Observation?
        let end = Date().addingTimeInterval(seconds)
        print("watching for \(Int(seconds)) s…")
        while Date() < end {
            let obs = PromptWatcher.observe()
            if obs != last {
                print("\(ISO8601DateFormatter().string(from: Date())) 1Password running: \(obs.onePasswordRunning), prompts: \(obs.promptIDs.sorted())")
                last = obs
            }
            Thread.sleep(forTimeInterval: PromptWatcher.interval)
        }
    }
}
