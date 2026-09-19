import SiteThreadCore
import SwiftUI

struct OverviewView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            healthCard
            tiles
            if !state.overviewSelection.isEmpty { expansion }
        }
    }

    // MARK: Health

    private var headline: String {
        switch state.severity {
        case .healthy: return "All sites healthy"
        case .critical: return "Attention required"
        default: return "UniFi SiteThread notice"
        }
    }

    private var healthCard: some View {
        Card(borderColor: state.severity == .critical ? Palette.urgent : Color.primary.opacity(0.12)) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: Palette.symbol(for: state.severity))
                    .font(.system(size: 20))
                    .foregroundColor(Palette.color(for: state.severity))

                VStack(alignment: .leading, spacing: 4) {
                    Text(headline).font(.system(size: 13, weight: .bold))
                    Text(state.summary.message)
                        .font(.system(size: 11))
                        .foregroundColor(Palette.dim)
                        .fixedSize(horizontal: false, vertical: true)

                    if state.cloudMode {
                        ForEach(Array(state.attentionSites.enumerated()), id: \.offset) { entry in
                            attentionRow(entry.element)
                        }
                    }
                }
            }
        }
    }

    private func attentionRow(_ site: Site) -> some View {
        Button {
            state.openSite(site)
        } label: {
            HStack(spacing: 8) {
                StatusDot(color: state.attentionColor(for: site), size: 8)
                Text(site.name.isEmpty ? "UniFi site" : site.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Spacer(minLength: 6)
                Text(site.status == .up
                    ? "\(site.offlineCount) device(s) offline"
                    : (site.statusText.isEmpty ? "Needs attention" : site.statusText))
                    .font(.caption2)
                    .foregroundColor(state.attentionColor(for: site))
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 7)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Summary tiles

    private struct Tile {
        let key: String
        let label: String
        let value: Int
        let symbol: String
    }

    private var tileModel: [Tile] {
        if state.cloudMode {
            return [
                Tile(key: "sites", label: "SITES", value: state.summary.sites.count, symbol: "mappin.and.ellipse"),
                Tile(key: "devices", label: "DEVICES", value: state.summary.network.deviceCount, symbol: "server.rack"),
                Tile(key: "clients", label: "CLIENTS", value: state.summary.network.clientCount, symbol: "person.2"),
                Tile(
                    key: "offline",
                    label: "ISSUES",
                    value: state.attentionSites.count + state.overviewDevices("offline").count,
                    symbol: "exclamationmark.triangle"
                ),
            ]
        }
        return [
            Tile(key: "devices", label: "DEVICES", value: state.summary.network.deviceCount, symbol: "server.rack"),
            Tile(key: "clients", label: "CLIENTS", value: state.summary.network.clientCount, symbol: "person.2"),
            Tile(key: "cameras", label: "CAMERAS", value: state.summary.protect.cameraCount, symbol: "video"),
            Tile(key: "offline", label: "OFFLINE", value: state.alertCount, symbol: "exclamationmark.triangle"),
        ]
    }

    private var tiles: some View {
        HStack(spacing: 8) {
            ForEach(Array(tileModel.enumerated()), id: \.offset) { entry in
                StatTile(
                    symbol: entry.element.symbol,
                    value: entry.element.value,
                    label: entry.element.label,
                    selected: state.overviewSelection == entry.element.key
                ) {
                    state.selectOverview(entry.element.key)
                }
            }
        }
    }

    // MARK: Expanded list

    private var expansionTitle: String {
        switch state.overviewSelection {
        case "sites": return "ALL SITES"
        case "devices": return "DEVICES"
        case "clients": return "CLIENTS BY SITE"
        case "cameras": return "CAMERAS"
        default: return "SITES AND DEVICES NEEDING ATTENTION"
        }
    }

    private var expansion: some View {
        let sites = state.overviewSites(state.overviewSelection)
        let devices = state.overviewDevices(state.overviewSelection)
        let cameras = state.overviewCameras(state.overviewSelection)

        return VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: expansionTitle)

            ForEach(Array(sites.enumerated()), id: \.offset) { entry in
                SiteRow(
                    site: entry.element,
                    trailing: trailing(for: entry.element),
                    trailingColor: state.overviewSelection == "offline"
                        ? state.attentionColor(for: entry.element)
                        : Palette.dim,
                    dotColor: state.attentionColor(for: entry.element)
                ) {
                    state.openSite(entry.element)
                }
            }

            ForEach(Array(devices.enumerated()), id: \.offset) { entry in
                DeviceRow(device: entry.element)
            }

            ForEach(Array(cameras.enumerated()), id: \.offset) { entry in
                DeviceRow(
                    device: Device(
                        id: entry.element.id,
                        name: entry.element.name,
                        model: entry.element.model,
                        ip: "",
                        online: entry.element.online,
                        update: false
                    ),
                    fallbackName: "Camera"
                )
            }

            if sites.isEmpty && devices.isEmpty && cameras.isEmpty {
                EmptyNote(text: state.overviewSelection == "clients"
                    ? "Client totals are available by site after connecting through UI Account"
                    : "No matching items")
            }
        }
    }

    private func trailing(for site: Site) -> String {
        if state.overviewSelection == "clients" { return "\(site.clientCount) CLIENTS" }
        if state.overviewSelection == "offline" && site.offlineCount > 0 {
            return "\(site.offlineCount) OFFLINE"
        }
        return "\(site.deviceCount) DEVICES"
    }
}
