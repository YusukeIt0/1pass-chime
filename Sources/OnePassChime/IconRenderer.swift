import AppKit
import ChimeCore

/// Menu bar images: a template (follows the menu bar's light/dark look) and a red one for
/// while a request is waiting.
enum IconRenderer {
    static let size = NSSize(width: 18, height: 18)

    static func image(waiting: Bool) -> NSImage {
        let img = NSImage(size: size, flipped: false) { rect in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            let color: NSColor = waiting ? .systemRed : .black
            ChimeGlyph.draw(in: ctx, rect: rect, color: color.cgColor)
            return true
        }
        img.isTemplate = !waiting
        return img
    }

    /// The app icon: the mark in white on a deep blue rounded square (macOS icon grid).
    static func appIconPNG(pixels: Int = 1024) -> Data? {
        let s = CGFloat(pixels)
        guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                         samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                         bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return nil }
        let k = s / 1024
        let body = CGRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
        let shape = NSBezierPath(roundedRect: body, xRadius: 185 * k, yRadius: 185 * k)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10 * k), blur: 28 * k, color: NSColor.black.withAlphaComponent(0.28).cgColor)
        color(0x1F3A8A).setFill()
        shape.fill()
        ctx.restoreGState()

        ctx.saveGState()
        shape.addClip()
        NSGradient(colors: [color(0x4F7BF0), color(0x2448B8), color(0x16297A)], atLocations: [0, 0.55, 1],
                   colorSpace: .sRGB)!.draw(in: body, angle: -90)
        ctx.restoreGState()

        let mark = CGRect(x: 262 * k, y: 250 * k, width: 500 * k, height: 500 * k)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -6 * k), blur: 16 * k, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        ChimeGlyph.draw(in: ctx, rect: mark, color: NSColor.white.cgColor)
        ctx.restoreGState()
        return rep.representation(using: .png, properties: [:])
    }

    private static func color(_ hex: UInt32) -> NSColor {
        NSColor(srgbRed: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}
