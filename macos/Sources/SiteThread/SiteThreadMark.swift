import AppKit

/// The app's hub-and-spoke mark, drawn rather than loaded so it stays sharp at
/// any menu bar size and needs no asset plumbing.
///
/// This is our own mark, not Ubiquiti's logo — the app is a third-party client
/// and must not present itself as an official UniFi product.
enum SiteThreadMark {

    /// Fixed bar colours, deliberately independent of the menu bar appearance,
    /// so fleet health reads the same on a light and a dark bar. These match
    /// the panel's `Palette`.
    enum BarColor {
        static let brand = NSColor(srgbRed: 0.18, green: 0.61, blue: 1.00, alpha: 1)
        static let urgent = NSColor(srgbRed: 1.00, green: 0.30, blue: 0.35, alpha: 1)
        static let backup = NSColor(srgbRed: 0.93, green: 0.74, blue: 0.16, alpha: 1)
    }

    /// The mark at `size`, drawn in `color`.
    ///
    /// Passing `nil` produces a template image, which macOS tints black on a
    /// light bar and white on a dark one. That is the platform convention, but
    /// it throws away the health signal, so the app only uses it when the user
    /// asks for a monochrome bar icon.
    static func statusImage(size: CGFloat = 16, color: NSColor? = nil) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let orbit = rect.width * 0.30
            let hubRadius = rect.width * 0.16
            let siteRadius = rect.width * 0.105
            let threadWidth = rect.width * 0.085

            // A template image carries only coverage, so black is simply an
            // opaque ink there; an explicit colour is used as given.
            let ink = color ?? NSColor.black
            ink.setFill()
            ink.setStroke()

            // One site at the top, two below — the same arrangement as the
            // app icon.
            let sites: [CGPoint] = [90.0, -30.0, 210.0].map { degrees in
                let radians = degrees * .pi / 180
                return CGPoint(
                    x: center.x + orbit * cos(radians),
                    y: center.y + orbit * sin(radians)
                )
            }

            let threads = NSBezierPath()
            threads.lineWidth = threadWidth
            threads.lineCapStyle = .round
            for site in sites {
                threads.move(to: center)
                threads.line(to: site)
            }
            threads.stroke()

            for site in sites {
                NSBezierPath(ovalIn: NSRect(
                    x: site.x - siteRadius, y: site.y - siteRadius,
                    width: siteRadius * 2, height: siteRadius * 2
                )).fill()
            }

            NSBezierPath(ovalIn: NSRect(
                x: center.x - hubRadius, y: center.y - hubRadius,
                width: hubRadius * 2, height: hubRadius * 2
            )).fill()

            return true
        }
        image.isTemplate = color == nil
        return image
    }

    /// An alert glyph in a fixed colour.
    ///
    /// The colour is baked into the bitmap rather than applied through
    /// `contentTintColor`, which the menu bar does not reliably honour for a
    /// status item.
    static func alertImage(symbol: String, color: NSColor, size: CGFloat = 16) -> NSImage? {
        guard let symbolImage = NSImage(
            systemSymbolName: symbol, accessibilityDescription: "UniFi SiteThread"
        ) else {
            return nil
        }
        symbolImage.isTemplate = true

        let target = NSSize(width: size, height: size)
        let tinted = NSImage(size: target, flipped: false) { rect in
            symbolImage.draw(in: rect)
            color.set()
            rect.fill(using: .sourceAtop)
            return true
        }
        tinted.isTemplate = false
        return tinted
    }
}
