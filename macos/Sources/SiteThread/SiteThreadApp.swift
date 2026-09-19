import AppKit

/// UniFi SiteThread runs as a menu bar accessory: no dock icon, no main window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusItemController()
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        true
    }
}

/// The entry point lives in a `@main` type rather than `main.swift` so that it
/// is main-actor isolated: the delegate and the status item controller are
/// both `@MainActor`, and top-level code is not.
@main
@MainActor
enum SiteThreadApp {
    /// `NSApplication.delegate` is a weak reference, so the delegate needs an
    /// owner that outlives `run()`.
    private static let delegate = AppDelegate()

    static func main() {
        let application = NSApplication.shared
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
