import CryptoKit
import Foundation

public struct ProbeResult: Equatable {
    public var baseUrl: String
    public var hostname: String
    public var port: Int
    public var fingerprint: String
    /// True when the freshly observed certificate matches the stored one.
    public var trusted: Bool
}

/// SHA-256 of a DER certificate, formatted the way UniFi consoles display it.
public func formatFingerprint(_ der: Data) -> String {
    let digest = SHA256.hash(data: der)
    let hex = digest.map { String(format: "%02X", $0) }
    return hex.joined(separator: ":")
}

// MARK: - TLS delegates

/// Captures the leaf certificate without ever completing the handshake, so no
/// credential can be transmitted during certificate inspection.
final class CertificateProbe: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private(set) var fingerprint: String?

    private func capture(_ challenge: URLAuthenticationChallenge) -> URLSession.AuthChallengeDisposition {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else {
            return .cancelAuthenticationChallenge
        }
        fingerprint = formatFingerprint(SecCertificateCopyData(leaf) as Data)
        return .cancelAuthenticationChallenge
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        completionHandler(capture(challenge), nil)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        completionHandler(capture(challenge), nil)
    }
}

/// Accepts exactly one certificate: the one the operator verified by
/// fingerprint. Replaces the Linux helper's `curl --pinnedpubkey`.
final class PinnedTrustDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate {
    private let expected: String

    init(fingerprint: String) {
        self.expected = fingerprint.uppercased()
    }

    private func evaluate(
        _ challenge: URLAuthenticationChallenge
    ) -> (URLSession.AuthChallengeDisposition, URLCredential?) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
              let trust = challenge.protectionSpace.serverTrust,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first else {
            return (.cancelAuthenticationChallenge, nil)
        }
        let observed = formatFingerprint(SecCertificateCopyData(leaf) as Data)
        guard observed == expected else { return (.cancelAuthenticationChallenge, nil) }
        return (.useCredential, URLCredential(trust: trust))
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let outcome = evaluate(challenge)
        completionHandler(outcome.0, outcome.1)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let outcome = evaluate(challenge)
        completionHandler(outcome.0, outcome.1)
    }
}

// MARK: - Client

/// RFC 3986 unreserved set, matching Python's `urllib.parse.quote(safe="")`.
let unreservedCharacters: CharacterSet = {
    var set = CharacterSet.alphanumerics
    set.insert(charactersIn: "-._~")
    return set
}()

public enum UniFiClient {
    public static let cloudBaseURL = "https://api.ui.com"

    static func configuration(timeout: TimeInterval) -> URLSessionConfiguration {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = timeout
        config.timeoutIntervalForResource = timeout + 5
        config.httpShouldSetCookies = false
        config.httpCookieStorage = nil
        config.urlCache = nil
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        return config
    }

    /// Ported from `normalize_host`: HTTPS only, no credentials, no path.
    public static func normalizeHost(_ raw: String) throws -> (String, String, Int) {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty {
            throw SiteThreadError("Enter the address of your UniFi console")
        }
        if !value.contains("://") { value = "https://" + value }
        guard let parsed = URLComponents(string: value), let hostname = parsed.host, !hostname.isEmpty else {
            throw SiteThreadError("Use an HTTPS console address")
        }
        guard parsed.scheme == "https" else {
            throw SiteThreadError("Use an HTTPS console address")
        }
        guard hostname.count <= 253 else {
            throw SiteThreadError("The console hostname is too long")
        }
        guard parsed.user == nil, parsed.password == nil, parsed.query == nil, parsed.fragment == nil else {
            throw SiteThreadError("The console address must not contain credentials or query data")
        }
        guard parsed.path.isEmpty || parsed.path == "/" else {
            throw SiteThreadError("Use the console address without an application path")
        }
        let port = parsed.port ?? 443
        let display = port == 443 ? hostname : "\(hostname):\(port)"
        return ("https://" + display, hostname, port)
    }

