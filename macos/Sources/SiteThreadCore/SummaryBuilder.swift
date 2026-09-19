import Foundation

/// Builds the panel's view models from UniFi responses. This is a direct port
/// of `build_cloud_summary`, `build_cloud_site`, and `build_summary` from the
/// Linux helper, so both platforms show the same numbers.
public enum SummaryBuilder {

    // MARK: Fleet-wide summary through Site Manager

    public static func cloudSummary(key: String) async throws -> Summary {
        let rawSites = try await UniFiClient.cloudRows(key: key, endpoint: "/v1/sites")
        if rawSites.count > Limits.maxModelItems {
            throw SiteThreadError("UniFi Site Manager returned too many sites")
        }
        let rawHosts = (try? await UniFiClient.cloudRows(key: key, endpoint: "/v1/hosts")) ?? []
        let rawGroups = (try? await UniFiClient.cloudRows(key: key, endpoint: "/v1/devices")) ?? []

        var hostNames: [String: String] = [:]
        var hostOnline: [String: Bool] = [:]
        for host in rawHosts {
            let identifier = try modelString(firstValue(host, ["id", "hostId"]), maxLength: 256)
            if !identifier.isEmpty { hostOnline[identifier] = hostIsOnline(host) }
        }

        var flattened: [[String: Any]] = []
        for group in rawGroups {
            let hostId = try modelString(firstValue(group, ["hostId", "id"]), maxLength: 256)
            let hostName = try modelString(firstValue(group, ["hostName", "name"]))
            if !hostId.isEmpty, !hostName.isEmpty { hostNames[hostId] = hostName }

            if let members = group["devices"] as? [Any] {
                for member in members {
                    guard var copy = member as? [String: Any] else { continue }
                    if copy["hostId"] == nil { copy["hostId"] = hostId }
                    if copy["hostName"] == nil { copy["hostName"] = hostName }
                    flattened.append(copy)
                }
            } else {
                flattened.append(group)
            }
            if flattened.count > Limits.maxModelItems {
                throw SiteThreadError("UniFi Site Manager returned too many devices")
            }
        }

        var sites: [Site] = []
        var totalDevices = 0
        var totalClients = 0
        var totalOffline = 0
        var totalUpdates = 0

        for item in rawSites {
            let meta = (item["meta"] as? [String: Any]) ?? [:]
            let stats = (item["statistics"] as? [String: Any]) ?? [:]
            let counts = (stats["counts"] as? [String: Any]) ?? [:]
            let percentages = (stats["percentages"] as? [String: Any]) ?? [:]
            let ispInfo = (stats["ispInfo"] as? [String: Any]) ?? [:]

            let hostId = try modelString(firstValue(item, ["hostId"]), maxLength: 256)
            let rawName = try modelString(firstValue(meta, ["desc", "name"], default: "Site"))
            // Consoles that never got a site name report "Default"; the host
            // name is far more useful in a fleet list.
            let name = rawName.lowercased() == "default" ? (hostNames[hostId] ?? rawName) : rawName

            let deviceCount = Int(nestedNumber(counts, ["totalDevice"]))
            let clientCount = Int(
                nestedNumber(counts, ["wifiClient"])
                    + nestedNumber(counts, ["wiredClient"])
                    + nestedNumber(counts, ["guestClient"])
            )
            let offlineCount = Int(nestedNumber(counts, ["offlineDevice"]))
            let updateCount = Int(nestedNumber(counts, ["pendingUpdateDevice"]))
            totalDevices += deviceCount
            totalClients += clientCount
            totalOffline += offlineCount
            totalUpdates += updateCount

            var health = siteHealth(stats: stats, counts: counts)
            if let reachable = hostOnline[hostId], !reachable {
                health = (.down, "Site unreachable")
            }

            sites.append(Site(
                id: try modelString(firstValue(item, ["siteId", "id"]), maxLength: 128),
                hostId: hostId,
                name: name,
                isp: try modelString(firstValue(ispInfo, ["name", "organization"])),
                timezone: try modelString(firstValue(meta, ["timezone"]), maxLength: 128),
                deviceCount: deviceCount,
                clientCount: clientCount,
                offlineCount: offlineCount,
                updateCount: updateCount,
                wanUptime: nestedNumber(percentages, ["wanUptime"]),
                permission: try modelString(
                    firstValue(item, ["permission"], default: "viewer"), maxLength: 64
                ),
                owner: (item["isOwner"] as? NSNumber)?.boolValue ?? false,
                status: health.0,
                statusText: health.1
            ))
        }
        sites = sortSites(sites)

        var devices: [Device] = []
        for item in flattened {
            var device = try compactDevice(item)
            device.site = try modelString(firstValue(item, ["hostName"]))
            devices.append(device)
        }

        let cameraWords = ["camera", "protect", "doorbell", "ai pro", "g3", "g4", "g5", "uvc"]
        let cameraItems = flattened.filter { item in
            let haystack = item.values
                .compactMap { value -> String? in
                    if let text = value as? String { return text.lowercased() }
                    if let number = value as? NSNumber { return stringify(number).lowercased() }
                    return nil
                }
                .joined(separator: " ")
            return cameraWords.contains { haystack.contains($0) }
        }
        let cameras = try cameraItems.map { try compactCamera($0) }

        if totalDevices == 0 && !devices.isEmpty {
            totalDevices = devices.count
            totalOffline = devices.filter { !$0.online }.count
            totalUpdates = devices.filter { $0.update }.count
        }

        var summary = Summary()
        summary.connected = true
        summary.cloud = true
        summary.baseUrl = "https://unifi.ui.com"
        summary.host = "unifi.ui.com"
        summary.siteLabel = "\(sites.count) site" + (sites.count == 1 ? "" : "s")
        summary.sites = sites
        summary.network = NetworkSummary(
            available: true,
            devices: devices,
            deviceCount: totalDevices,
            offlineCount: totalOffline,
            updateCount: totalUpdates,
            clientCount: totalClients
        )
        summary.protect = ProtectSummary(
            available: !cameras.isEmpty,
            installed: !cameras.isEmpty,
            cameras: cameras,
            cameraCount: cameras.count,
            offlineCount: cameras.filter { !$0.online }.count
        )
        applyFleetSeverity(&summary)
        return summary
    }

