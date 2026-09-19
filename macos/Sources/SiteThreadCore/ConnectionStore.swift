import Foundation

public struct Connection: Codable, Equatable {
    /// `cloud` for UI Account / Site Manager, `local` for a pinned console.
    public var mode: String
    public var baseUrl: String
    public var hostname: String
    public var port: Int
    /// Colon-separated uppercase SHA-256 of the console's leaf certificate.
    /// Empty in cloud mode, where normal public TLS verification applies.
    public var fingerprint: String

    public init(mode: String, baseUrl: String, hostname: String = "", port: Int = 443, fingerprint: String = "") {
        self.mode = mode
        self.baseUrl = baseUrl
        self.hostname = hostname
        self.port = port
        self.fingerprint = fingerprint
    }

    public static let cloud = Connection(mode: "cloud", baseUrl: UniFiClient.cloudBaseURL)

    public var isCloud: Bool { mode == "cloud" }
}

/// Stores the non-secret half of the connection in Application Support with
/// owner-only permissions. The credential itself stays in the keychain.
public enum ConnectionStore {
    public static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("UniFi SiteThread", isDirectory: true)
    }

    public static var file: URL {
        directory.appendingPathComponent("connection.json")
    }

    public static func load() -> Connection? {
        guard let data = try? Data(contentsOf: file), data.count <= 64 * 1024 else { return nil }
        guard let connection = try? JSONDecoder().decode(Connection.self, from: data) else { return nil }
        if connection.isCloud {
            return connection.baseUrl == UniFiClient.cloudBaseURL ? connection : nil
        }
        guard !connection.hostname.isEmpty, !connection.fingerprint.isEmpty, connection.port > 0 else {
            return nil
        }
        return connection
    }

    public static func save(_ connection: Connection) throws {
        let manager = FileManager.default
        try manager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try manager.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(connection)
        try data.write(to: file, options: [.atomic])
        try manager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    public static func clear() {
        try? FileManager.default.removeItem(at: file)
    }
}