    /// Inspects the console certificate. No credential is sent.
    public static func probe(host: String, storedFingerprint: String?) async throws -> ProbeResult {
        let normalized = try normalizeHost(host)
        guard let url = URL(string: normalized.0 + "/") else {
            throw SiteThreadError("Use an HTTPS console address")
        }
        let delegate = CertificateProbe()
        let session = URLSession(configuration: configuration(timeout: 10), delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        // The handshake is deliberately cancelled once the leaf is captured,
        // so this call is expected to fail.
        _ = try? await session.data(for: request)

        guard let fingerprint = delegate.fingerprint else {
            throw SiteThreadError("Could not read the console certificate")
        }
        return ProbeResult(
            baseUrl: normalized.0,
            hostname: normalized.1,
            port: normalized.2,
            fingerprint: fingerprint,
            trusted: storedFingerprint?.uppercased() == fingerprint
        )
    }

    private static func send(
        request: URLRequest,
        delegate: URLSessionDelegate?,
        timeout: TimeInterval,
        byteLimit: Int,
        failureMessage: String
    ) async throws -> (Int, Data) {
        let session = URLSession(configuration: configuration(timeout: timeout), delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }

        let result: (Data, URLResponse)
        do {
            result = try await session.data(for: request)
        } catch {
            throw SiteThreadError(failureMessage)
        }
        guard let response = result.1 as? HTTPURLResponse else {
            throw SiteThreadError(failureMessage)
        }
        if response.expectedContentLength > Int64(byteLimit) || result.0.count > byteLimit {
            throw SiteThreadError(
                "The server returned an oversized response "
                    + "(over \(byteLimit) bytes)"
            )
        }
        return (response.statusCode, result.0)
    }

    private static func authorized(url: URL, key: String, accept: String?) throws -> URLRequest {
        guard isValidAPIKey(key) else {
            throw SiteThreadError("The stored API key is malformed")
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key, forHTTPHeaderField: "X-API-KEY")
        if let accept = accept { request.setValue(accept, forHTTPHeaderField: "Accept") }
        return request
    }

    // MARK: Cloud (UI Account / Site Manager)

    public static func cloudJSON(key: String, path: String) async throws -> (Int, Any?) {
        guard let url = URL(string: cloudBaseURL + path) else {
            throw SiteThreadError("UniFi Site Manager returned an invalid request path")
        }
        let request = try authorized(url: url, key: key, accept: "application/json")
        let response = try await send(
            request: request,
            delegate: nil,
            timeout: 15,
            byteLimit: Limits.maxResponseBytes,
            failureMessage: "UniFi Site Manager could not be reached"
        )
        return (response.0, try decodeJSON(response.1))
    }

    public static func cloudData(key: String, path: String) async throws -> (Int, Data) {
        guard let url = URL(string: cloudBaseURL + path) else {
            throw SiteThreadError("UniFi Cloud Connector returned an invalid request path")
        }
        let request = try authorized(url: url, key: key, accept: nil)
        return try await send(
            request: request,
            delegate: nil,
            timeout: 15,
            byteLimit: Limits.maxSnapshotBytes,
            failureMessage: "UniFi Cloud Connector could not be reached"
        )
    }

    /// Paginated collection read with the helper's row and page ceilings.
    public static func cloudRows(key: String, endpoint: String) async throws -> [[String: Any]] {
        var output: [[String: Any]] = []
        var token = ""
        for _ in 0..<Limits.maxPaginationPages {
            var query = "?pageSize=200"
            if !token.isEmpty {
                let encoded = token.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) ?? ""
                query += "&nextToken=" + encoded
            }
            let response = try await cloudJSON(key: key, path: endpoint + query)
            guard response.0 == 200 else {
                var message = ""
                if let object = response.1 as? [String: Any], let text = object["message"] as? String {
                    message = (try? modelString(text)) ?? ""
                }
                throw SiteThreadError(
                    message.isEmpty ? "UniFi Site Manager returned HTTP \(response.0)" : message
                )
            }
            let page = try rows(response.1)
            if output.count + page.count > Limits.maxPaginatedRows {
                throw SiteThreadError(
                    "UniFi Site Manager returned too many rows "
                        + "(over \(Limits.maxPaginatedRows))"
                )
            }
            output.append(contentsOf: page)

            token = ""
            if let object = response.1 as? [String: Any], let next = object["nextToken"] {
                token = (try? modelString(next, maxLength: 2048)) ?? ""
            }
            if token.isEmpty { return output }
        }
        throw SiteThreadError("UniFi Site Manager pagination did not finish")
    }

    /// Builds a Cloud Connector proxy path for one console.
    public static func connectorPath(hostId: String, path: String) throws -> String {
        guard isValidHostIdentifier(hostId) else {
            throw SiteThreadError("Invalid UniFi console id")
        }
        let encoded = hostId.addingPercentEncoding(withAllowedCharacters: unreservedCharacters) ?? ""
        var suffix = path
        while suffix.hasPrefix("/") { suffix.removeFirst() }
        return "/v1/connector/consoles/\(encoded)/proxy/\(suffix)"
    }

    // MARK: Local console (pinned)

    public static func localJSON(
        connection: Connection,
        key: String,
        path: String
    ) async throws -> (Int, Any?) {
        guard let url = URL(string: connection.baseUrl + path) else {
            throw SiteThreadError("The console returned an invalid request path")
        }
        let request = try authorized(url: url, key: key, accept: "application/json")
        let response = try await send(
            request: request,
            delegate: PinnedTrustDelegate(fingerprint: connection.fingerprint),
            timeout: 18,
            byteLimit: Limits.maxResponseBytes,
            failureMessage: "The UniFi console could not be reached securely"
        )
        return (response.0, try decodeJSON(response.1))
    }

    public static func localData(
        connection: Connection,
        key: String,
        path: String
    ) async throws -> (Int, Data) {
        guard let url = URL(string: connection.baseUrl + path) else {
            throw SiteThreadError("The console returned an invalid request path")
        }
        let request = try authorized(url: url, key: key, accept: nil)
        return try await send(
            request: request,
            delegate: PinnedTrustDelegate(fingerprint: connection.fingerprint),
            timeout: 18,
            byteLimit: Limits.maxSnapshotBytes,
            failureMessage: "The UniFi console could not be reached securely"
        )
    }
}
