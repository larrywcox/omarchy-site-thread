import AppKit
import Combine
import SiteThreadCore
import SwiftUI

/// Owns the menu bar item and the popover that replaces the Omarchy bar widget.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let state = AppState()
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellable: AnyCancellable?

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        let root = ScrollingPanel(state: state)
        let controller = NSHostingController(rootView: root)
        popover.contentViewController = controller
        popover.behavior = .transient
        popover.delegate = self
        popover.contentSize = NSSize(width: state.panelWidth, height: 620)

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageLeading
        }

        cancellable = state.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateStatusItem() }
        }

        state.start()
        updateStatusItem()
    }

    // MARK: Bar presentation

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        let severity = state.barSeverity
        // Colours are fixed rather than left to the menu bar's own tinting, so
        // an outage looks the same on a light and a dark bar. Set
        // `monochromeBarIcon` to opt into the platform's template behaviour.
        let monochrome = UserDefaults.standard.bool(forKey: "monochromeBarIcon")

        switch severity {
        case .critical, .warning:
            // An alert glyph replaces the mark, the way the Omarchy panel
            // swaps its bar icon when a site needs attention.
            let color = severity == .critical
                ? SiteThreadMark.BarColor.urgent
                : SiteThreadMark.BarColor.backup
            button.image = SiteThreadMark.alertImage(
                symbol: Palette.symbol(for: severity),
                color: monochrome ? NSColor.black : color,
                // Only the outage glyph gets a plate; amber on white would be
                // less legible than amber on either bar.
                plate: (monochrome || severity != .critical) ? nil : NSColor.white
            )
            if monochrome { button.image?.isTemplate = true }
        case .healthy:
            button.image = SiteThreadMark.statusImage(
                color: monochrome ? nil : SiteThreadMark.BarColor.brand
            )
        case .disconnected:
            // Nothing to report yet, so the mark stays neutral and dimmed.
            button.image = SiteThreadMark.statusImage()
        }
        button.contentTintColor = nil
        button.appearsDisabled = severity == .disconnected

        let count = state.alertCount
        if count > 0 {
            button.attributedTitle = NSAttributedString(
                string: " \(count)",
                attributes: [
                    .foregroundColor: NSColor.systemRed,
                    .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                ]
            )
        } else {
            button.attributedTitle = NSAttributedString(string: "")
        }

        button.toolTip = state.connected
            ? "UniFi SiteThread · \(state.summary.message)"
            : "UniFi SiteThread · Connect"
    }

    // MARK: Interaction

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let rightClick = NSApp.currentEvent?.type == .rightMouseUp
        if rightClick {
            showMenu()
        } else {
            togglePopover(sender)
        }
    }

    private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        popover.contentSize = NSSize(width: state.panelWidth, height: 620)
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        state.panelOpened()
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(
            withTitle: "Refresh", action: #selector(refreshNow), keyEquivalent: "r"
        ).target = self
        menu.addItem(
            withTitle: "Open unifi.ui.com", action: #selector(openAccount), keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit UniFi SiteThread", action: #selector(quit), keyEquivalent: "q"
        ).target = self

        guard let button = statusItem.button else { return }
        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 4),
            in: button
        )
    }

    @objc private func refreshNow() {
        Task { await state.reload() }
    }

    @objc private func openAccount() {
        state.openAccount()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: NSPopoverDelegate

    nonisolated func popoverDidClose(_ notification: Notification) {
        Task { @MainActor in state.panelClosed() }
    }
}

/// Keeps the popover a fixed height and scrolls long fleets, the way the
/// Quickshell panel flicks its content.
private struct ScrollingPanel: View {
    @ObservedObject var state: AppState

    var body: some View {
        ScrollView(.vertical) {
            PanelView(state: state)
        }
        .frame(width: state.panelWidth, height: 620)
    }
}
