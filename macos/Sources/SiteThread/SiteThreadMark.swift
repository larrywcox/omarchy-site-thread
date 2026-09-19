import AppKit

/// The app's hub-and-spoke mark, drawn rather than loaded so it stays sharp at
/// any menu bar size and needs no asset plumbing.
///
/// This is our own mark, not Ubiquiti's logo — the app is a third-party client
/// and must not present itself as an official UniFi product.
enum SiteThreadMark {

    /// A template image: macOS tints it for the light and dark menu bar, and
    /// inverts it when the item is highlighted.
    static func statusImage(size: CGFloat = 16) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let orbit = rect.width * 0.30
            let hubRadius = rect.width * 0.16
            let siteRadius = rect.width * 0.105
            let threadWidth = rect.width * 0.085

            // A template image carries only coverage, so the colour is
            // irrelevant beyond being fully opaque.
            NSColor.black.setFill()
            NSColor.black.setStroke()

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
        image.isTemplate = true
        return image
    }
}