    /// Shared by the initial build and by the two-check outage stabilizer.
    public static func applyFleetSeverity(_ summary: inout Summary) {
        let down = summary.sites.filter { $0.status == .down }.count
        let backup = summary.sites.filter { $0.status == .backup }.count
        let total = summary.sites.count

        if down > 0 {
            summary.severity = .critical
            summary.message = "\(down) site(s) unreachable"
        } else if backup > 0 {
            summary.severity = .warning
            summary.message = "\(backup) site(s) using backup WAN"
        } else if summary.network.offlineCount > 0 {
            summary.severity = .critical
            summary.message = "\(summary.network.offlineCount) device(s) offline across \(total) sites"
        } else if summary.network.updateCount > 0 {
            summary.severity = .warning
            summary.message = "\(summary.network.updateCount) firmware update(s) across \(total) sites"
        } else {
            summary.severity = .healthy
            summary.message = "All \(total) sites operational"
        }
    }

    // MARK: One site, live, through Cloud Connector

    public static func cloudSite(key: String, hostId: String, siteId: String) async throws -> SiteDetail {
        guard isValidIdentifier(siteId) else {
            throw SiteThreadError("Invalid UniFi site id")
        }

        let sitesPath = try UniFiClient.connectorPath(
            hostId: hostId, path: "/network/integration/v1/sites"
        )
        let sitesResponse = try await UniFiClient.cloudJSON(key: key, path: sitesPath)
        guard sitesResponse.0 == 200 else {
            throw SiteThreadError(
                "This site's Network application is unavailable (HTTP \(sitesResponse.0))"
            )
        }

        let networkSites = try rows(sitesResponse.1)
        var chosen: [String: Any]?
        for item in networkSites {
            let identifier = try modelString(firstValue(item, ["id", "siteId", "_id"]), maxLength: 128)
            if identifier == siteId { chosen = item }
        }
        if chosen == nil, networkSites.count == 1 { chosen = networkSites[0] }
        guard let site = chosen else {
            throw SiteThreadError("UniFi Cloud Connector could not match this Network site")
        }

        let localSiteId = try modelString(firstValue(site, ["id", "siteId", "_id"]), maxLength: 128)
        guard isValidIdentifier(localSiteId) else {
            throw SiteThreadError("The console returned an invalid Network site id")
        }

        let devicePath = try UniFiClient.connectorPath(
            hostId: hostId, path: "/network/integration/v1/sites/\(localSiteId)/devices"
        )
        let clientPath = try UniFiClient.connectorPath(
            hostId: hostId, path: "/network/integration/v1/sites/\(localSiteId)/clients"
        )
        let protectPath = try UniFiClient.connectorPath(
            hostId: hostId, path: "/protect/integration/v1/cameras"
        )

        let deviceResponse = try await UniFiClient.cloudJSON(key: key, path: devicePath)
        let clientResponse = try await UniFiClient.cloudJSON(key: key, path: clientPath)
        let protectResponse = try await UniFiClient.cloudJSON(key: key, path: protectPath)

        var devices: [Device] = []
        if deviceResponse.0 == 200 {
            devices = try rows(deviceResponse.1).map { try compactDevice($0) }
        }
        var clients: [[String: Any]] = []
        if clientResponse.0 == 200 {
            clients = try rows(clientResponse.1)
        }
        let protectInstalled = protectResponse.0 == 200
        var cameras: [Camera] = []
        if protectInstalled {
            cameras = try rows(protectResponse.1).map { try compactCamera($0) }
        }

        var detail = SiteDetail()
        detail.hostId = hostId
        detail.siteId = siteId
        detail.name = try modelString(
            firstValue(site, ["name", "displayName"], default: "UniFi site")
        )
        detail.network = NetworkSummary(
            available: true,
            devices: devices,
            deviceCount: devices.count,
            offlineCount: devices.filter { !$0.online }.count,
            updateCount: devices.filter { $0.update }.count,
            clientCount: clients.count
        )
        detail.protect = ProtectSummary(
            available: protectInstalled,
            installed: protectInstalled,
            cameras: cameras,
            cameraCount: cameras.count,
            offlineCount: cameras.filter { !$0.online }.count
        )
        return detail
    }

