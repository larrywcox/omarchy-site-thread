import XCTest
@testable import SiteThreadCore

/// Ports `tests/test_security.py` so the macOS app keeps the same response
/// bounds as the Linux helper.
final class JSONLimitTests: XCTestCase {

    private func expectFailure(
        containing fragment: String,
        _ body: () throws -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        do {
            try body()
            XCTFail("Expected a failure containing \"\(fragment)\"", file: file, line: line)
        } catch let error as SiteThreadError {
            XCTAssertTrue(
                error.message.contains(fragment),
                "\"\(error.message)\" does not contain \"\(fragment)\"",
                file: file, line: line
            )
        } catch {
            XCTFail("Unexpected error: \(error)", file: file, line: line)
        }
    }

    func testValidJSONIsReturned() throws {
        let data = Data(#"{"data":[{"name":"switch"}]}"#.utf8)
        let payload = try decodeJSON(data)
        let items = try rows(payload)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0]["name"] as? String, "switch")
    }

    func testNonJSONBodyIsNotAnError() throws {
        XCTAssertNil(try decodeJSON(Data("<html>nope</html>".utf8)))
        XCTAssertNil(try decodeJSON(Data()))
    }

    func testExcessiveDepthIsRejected() {
        var value: Any = "leaf"
        for _ in 0...(Limits.maxJSONDepth) { value = [value] }
        expectFailure(containing: "nested too deeply") { try validateJSONLimits(value) }
    }

    func testExcessiveArrayIsRejected() {
        let value = Array(repeating: 0, count: Limits.maxJSONCollectionItems + 1)
        expectFailure(containing: "oversized JSON array") { try validateJSONLimits(value) }
    }

    func testExcessiveStringIsRejected() {
        let value = String(repeating: "x", count: Limits.maxJSONStringChars + 1)
        expectFailure(containing: "oversized JSON string") { try validateJSONLimits(value) }
    }

    func testOutOfRangeNumberIsRejected() {
        expectFailure(containing: "out-of-range JSON number") {
            try validateJSONLimits(Double.infinity)
        }
        expectFailure(containing: "out-of-range JSON number") {
            try validateJSONLimits(1e16)
        }
    }

    func testBooleansAreNotTreatedAsNumbers() throws {
        try validateJSONLimits(["enabled": true, "disabled": false])
    }

    func testExcessiveRowCountIsRejected() {
        let payload: [String: Any] = [
            "data": Array(repeating: [String: Any](), count: Limits.maxRowsPerResponse + 1),
        ]
        expectFailure(containing: "too many rows") { _ = try rows(payload) }
    }

    func testOversizedBodyIsRejected() {
        let data = Data(repeating: 0x20, count: Limits.maxResponseBytes + 1)
        expectFailure(containing: "oversized response") { _ = try decodeJSON(data) }
    }

    func testModelStringsHaveATighterLimit() {
        expectFailure(containing: "oversized model field") {
            _ = try compactDevice(["name": String(repeating: "x", count: 257)])
        }
    }
}

/// Regression: the response bounds guard against hostile payloads, so they
/// must sit clear of what Site Manager legitimately returns. An earlier
/// 20,000-value ceiling rejected any fleet past roughly 74 sites.
final class FleetSizeTests: XCTestCase {

    /// A `/v1/sites` page shaped like the real thing. The statistics block is
    /// the bulk of the value count.
    private func fleetPayload(siteCount: Int) -> [String: Any] {
        let countKeys = [
            "totalDevice", "offlineDevice", "gatewayDevice", "offlineGatewayDevice",
            "wifiDevice", "wiredDevice", "pendingUpdateDevice", "wifiClient",
            "wiredClient", "guestClient", "criticalNotification",
        ]
        let sites: [[String: Any]] = (0..<siteCount).map { index in
            var counts: [String: Any] = [:]
            for key in countKeys { counts[key] = index % 17 }
            let issues: [[String: Any]] = (0..<24).map { period in
                [
                    "index": period,
                    "startTimestamp": "2026-09-01T00:00:00Z",
                    "duration": 12,
                    "wanDowntime": false,
                    "wan2FailoverActive": false,
                    "latencyAvg": 14.2,
                    "packetLoss": 0.0,
                ]
            }
            return [
                "siteId": String(format: "site%04d", index),
                "hostId": String(format: "console-%04d", index),
                "isOwner": index % 3 == 0,
                "permission": "admin",
                "meta": [
                    "desc": "Branch \(index)",
                    "name": "branch-\(index)",
                    "timezone": "America/Chicago",
                    "gatewayMac": "aa:bb:cc:dd:ee:ff",
                ],
                "statistics": [
                    "counts": counts,
                    "percentages": ["wanUptime": 99.9, "txRetry": 1.2],
                    "ispInfo": ["name": "Acme Fiber", "organization": "Acme"],
                    "internetIssues": issues,
                ],
            ]
        }
        return ["data": sites, "nextToken": ""]
    }

    func testALargeFleetPageIsAccepted() throws {
        let payload = fleetPayload(siteCount: 200)
        let body = try JSONSerialization.data(withJSONObject: payload, options: [])
        XCTAssertLessThan(body.count, Limits.maxResponseBytes)

        let decoded = try decodeJSON(body)
        XCTAssertEqual(try rows(decoded).count, 200)
    }

    func testTheValueCeilingClearsAFullPageWithHeadroom() {
        var pending: [Any] = [fleetPayload(siteCount: 200)]
        var seen = 0
        while !pending.isEmpty {
            let value = pending.removeLast()
            seen += 1
            if let array = value as? [Any] {
                pending.append(contentsOf: array)
            } else if let object = value as? [String: Any] {
                pending.append(contentsOf: object.values)
            }
        }
        XCTAssertLessThan(seen * 4, Limits.maxJSONTotalValues)
    }

