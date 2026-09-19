import Foundation

// MARK: - Value helpers

/// Renders a decoded JSON scalar the way the Linux helper's `str()` calls do.
public func stringify(_ value: Any) -> String {
    if let text = value as? String { return text }
    if let number = value as? NSNumber {
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue ? "true" : "false" }
        let scalar = number.doubleValue
        if scalar == scalar.rounded() && abs(scalar) < 1e15 { return String(number.int64Value) }
        return String(scalar)
    }
    if value is NSNull { return "" }
    return String(describing: value)
}

/// First key whose value is neither missing, null, nor the empty string.
public func firstValue(_ item: [String: Any], _ keys: [String], default fallback: Any = "") -> Any {
    for key in keys {
        guard let value = item[key], !(value is NSNull) else { continue }
        if let text = value as? String, text.isEmpty { continue }
        return value
    }
    return fallback
}

/// Bounded string projection. Oversized fields are rejected rather than
/// truncated so a console cannot smuggle a huge label into the panel.
public func modelString(
    _ value: Any,
    default fallback: String = "",
    maxLength: Int = Limits.maxModelStringChars
) throws -> String {
    var source = value
    if source is NSNull { source = fallback }
    if let text = source as? String, text.isEmpty { source = fallback }
    let rendered = stringify(source)
    if rendered.count > maxLength {
        throw SiteThreadError(
            "The server returned an oversized model field "
                + "(\(rendered.count) > \(maxLength) characters)"
        )
    }
    return rendered
}

public func nestedNumber(_ item: [String: Any], _ path: [String]) -> Double {
    var value: Any = item
    for key in path {
        guard let object = value as? [String: Any], let next = object[key] else { return 0 }
        value = next
    }
    if let number = value as? NSNumber { return number.doubleValue }
    if let text = value as? String { return Double(text) ?? 0 }
    return 0
}

/// Extracts the row array from the several shapes UniFi endpoints return.
public func rows(_ payload: Any?) throws -> [[String: Any]] {
    var source: [Any]?
    if let array = payload as? [Any] {
        source = array
    } else if let object = payload as? [String: Any] {
        for key in ["data", "items", "results"] {
            if let array = object[key] as? [Any] {
                source = array
                break
            }
        }
    }
    guard let items = source else { return [] }
    if items.count > Limits.maxRowsPerResponse {
        throw SiteThreadError(
            "The server returned too many rows "
                + "(\(items.count) > \(Limits.maxRowsPerResponse))"
        )
    }
    return items.compactMap { $0 as? [String: Any] }
}

public func isOnline(_ item: [String: Any]) -> Bool {
    let raw = firstValue(item, ["state", "status", "connectionState"], default: "CONNECTED")
    if let number = raw as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() {
        return number.boolValue
    }
    let online: Set<String> = ["CONNECTED", "ONLINE", "ACTIVE", "ADOPTED", "UP", "1", "TRUE"]
    return online.contains(stringify(raw).uppercased())
}

private func truthy(_ value: Any) -> Bool {
    if let number = value as? NSNumber { return number.boolValue }
    if let text = value as? String { return !text.isEmpty && text.lowercased() != "false" }
    return false
}

// MARK: - Projected models

public struct Device: Equatable {
    public var id: String
    public var name: String
    public var model: String
    public var ip: String
    public var online: Bool
    public var update: Bool
    public var site: String

    public init(
        id: String, name: String, model: String, ip: String,
        online: Bool, update: Bool, site: String = ""
    ) {
        self.id = id
        self.name = name
        self.model = model
        self.ip = ip
        self.online = online
        self.update = update
        self.site = site
    }
}

public struct Camera: Equatable {
    public var id: String
    public var name: String
    public var model: String
    public var online: Bool
    public var recording: Bool

    public init(id: String, name: String, model: String, online: Bool, recording: Bool) {
        self.id = id
        self.name = name
        self.model = model
        self.online = online
        self.recording = recording
    }
}

public enum SiteStatus: String, Equatable {
    case up
    case backup
    case down

