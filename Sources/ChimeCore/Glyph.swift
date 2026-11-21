import CoreGraphics

/// The app's mark: an eighth note that is also a key. The note head is the key's bow (with a
/// hole for a key ring), the stem is the shaft, and two teeth sit on the stem below the flag.
/// Drawn in one color so it works as a menu bar template image.
public enum ChimeGlyph {
    /// Design box, in points.
    public static let designSize = CGSize(width: 18, height: 18)

    /// Draws the mark filling `rect` (aspect kept, centered) in `color`.
    public static func draw(in ctx: CGContext, rect: CGRect, color: CGColor) {
        let scale = min(rect.width / designSize.width, rect.height / designSize.height)
        ctx.saveGState()
        ctx.translateBy(x: rect.midX - designSize.width * scale / 2, y: rect.midY - designSize.height * scale / 2)
        ctx.scaleBy(x: scale, y: scale)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.setFillColor(color)

        // Note head = key bow: a tilted oval.
        ctx.saveGState()
        ctx.translateBy(x: head.x, y: head.y)
        ctx.rotate(by: -0.38)
        ctx.fillEllipse(in: CGRect(x: -4.6, y: -3.4, width: 9.2, height: 6.8))
        ctx.restoreGState()

        // Stem = shaft, rising from the right side of the head.
        ctx.fill(CGRect(x: stemX, y: stemBottom, width: stemWidth, height: stemTop - stemBottom))

        // Teeth on the left of the stem (overlapping it, so no seam shows).
        ctx.fill(CGRect(x: stemX - 2.4, y: 9.6, width: 2.4 + overlap, height: 1.5))
        ctx.fill(CGRect(x: stemX - 1.7, y: 12.0, width: 1.7 + overlap, height: 1.5))

        // Flag.
        let flag = CGMutablePath()
        flag.move(to: CGPoint(x: stemX + stemWidth - 0.1, y: stemTop))
        flag.addCurve(to: CGPoint(x: stemX + stemWidth + 3.6, y: 9.8),
                      control1: CGPoint(x: stemX + stemWidth + 0.6, y: stemTop - 2.6),
                      control2: CGPoint(x: stemX + stemWidth + 5.2, y: 13.4))
        flag.addCurve(to: CGPoint(x: stemX + stemWidth - 0.1, y: stemTop - 3.4),
                      control1: CGPoint(x: stemX + stemWidth + 3.4, y: 12.4),
                      control2: CGPoint(x: stemX + stemWidth + 0.8, y: stemTop - 3.6))
        flag.closeSubpath()
        ctx.addPath(flag)
        ctx.fillPath()

        // Key-ring hole through the head.
        ctx.setBlendMode(.destinationOut)
        ctx.fillEllipse(in: CGRect(x: head.x - 1.45, y: head.y - 1.45, width: 2.9, height: 2.9))

        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    static let head = CGPoint(x: 7.2, y: 4.6)
    static let stemX = 9.7
    /// Starts inside the head so its corner never sticks out below the oval.
    static let stemBottom = 4.0
    static let overlap = 0.8
    static let stemWidth = 1.7
    static let stemTop = 16.9
}
