import AppKit
import Foundation
import SiteThreadCore
import SwiftUI

@MainActor
final class AppState: ObservableObject {

    // Connection + fleet
    @Published var connection: Connection?
    @Published var summary = Summary()
    @Published var loading = false
    @Published var notice = ""

    // Navigation
    @Published var activeTab = 0
    @Published var overviewSelection = ""
    @Published var selectedSite: Site?
    @Published var siteDetail = SiteDetail()
    @Published var siteLoading = false
    @Published var siteTab = 0

    // Protect
    @Published var selectedCameraId = ""
    @Published var selectedCameraName = ""
    @Published var snapshot: NSImage?

    // Sign-in
    @Published var localSetup = false
    @Published var cloudKey = ""
    @Published var localKey = ""
    @Published var hostField = ""
    @Published var probeFingerprint = ""
    @Published var certificateAccepted = false
    @Published var connecting = false
    @Published var confirmDisconnect = false

    /// Outages must be seen twice before a site turns red, so a momentary
    /// cloud disconnect does not raise a false alarm.
    private var downConfirmations: [String: Int] = [:]

    private var refreshTimer: Timer?
    private var snapshotTimer: Timer?
    private(set) var panelOpen = false

    var refreshSeconds: Int {
        let stored = UserDefaults.standard.integer(forKey: "refreshSeconds")
        return stored == 0 ? 30 : min(600, max(10, stored))
    }

    var panelWidth: CGFloat {
        let stored = UserDefaults.standard.integer(forKey: "panelWidth")
        return stored == 0 ? 420 : CGFloat(min(1200, max(360, stored)))
    }

    var connected: Bool { summary.connected }
    var cloudMode: Bool { summary.connected && summary.cloud }
    var inSite: Bool { selectedSite != nil }
    var siteProtectInstalled: Bool { siteDetail.protect.installed }

    var severity: Severity { connected ? summary.severity : .disconnected }

    private func countSites(_ status: SiteStatus) -> Int {
        summary.sites.filter { $0.status == status }.count
    }

    /// The bar icon reflects site reachability only, never device counts.
    var barSeverity: Severity {
        guard connected else { return .disconnected }
        if !cloudMode { return severity }
        if countSites(.down) > 0 { return .critical }
        if countSites(.backup) > 0 { return .warning }
        return .healthy
    }

    /// The badge counts unreachable sites only, matching the Linux panel.
    var alertCount: Int {
        guard connected else { return 0 }
        if cloudMode { return countSites(.down) }
        return summary.network.offlineCount + summary.protect.offlineCount
    }

    var subtitle: String {
        guard connected else { return "Network + Protect" }
        let label = summary.siteLabel.isEmpty ? "Default" : summary.siteLabel
        let host = summary.host.isEmpty ? "UniFi" : summary.host
        return "\(label)  ·  \(host)"
    }

    // MARK: Lifecycle

    func start() {
        connection = ConnectionStore.load()
        startRefreshTimer()
        Task { await refresh() }
    }

    func panelOpened() {
        panelOpen = true
        confirmDisconnect = false
        Task { await reload() }
        startSnapshotTimer()
    }

    func panelClosed() {
        panelOpen = false
        snapshot = nil
        snapshotTimer?.invalidate()
        snapshotTimer = nil
    }