    /// Health first, so unreachable sites sort to the top of every list.
    var rank: Int {
        switch self {
        case .down: return 0
        case .backup: return 1
        case .up: return 2
        }
    }
}

public struct Site: Equatable {
    public var id: String
    public var hostId: String
    public var name: String
    public var isp: String
    public var timezone: String
    public var deviceCount: Int
    public var clientCount: Int
    public var offlineCount: Int
    public var updateCount: Int
    public var wanUptime: Double
    public var permission: String
    public var owner: Bool
    public var status: SiteStatus
    public var statusText: String
    /// Set while an outage is awaiting its second confirming check.
    public var pendingDown: Bool = false

    public init(
        id: String, hostId: String, name: String, isp: String = "", timezone: String = "",
        deviceCount: Int = 0, clientCount: Int = 0, offlineCount: Int = 0, updateCount: Int = 0,
        wanUptime: Double = 0, permission: String = "viewer", owner: Bool = false,
        status: SiteStatus = .up, statusText: String = "Online", pendingDown: Bool = false
    ) {
        self.id = id
        self.hostId = hostId
        self.name = name
        self.isp = isp
        self.timezone = timezone
        self.deviceCount = deviceCount
        self.clientCount = clientCount
        self.offlineCount = offlineCount
        self.updateCount = updateCount
        self.wanUptime = wanUptime
        self.permission = permission
        self.owner = owner
        self.status = status
        self.statusText = statusText
        self.pendingDown = pendingDown
    }

    /// Stable key used to carry outage confirmations across refreshes.
    public var confirmationKey: String { hostId + ":" + id }
}

public struct NetworkSummary: Equatable {
    public var available: Bool = false
    public var devices: [Device] = []
    public var deviceCount: Int = 0
    public var offlineCount: Int = 0
    public var updateCount: Int = 0
    public var clientCount: Int = 0

    public init(
        available: Bool = false, devices: [Device] = [], deviceCount: Int = 0,
        offlineCount: Int = 0, updateCount: Int = 0, clientCount: Int = 0
    ) {
        self.available = available
        self.devices = devices
        self.deviceCount = deviceCount
        self.offlineCount = offlineCount
        self.updateCount = updateCount
        self.clientCount = clientCount
    }
}

public struct ProtectSummary: Equatable {
    public var available: Bool = false
    public var installed: Bool = false
    public var cameras: [Camera] = []
    public var cameraCount: Int = 0
    public var offlineCount: Int = 0

    public init(
        available: Bool = false, installed: Bool = false, cameras: [Camera] = [],
        cameraCount: Int = 0, offlineCount: Int = 0
    ) {
        self.available = available
        self.installed = installed
        self.cameras = cameras
        self.cameraCount = cameraCount
        self.offlineCount = offlineCount
    }
}

public enum Severity: String, Equatable {
    case healthy
    case warning
    case critical
    case disconnected
}

public struct Summary: Equatable {
    public var connected: Bool = false
    public var demo: Bool = false
    public var cloud: Bool = false
    public var host: String = ""
    public var baseUrl: String = ""
    public var siteLabel: String = ""
    public var sites: [Site] = []
    public var severity: Severity = .disconnected
    public var message: String = ""
    public var network = NetworkSummary()
    public var protect = ProtectSummary()

    public init() {}
}

public struct SiteDetail: Equatable {
    public var hostId: String = ""
    public var siteId: String = ""
    public var name: String = ""
    public var network = NetworkSummary()
    public var protect = ProtectSummary()

    public init() {}
}

// MARK: - Projections

public func compactDevice(_ item: [String: Any]) throws -> Device {
    Device(
        id: try modelString(firstValue(item, ["id", "_id", "mac"]), maxLength: 256),
        name: try modelString(
            firstValue(item, ["name", "displayName", "model", "shortname"], default: "UniFi device")
        ),
        model: try modelString(firstValue(item, ["model", "shortname", "type"])),
        ip: try modelString(firstValue(item, ["ipAddress", "ip", "lanIp"]), maxLength: 64),
        online: isOnline(item),
        update: truthy(
            firstValue(item, ["firmwareUpgradable", "upgradable", "upgradeable"], default: false)
        )
    )
}

