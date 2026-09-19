import SiteThreadCore
import SwiftUI

struct PanelView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if !state.notice.isEmpty {
                Text(state.notice)
                    .font(.caption)
                    .foregroundColor(noticeIsFailure ? Palette.urgent : Palette.dim)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !state.connected {
                ConnectView(state: state)
            } else if state.inSite {
                SiteDetailView(state: state)
            } else {
                fleet
            }
        }
        .padding(14)
        .frame(width: state.panelWidth)
    }

    private var noticeIsFailure: Bool {
        let text = state.notice.lowercased()
        return text.contains("failed") || text.contains("invalid") || text.contains("could not")
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            if state.inSite {
                Button { state.backToSites() } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .help("Back to all sites")
            }

            Image(systemName: Palette.symbol(for: state.barSeverity))
                .font(.system(size: 18))
                .foregroundColor(Palette.color(for: state.barSeverity))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundColor(Palette.dim)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            if state.loading || state.siteLoading {
                ProgressView().controlSize(.small)
            }

            Button {
                Task { await state.reload() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .help("Refresh")

            if state.connected && !state.inSite {
                Button { state.openConsole() } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .buttonStyle(.plain)
                .help("Open UniFi")
            }
        }
    }

    private var title: String {
        if let site = state.selectedSite {
            return site.name.isEmpty ? "UNIFI SITE" : site.name
        }
        return "UNIFI SITETHREAD"
    }

    private var subtitle: String {
        if let site = state.selectedSite {
            return site.statusText.isEmpty ? "Live site view" : site.statusText
        }
        return state.subtitle
    }

    // MARK: Connected fleet

    private var fleet: some View {
        VStack(alignment: .leading, spacing: 12) {
            TabBar(
                labels: state.cloudMode ? ["Overview", "Sites"] : ["Overview", "Network", "Protect"],
                selection: $state.activeTab,
                onChange: { state.tabChanged() }
            )

            if state.activeTab == 0 {
                OverviewView(state: state)
            } else if state.activeTab == 1 {
                secondTab
            } else {
                protectTab
            }

            Divider()

            HStack(spacing: 10) {
                Text("API key stored in the macOS keychain")
                    .font(.caption2)
                    .foregroundColor(Palette.dim)
                Spacer(minLength: 6)
                Button {
                    if state.confirmDisconnect {
                        state.disconnect()
                    } else {
                        state.confirmDisconnect = true
                    }
                } label: {
                    Text(state.confirmDisconnect ? "Click again to forget" : "Disconnect")
                        .font(.caption2)
                        .foregroundColor(state.confirmDisconnect ? Palette.urgent : Palette.dim)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Cloud mode lists every site here; local mode lists network devices.
    private var secondTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: state.cloudMode ? "ALL SITES" : "NETWORK DEVICES")

            if state.cloudMode {
                ForEach(Array(state.summary.sites.enumerated()), id: \.offset) { entry in
                    SiteRow(
                        site: entry.element,
                        trailing: entry.element.statusText.uppercased(),
                        trailingColor: Palette.color(for: entry.element.status),
                        dotColor: Palette.color(for: entry.element.status)
                    ) {
                        state.openSite(entry.element)
                    }
                }
            } else {
                ForEach(Array(state.summary.network.devices.enumerated()), id: \.offset) { entry in
                    DeviceRow(device: entry.element)
                }
            }

            if !state.summary.network.available {
                EmptyNote(text: "UniFi Network is unavailable for this connection")
            }
        }
    }

    private var protectTab: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: "PROTECT CAMERAS")

            if !state.selectedCameraId.isEmpty {
                CameraStage(
                    image: state.snapshot,
                    name: state.selectedCameraName,
                    placeholder: "Loading \(state.selectedCameraName)…"
                )
            }

            CameraGrid(cameras: state.summary.protect.cameras, state: state)

            if !state.summary.protect.available {
                EmptyNote(text: "UniFi Protect is unavailable for this connection")
            }
        }
    }
}

/// Four-per-row camera picker shared by the fleet and per-site Protect views.
struct CameraGrid: View {
    let cameras: [Camera]
    @ObservedObject var state: AppState

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 6), count: 4)
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(Array(cameras.enumerated()), id: \.offset) { entry in
                CameraTile(
                    camera: entry.element,
                    selected: entry.element.id == state.selectedCameraId
                ) {
                    state.selectCamera(entry.element)
                }
            }
        }
    }
}