    private func startRefreshTimer() {
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: TimeInterval(refreshSeconds), repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.reload() }
        }
    }

    /// Refreshes whichever view is on screen.
    func reload() async {
        if inSite {
            await loadSite()
        } else {
            await refresh()
        }
    }

    private func startSnapshotTimer() {
        snapshotTimer?.invalidate()
        snapshotTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { await self.requestSnapshot() }
        }
    }

    // MARK: Credentials

    private func storedKey() -> String? {
        (try? Keychain.load()) ?? nil
    }

    // MARK: Fleet refresh

    func refresh() async {
        guard !loading else { return }
        if Demo.isEnabled {
            summary = stabilize(Demo.summary())
            notice = "Demo data — no console is connected"
            return
        }
        guard let connection = connection, let key = storedKey() else {
            summary = Summary()
            notice = ""
            return
        }

        loading = true
        notice = ""
        do {
            let fresh: Summary
            if connection.isCloud {
                fresh = try await SummaryBuilder.cloudSummary(key: key)
            } else {
                fresh = try await SummaryBuilder.localSummary(connection: connection, key: key)
            }
            summary = stabilize(fresh)
        } catch {
            notice = message(for: error, fallback: "Unable to load UniFi")
        }
        loading = false
    }

    /// Ported from `stabilizeCloudSummary`: a site must fail two consecutive
    /// checks before it is shown as unreachable.
    private func stabilize(_ incoming: Summary) -> Summary {
        guard incoming.cloud else { return incoming }
        var result = incoming
        var next: [String: Int] = [:]

        for index in result.sites.indices where result.sites[index].status == .down {
            let key = result.sites[index].confirmationKey
            let failures = (downConfirmations[key] ?? 0) + 1
            next[key] = min(2, failures)
            if failures < 2 {
                result.sites[index].status = .up
                result.sites[index].statusText = "Checking connectivity"
                result.sites[index].pendingDown = true
            }
        }
        downConfirmations = next

        result.sites = sortSites(result.sites)
        SummaryBuilder.applyFleetSeverity(&result)
        return result
    }

    // MARK: Site drill-down

    func openSite(_ site: Site) {
        guard !site.hostId.isEmpty, !site.id.isEmpty else { return }
        selectedSite = site
        siteDetail = SiteDetail()
        siteTab = 0
        clearCamera()
        Task { await loadSite() }
    }

    func backToSites() {
        selectedSite = nil
        siteDetail = SiteDetail()
        siteTab = 0
        clearCamera()
        activeTab = 1
        notice = ""
    }

    func loadSite() async {
        guard let site = selectedSite, !siteLoading else { return }
        if Demo.isEnabled {
            siteDetail = Demo.siteDetail(for: site)
            return
        }
        guard let connection = connection, connection.isCloud, let key = storedKey() else {
            notice = "Site drill-down is available for UI Account connections"
            return
        }

        siteLoading = true
        notice = ""
        do {
            siteDetail = try await SummaryBuilder.cloudSite(
                key: key, hostId: site.hostId, siteId: site.id
            )
            if siteTab == 1, selectedCameraId.isEmpty, let first = siteDetail.protect.cameras.first {
                selectCamera(first)
            }
        } catch {
            notice = message(for: error, fallback: "Unable to load this site")
        }
        siteLoading = false
    }

    // MARK: Protect

    private func clearCamera() {
        selectedCameraId = ""
        selectedCameraName = ""
        snapshot = nil
    }

    func selectCamera(_ camera: Camera) {
        selectedCameraId = camera.id
        selectedCameraName = camera.name
        snapshot = nil
        guard !selectedCameraId.isEmpty else { return }
        Task { await requestSnapshot() }
    }

    func requestSnapshot() async {
        let viewingProtect = inSite ? siteTab == 1 : activeTab == 2
        guard panelOpen, viewingProtect, !selectedCameraId.isEmpty else { return }
        guard !Demo.isEnabled else { return }
        guard let connection = connection, let key = storedKey() else { return }

        let hostId = inSite ? selectedSite?.hostId : nil
        do {
            let data = try await SummaryBuilder.snapshot(
                connection: connection, key: key, cameraId: selectedCameraId, hostId: hostId
            )
            snapshot = try data.asImage()
        } catch {
            // A failed frame leaves the previous one on screen rather than
            // flashing an error every 2.5 seconds.
        }
    }

    func tabChanged() {
        guard !inSite, activeTab == 2 else { return }
        if selectedCameraId.isEmpty, let first = summary.protect.cameras.first {
            selectCamera(first)
        } else {
            Task { await requestSnapshot() }
        }
    }

    func siteTabChanged() {
        guard inSite, siteTab == 1 else { return }
        if selectedCameraId.isEmpty, let first = siteDetail.protect.cameras.first {
            selectCamera(first)
        } else {
            Task { await requestSnapshot() }
        }
    }

    // MARK: Sign-in

    func pasteAPIKey(intoLocalField: Bool) {
        let value = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else {
            notice = "No text was found on the clipboard"
            return
        }
        if intoLocalField { localKey = value } else { cloudKey = value }
        notice = "API key pasted securely"
    }

    func connectCloud() async {
        let key = cloudKey
        guard !connecting, !key.isEmpty else { return }
        guard isValidAPIKey(key) else {
            notice = "Enter a valid UI Account API key"
            return
        }

        connecting = true
        cloudKey = ""
        notice = "Connecting to all UniFi sites…"
        do {
            // Validate before persisting either the connection or the credential.
            let fresh = try await SummaryBuilder.cloudSummary(key: key)
            try Keychain.store(key)
            try ConnectionStore.save(.cloud)
            connection = .cloud
            summary = stabilize(fresh)
            activeTab = 0
            notice = "Connected to all accessible sites"
        } catch {
            notice = message(for: error, fallback: "Site Manager authentication failed")
        }
        connecting = false
    }

    func inspectCertificate() async {
        let host = hostField.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !host.isEmpty else { return }

        probeFingerprint = ""
        certificateAccepted = false
        notice = "Inspecting the console certificate…"
        do {
            let result = try await UniFiClient.probe(
                host: host, storedFingerprint: connection?.fingerprint
            )
            probeFingerprint = result.fingerprint
            certificateAccepted = result.trusted
            notice = result.trusted
                ? "Console identity already trusted"
                : "Compare this fingerprint with your UniFi console"
        } catch {
            notice = message(for: error, fallback: "Certificate inspection failed")
        }
    }

    func connectLocal() async {
        let key = localKey
        guard !connecting, certificateAccepted, !probeFingerprint.isEmpty, !key.isEmpty else { return }
        guard isValidAPIKey(key) else {
            notice = "Enter a valid UniFi API key"
            return
        }

        connecting = true
        localKey = ""
        notice = "Authenticating securely…"
        do {
            let normalized = try UniFiClient.normalizeHost(hostField)
            // Re-read the certificate so a swap between inspection and connect
            // is caught before the credential leaves this process.
            let current = try await UniFiClient.probe(host: hostField, storedFingerprint: probeFingerprint)
            guard current.fingerprint == probeFingerprint else {
                throw SiteThreadError("The console certificate changed; inspect it again before connecting")
            }

            let candidate = Connection(
                mode: "local",
                baseUrl: normalized.0,
                hostname: normalized.1,
                port: normalized.2,
                fingerprint: probeFingerprint
            )
            let fresh = try await SummaryBuilder.localSummary(connection: candidate, key: key)
            try Keychain.store(key)
            try ConnectionStore.save(candidate)
            connection = candidate
            summary = fresh
            activeTab = 0
            probeFingerprint = ""
            certificateAccepted = false
            notice = "Connected securely"
        } catch {
            notice = message(for: error, fallback: "Authentication failed")
        }
        connecting = false
    }

    func disconnect() {
        Keychain.clear()
        ConnectionStore.clear()
        connection = nil
        summary = Summary()
        selectedSite = nil
        siteDetail = SiteDetail()
        downConfirmations = [:]
        clearCamera()
        confirmDisconnect = false
        notice = "Connection removed"
    }

    // MARK: Derived lists

    var attentionSites: [Site] {
        summary.sites.filter { $0.status != .up }
    }

    func attentionColor(for site: Site) -> Color {
        if site.status == .up && site.offlineCount > 0 { return Palette.urgent }
        return Palette.color(for: site.status)
    }

    func overviewSites(_ kind: String) -> [Site] {
        guard cloudMode else { return [] }
        var result: [Site]
        switch kind {
        case "sites": result = summary.sites
        case "clients": result = summary.sites.filter { $0.clientCount > 0 }
        case "offline": result = summary.sites.filter { $0.status != .up }
        default: return []
        }
        if kind == "clients" { result.sort { $0.clientCount > $1.clientCount } }
        return result
    }

    func overviewDevices(_ kind: String) -> [Device] {
        if !cloudMode && kind == "cameras" { return [] }
        switch kind {
        case "devices": return summary.network.devices
        case "offline": return summary.network.devices.filter { !$0.online }
        default: return []
        }
    }

    func overviewCameras(_ kind: String) -> [Camera] {
        guard !cloudMode, kind == "cameras" else { return [] }
        return summary.protect.cameras
    }

    func selectOverview(_ kind: String) {
        overviewSelection = overviewSelection == kind ? "" : kind
    }

    // MARK: External links

    func openConsole() {
        guard connected else { return }
        let target = summary.baseUrl.isEmpty ? "https://" + summary.host : summary.baseUrl
        open(target)
    }

    func openAccount() {
        open("https://unifi.ui.com")
    }

    private func open(_ address: String) {
        guard let url = URL(string: address), url.scheme == "https" else { return }
        NSWorkspace.shared.open(url)
    }

    // MARK: Errors

    private func message(for error: Error, fallback: String) -> String {
        if let known = error as? SiteThreadError, !known.message.isEmpty { return known.message }
        return fallback
    }
}

extension Data {
    /// Snapshots stay in memory; nothing is written to disk.
    func asImage() throws -> NSImage {
        guard let image = NSImage(data: self) else {
            throw SiteThreadError("The camera returned an unreadable snapshot")
        }
        return image
    }
}