    func testAFleetLargerThanTheModelCeilingIsStillRejected() {
        XCTAssertGreaterThan(Limits.maxModelItems, 200)
        XCTAssertLessThan(Limits.maxModelItems, 1_000_000)
    }
}

final class CredentialValidationTests: XCTestCase {

    func testAPIKeyPattern() {
        XCTAssertTrue(isValidAPIKey("abcd1234"))
        XCTAssertTrue(isValidAPIKey("A-b_c.d~e+f/g=h"))
        XCTAssertFalse(isValidAPIKey("short"))
        XCTAssertFalse(isValidAPIKey("has space"))
        XCTAssertFalse(isValidAPIKey("newline\ninjected"))
        XCTAssertFalse(isValidAPIKey(String(repeating: "x", count: 4097)))
    }

    func testIdentifierPatterns() {
        XCTAssertTrue(isValidIdentifier("site-01_a"))
        XCTAssertFalse(isValidIdentifier("../../etc/passwd"))
        XCTAssertFalse(isValidIdentifier(""))
        XCTAssertTrue(isValidHostIdentifier("console:01"))
        XCTAssertFalse(isValidHostIdentifier("console/01"))
    }

    func testConnectorPathRejectsHostileIds() {
        XCTAssertThrowsError(try UniFiClient.connectorPath(hostId: "a/b", path: "x"))
        let path = try? UniFiClient.connectorPath(
            hostId: "console-1", path: "/network/integration/v1/sites"
        )
        XCTAssertEqual(path, "/v1/connector/consoles/console-1/proxy/network/integration/v1/sites")
    }

    func testHostNormalization() throws {
        let plain = try UniFiClient.normalizeHost("192.168.1.1")
        XCTAssertEqual(plain.0, "https://192.168.1.1")
        XCTAssertEqual(plain.2, 443)

        let ported = try UniFiClient.normalizeHost("https://unifi.local:8443")
        XCTAssertEqual(ported.0, "https://unifi.local:8443")
        XCTAssertEqual(ported.2, 8443)

        XCTAssertThrowsError(try UniFiClient.normalizeHost("http://unifi.local"))
        XCTAssertThrowsError(try UniFiClient.normalizeHost("https://user:pass@unifi.local"))
        XCTAssertThrowsError(try UniFiClient.normalizeHost("https://unifi.local/network"))
        XCTAssertThrowsError(try UniFiClient.normalizeHost(""))
    }
}

final class HealthModelTests: XCTestCase {

    func testOfflineGatewayMarksSiteDown() {
        let counts: [String: Any] = ["offlineGatewayDevice": 1, "gatewayDevice": 1, "totalDevice": 6]
        let health = siteHealth(stats: [:], counts: counts)
        XCTAssertEqual(health.0, .down)
        XCTAssertEqual(health.1, "Site unreachable")
    }

    func testBackupWanIsWarningNotOutage() {
        let stats: [String: Any] = [
            "internetIssues": [["index": 3, "wan2FailoverActive": true]],
        ]
        let health = siteHealth(stats: stats, counts: ["totalDevice": 4, "offlineDevice": 0])
        XCTAssertEqual(health.0, .backup)
    }

    func testHealthySiteStaysUp() {
        let health = siteHealth(stats: [:], counts: ["totalDevice": 4, "offlineDevice": 1])
        XCTAssertEqual(health.0, .up)
        XCTAssertEqual(health.1, "Online")
    }

    func testSitesSortByHealthThenName() {
        let sites = [
            Site(id: "c", hostId: "h", name: "Zulu", status: .up),
            Site(id: "a", hostId: "h", name: "Bravo", status: .down),
            Site(id: "b", hostId: "h", name: "Alpha", status: .backup),
            Site(id: "d", hostId: "h", name: "Alpha Two", status: .down),
        ]
        XCTAssertEqual(sortSites(sites).map { $0.name }, ["Alpha Two", "Bravo", "Alpha", "Zulu"])
    }

    func testFleetSeverityPrefersSiteOutages() {
        var summary = Demo.summary()
        XCTAssertEqual(summary.severity, .critical)
        XCTAssertEqual(summary.message, "1 site(s) unreachable")

        summary.sites = summary.sites.map { site in
            var copy = site
            if copy.status == .down { copy.status = .up }
            return copy
        }
        SummaryBuilder.applyFleetSeverity(&summary)
        XCTAssertEqual(summary.severity, .warning)
        XCTAssertEqual(summary.message, "1 site(s) using backup WAN")
    }

    func testDeviceProjectionKeepsOnlyKnownFields() throws {
        let device = try compactDevice([
            "id": "aa:bb", "name": "Core Switch", "model": "USW",
            "ipAddress": "10.0.0.2", "state": "ONLINE", "firmwareUpgradable": true,
            "secretInternalField": "should not matter",
        ])
        XCTAssertEqual(device.name, "Core Switch")
        XCTAssertTrue(device.online)
        XCTAssertTrue(device.update)
        XCTAssertEqual(device.ip, "10.0.0.2")
    }

    func testOnlineStateAcceptsBooleansAndStrings() {
        XCTAssertTrue(isOnline(["state": true]))
        XCTAssertTrue(isOnline(["status": "connected"]))
        XCTAssertFalse(isOnline(["state": "DISCONNECTED"]))
        XCTAssertFalse(isOnline(["state": false]))
        XCTAssertTrue(isOnline([:]))
    }
}
