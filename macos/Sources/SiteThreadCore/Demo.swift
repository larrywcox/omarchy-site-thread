import Foundation

/// Fictional fleet used by `SITE_THREAD_DEMO=1` and by the test suite, ported
/// from the Linux helper's `summary --demo`. No network access is performed.
public enum Demo {
    public static func summary() -> Summary {
        let devices = [
            Device(id: "gw", name: "Dream Machine Pro", model: "UDM Pro", ip: "10.0.0.1", online: true, update: false, site: "Home"),
            Device(id: "sw", name: "Core Switch", model: "USW Pro 24 PoE", ip: "10.0.0.2", online: true, update: true, site: "Main Office"),
            Device(id: "ap", name: "Living Room AP", model: "U7 Pro", ip: "10.0.0.3", online: true, update: false, site: "Home"),
        ]
        let cameras = [
            Camera(id: "frontdoor", name: "Front Door", model: "G4 Doorbell Pro", online: true, recording: true),
            Camera(id: "driveway", name: "Driveway", model: "AI Pro", online: true, recording: true),
            Camera(id: "backyard", name: "Backyard", model: "G5 Turret", online: true, recording: true),
        ]
        let sites = sortSites([
            Site(
                id: "home", hostId: "console-home", name: "Home", isp: "Fiber",
                deviceCount: 8, clientCount: 47, offlineCount: 0, updateCount: 1,
                wanUptime: 100, permission: "owner", owner: true,
                status: .up, statusText: "Online"
            ),
            Site(
                id: "office", hostId: "console-office", name: "Main Office", isp: "Business Fiber",
                deviceCount: 19, clientCount: 86, offlineCount: 0, updateCount: 0,
                wanUptime: 99.99, permission: "admin",
                status: .backup, statusText: "Backup WAN active"
            ),
            Site(
                id: "warehouse", hostId: "console-warehouse", name: "Warehouse", isp: "Cable",
                deviceCount: 11, clientCount: 31, offlineCount: 11, updateCount: 2,
                wanUptime: 99.72, permission: "admin",
                status: .down, statusText: "Site unreachable"
            ),
        ])

        var summary = Summary()
        summary.connected = true
        summary.demo = true
        summary.cloud = true
        summary.host = "unifi.ui.com"
        summary.baseUrl = "https://unifi.ui.com"
        summary.siteLabel = "3 sites"
        summary.sites = sites
        summary.network = NetworkSummary(
            available: true, devices: devices, deviceCount: 38,
            offlineCount: 1, updateCount: 3, clientCount: 164
        )
        summary.protect = ProtectSummary(
            available: true, installed: true, cameras: cameras,
            cameraCount: 3, offlineCount: 0
        )
        SummaryBuilder.applyFleetSeverity(&summary)
        return summary
    }

    public static func siteDetail(for site: Site) -> SiteDetail {
        var detail = SiteDetail()
        detail.hostId = site.hostId
        detail.siteId = site.id
        detail.name = site.name
        detail.network = NetworkSummary(
            available: true,
            devices: [
                Device(id: "gw", name: "Gateway", model: "UXG Pro", ip: "10.1.0.1", online: site.status != .down, update: false),
                Device(id: "sw1", name: "Switch 24", model: "USW 24", ip: "10.1.0.2", online: site.status != .down, update: true),
                Device(id: "ap1", name: "Ceiling AP", model: "U6 Pro", ip: "10.1.0.3", online: site.offlineCount == 0, update: false),
            ],
            deviceCount: site.deviceCount,
            offlineCount: site.offlineCount,
            updateCount: site.updateCount,
            clientCount: site.clientCount
        )
        detail.protect = ProtectSummary(
            available: site.status != .down,
            installed: site.status != .down,
            cameras: [
                Camera(id: "cam1", name: "Entrance", model: "G5 Bullet", online: true, recording: true),
                Camera(id: "cam2", name: "Loading Bay", model: "G4 Pro", online: true, recording: true),
            ],
            cameraCount: 2,
            offlineCount: 0
        )
        return detail
    }

    public static var isEnabled: Bool {
        ProcessInfo.processInfo.environment["SITE_THREAD_DEMO"] == "1"
    }
}