public func compactCamera(_ item: [String: Any]) throws -> Camera {
    Camera(
        id: try modelString(firstValue(item, ["id", "_id"]), maxLength: 256),
        name: try modelString(firstValue(item, ["name", "displayName"], default: "Camera")),
        model: try modelString(firstValue(item, ["type", "modelKey", "model"])),
        online: isOnline(item),
        recording: truthy(firstValue(item, ["isRecording", "recording"], default: true))
    )
}

// MARK: - Site health

/// Recursively looks for any of `names` set to boolean true.
public func telemetryFlag(_ value: Any, _ names: [String]) -> Bool {
    let wanted = Set(names.map { $0.lowercased() })
    if let object = value as? [String: Any] {
        for (key, child) in object {
            if wanted.contains(key.lowercased()),
               let number = child as? NSNumber,
               CFGetTypeID(number) == CFBooleanGetTypeID(),
               number.boolValue {
                return true
            }
            if telemetryFlag(child, names) { return true }
        }
        return false
    }
    if let array = value as? [Any] {
        return array.contains { telemetryFlag($0, names) }
    }
    return false
}

public func latestIssuePeriod(_ value: Any) -> Any {
    var source = value
    if let object = source as? [String: Any], let periods = object["periods"] as? [Any] {
        source = periods
    }
    guard let array = source as? [Any] else { return source }
    let candidates = array.compactMap { $0 as? [String: Any] }
    guard !candidates.isEmpty else { return [Any]() }
    var best = candidates[0]
    for candidate in candidates.dropFirst() where
        nestedNumber(candidate, ["index"]) > nestedNumber(best, ["index"]) {
        best = candidate
    }
    return best
}

public func hostIsOnline(_ host: [String: Any]) -> Bool {
    let reported = (host["reportedState"] as? [String: Any]) ?? [:]
    let state = firstValue(reported, ["state", "connectionState"], default: "connected")
    return ["connected", "online", "active", "up"].contains(stringify(state).lowercased())
}

/// Conservative current site state derived from Site Manager telemetry.
public func siteHealth(stats: [String: Any], counts: [String: Any]) -> (SiteStatus, String) {
    let offlineGateways = Int(nestedNumber(counts, ["offlineGatewayDevice"]))
    let totalGateways = Int(nestedNumber(counts, ["gatewayDevice"]))
    let totalDevices = Int(nestedNumber(counts, ["totalDevice"]))
    let offlineDevices = Int(nestedNumber(counts, ["offlineDevice"]))
    let issues = latestIssuePeriod(stats["internetIssues"] ?? [Any]())

    var issueText = ""
    if JSONSerialization.isValidJSONObject(issues),
       let encoded = try? JSONSerialization.data(withJSONObject: issues, options: []),
       let text = String(data: encoded, encoding: .utf8) {
        issueText = text.lowercased()
    }

    let backupActive = telemetryFlag(issues, [
        "wan2FailoverActive", "wan2_failover_active", "backupWanActive",
        "backup_wan_active", "failoverActive",
    ])
    let outageWords = ["unreachable", "internet down", "wan down", "disconnected"]

    if offlineGateways > 0
        || (totalGateways > 0 && offlineGateways >= totalGateways)
        || (totalDevices > 0 && offlineDevices >= totalDevices)
        || outageWords.contains(where: { issueText.contains($0) }) {
        return (.down, "Site unreachable")
    }
    if backupActive { return (.backup, "Backup WAN active") }
    if telemetryFlag(issues, ["wanDowntime", "wan_downtime"]) {
        return (.down, "Site unreachable")
    }
    return (.up, "Online")
}

/// Health first, then name — matching the Linux panel's ordering.
public func sortSites(_ sites: [Site]) -> [Site] {
    sites.sorted { left, right in
        if left.status.rank != right.status.rank { return left.status.rank < right.status.rank }
        return left.name.lowercased() < right.name.lowercased()
    }
}