    // MARK: Single pinned console

    public static func localSummary(connection: Connection, key: String) async throws -> Summary {
        let networkResponse = try await UniFiClient.localJSON(
            connection: connection, key: key, path: "/proxy/network/integration/v1/sites"
        )
        let protectResponse = try await UniFiClient.localJSON(
            connection: connection, key: key, path: "/proxy/protect/integration/v1/cameras"
        )

        var networkSites: [[String: Any]] = []
        if networkResponse.0 == 200 {
            networkSites = try rows(networkResponse.1)
        }
        let site = networkSites.first ?? [:]
        let siteId = try modelString(firstValue(site, ["id", "siteId", "_id"]), maxLength: 128)

        var devices: [Device] = []
        var clients: [[String: Any]] = []
        if !siteId.isEmpty, isValidIdentifier(siteId) {
            let deviceResponse = try await UniFiClient.localJSON(
                connection: connection, key: key,
                path: "/proxy/network/integration/v1/sites/\(siteId)/devices"
            )
            let clientResponse = try await UniFiClient.localJSON(
                connection: connection, key: key,
                path: "/proxy/network/integration/v1/sites/\(siteId)/clients"
            )
            if deviceResponse.0 == 200 {
                devices = try rows(deviceResponse.1).map { try compactDevice($0) }
            }
            if clientResponse.0 == 200 {
                clients = try rows(clientResponse.1)
            }
        }

        var cameras: [Camera] = []
        if protectResponse.0 == 200 {
            cameras = try rows(protectResponse.1).map { try compactCamera($0) }
        }
        let offlineDevices = devices.filter { !$0.online }.count
        let offlineCameras = cameras.filter { !$0.online }.count
        let updates = devices.filter { $0.update }.count

        let availableApps = (networkResponse.0 == 200 ? 1 : 0) + (protectResponse.0 == 200 ? 1 : 0)
        if availableApps == 0 {
            throw SiteThreadError("The API key was accepted by neither Network nor Protect")
        }

        var summary = Summary()
        summary.connected = true
        summary.cloud = false
        summary.baseUrl = connection.baseUrl
        summary.host = connection.hostname
        summary.siteLabel = try modelString(
            firstValue(site, ["name", "displayName"], default: "Default")
        )
        summary.network = NetworkSummary(
            available: networkResponse.0 == 200,
            devices: devices,
            deviceCount: devices.count,
            offlineCount: offlineDevices,
            updateCount: updates,
            clientCount: clients.count
        )
        summary.protect = ProtectSummary(
            available: protectResponse.0 == 200,
            installed: protectResponse.0 == 200,
            cameras: cameras,
            cameraCount: cameras.count,
            offlineCount: offlineCameras
        )

        if offlineDevices + offlineCameras > 0 {
            summary.severity = .critical
            summary.message = "\(offlineDevices + offlineCameras) device(s) offline"
        } else if availableApps < 2 {
            summary.severity = .warning
            summary.message = "One UniFi application is unavailable"
        } else if updates > 0 {
            summary.severity = .warning
            summary.message = "\(updates) firmware update(s) available"
        } else {
            summary.severity = .healthy
            summary.message = "All systems operational"
        }
        return summary
    }

    // MARK: Snapshots

    public static func snapshot(
        connection: Connection,
        key: String,
        cameraId: String,
        hostId: String?
    ) async throws -> Data {
        guard isValidIdentifier(cameraId) else {
            throw SiteThreadError("Invalid camera id")
        }
        let response: (Int, Data)
        if connection.isCloud {
            guard let hostId = hostId, !hostId.isEmpty else {
                throw SiteThreadError("A site is required for a cloud camera")
            }
            let path = try UniFiClient.connectorPath(
                hostId: hostId, path: "/protect/integration/v1/cameras/\(cameraId)/snapshot"
            )
            response = try await UniFiClient.cloudData(key: key, path: path)
        } else {
            response = try await UniFiClient.localData(
                connection: connection, key: key,
                path: "/proxy/protect/integration/v1/cameras/\(cameraId)/snapshot"
            )
        }
        guard response.0 == 200, !response.1.isEmpty else {
            throw SiteThreadError("Snapshot failed (HTTP \(response.0))")
        }
        return response.1
    }
}
