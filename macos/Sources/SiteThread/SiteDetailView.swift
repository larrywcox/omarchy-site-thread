import SiteThreadCore
import SwiftUI

/// The in-app site view. Selecting a site never leaves the panel; Back returns
/// to the fleet list.
struct SiteDetailView: View {
    @ObservedObject var state: AppState

    private var site: Site {
        state.selectedSite ?? Site(id: "", hostId: "", name: "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            healthCard

            if state.siteLoading && state.siteDetail.network.devices.isEmpty {
                EmptyNote(text: "Loading live site data…")
            }

            if state.siteProtectInstalled {
                TabBar(
                    labels: ["Network", "Protect"],
                    selection: $state.siteTab,
                    onChange: { state.siteTabChanged() }
                )
            }

            stats

            if state.siteTab == 1 && state.siteProtectInstalled {
                protectSection
            } else {
                networkSection
            }
        }
    }

    private var healthCard: some View {
        Card(borderColor: Palette.color(for: site.status)) {
            HStack(spacing: 10) {
                StatusDot(color: Palette.color(for: site.status), size: 12)
                VStack(alignment: .leading, spacing: 1) {
                    Text(site.statusText.isEmpty ? "Online" : site.statusText)
                        .font(.system(size: 12, weight: .semibold))
                    Text(site.isp.isEmpty
                        ? "Live data from this UniFi console"
                        : "\(site.isp)  ·  Live data from this UniFi console")
                        .font(.caption2)
                        .foregroundColor(Palette.dim)
                }
            }
        }
    }

    private var stats: some View {
        HStack(spacing: 8) {
            statTile("DEVICES", state.siteDetail.network.deviceCount)
            statTile("CLIENTS", state.siteDetail.network.clientCount)
            statTile("OFFLINE", state.siteDetail.network.offlineCount)
            statTile("CAMERAS", state.siteProtectInstalled ? state.siteDetail.protect.cameraCount : 0)
        }
    }

    private func statTile(_ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)").font(.title3.bold())
            Text(label).font(.caption2).foregroundColor(Palette.dim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))
        .overlay(
            RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.10), lineWidth: 1)
        )
    }

    private var networkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: "LIVE NETWORK DEVICES")
            ForEach(Array(state.siteDetail.network.devices.enumerated()), id: \.offset) { entry in
                DeviceRow(device: entry.element)
            }
            if state.siteDetail.network.devices.isEmpty && !state.siteLoading {
                EmptyNote(text: "No Network devices were returned for this site")
            }
        }
    }

    private var protectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(text: "LIVE PROTECT CAMERAS")

            if !state.selectedCameraId.isEmpty {
                CameraStage(
                    image: state.snapshot,
                    name: state.selectedCameraName,
                    placeholder: "Loading \(state.selectedCameraName)…"
                )
            }

            CameraGrid(cameras: state.siteDetail.protect.cameras, state: state)

            if state.siteDetail.protect.cameras.isEmpty {
                EmptyNote(text: "Protect is installed, but no cameras were returned")
            }
        }
    }
}
