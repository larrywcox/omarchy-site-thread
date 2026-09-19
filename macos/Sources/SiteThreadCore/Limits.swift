import Foundation

/// Every failure surfaced to the panel carries a message that is safe to show.
public struct SiteThreadError: LocalizedError, Equatable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

/// Bounds that stop a hostile or broken console from exhausting memory.
///
/// `maxResponseBytes` is the primary guard: nothing larger is ever decoded, so
/// the worst case is bounded before any traversal begins. The counters below
/// are a secondary guard against shapes that are cheap in bytes but expensive
/// to walk — deep nesting, or millions of one-character values.
///
/// They must therefore sit well clear of what UniFi legitimately returns. A
/// Site Manager `/v1/sites` page carries each site's full `statistics` block —
/// `counts`, `percentages`, `ispInfo`, and an `internetIssues` period array —
/// which is a few hundred JSON values per site before any devices are counted.
public enum Limits {
    public static let maxResponseBytes = 8 * 1024 * 1024
    public static let maxSnapshotBytes = 16 * 1024 * 1024
    public static let maxJSONDepth = 20
    public static let maxJSONCollectionItems = 20_000
    public static let maxJSONTotalValues = 400_000
    public static let maxJSONStringChars = 4096
    public static let maxJSONKeyChars = 128
    public static let maxJSONNumberAbs = 1e15
    public static let maxRowsPerResponse = 1000
    public static let maxPaginatedRows = 20_000
    public static let maxModelItems = 5000
    public static let maxPaginationPages = 100
    public static let maxModelStringChars = 256
}

private let apiKeyCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789._~+/=-"
)
private let idCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_-"
)
private let hostIdCharacters = CharacterSet(
    charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789:_-"
)

private func matches(_ value: String, _ allowed: CharacterSet, _ range: ClosedRange<Int>) -> Bool {
    guard range.contains(value.count) else { return false }
    for scalar in value.unicodeScalars where !allowed.contains(scalar) {
        return false
    }
    return true
}

/// Mirrors `KEY_PATTERN` in the Linux helper.
public func isValidAPIKey(_ key: String) -> Bool {
    matches(key, apiKeyCharacters, 8...4096)
}

/// Mirrors `ID_PATTERN` in the Linux helper.
public func isValidIdentifier(_ value: String) -> Bool {
    matches(value, idCharacters, 1...128)
}

/// Mirrors `HOST_ID_PATTERN` in the Linux helper.
public func isValidHostIdentifier(_ value: String) -> Bool {
    matches(value, hostIdCharacters, 1...256)
}

private func isBoolean(_ value: Any) -> Bool {
    guard let number = value as? NSNumber else { return false }
    return CFGetTypeID(number) == CFBooleanGetTypeID()
}

/// Rejects decoded responses whose shape is too costly to retain or traverse.
public func validateJSONLimits(_ payload: Any) throws {
    var pending: [(Any, Int)] = [(payload, 0)]
    var seen = 0
    while !pending.isEmpty {
        let entry = pending.removeLast()
        let value = entry.0
        let depth = entry.1
        seen += 1
        if seen > Limits.maxJSONTotalValues {
            throw SiteThreadError(
                "The server returned too many JSON values (over \(Limits.maxJSONTotalValues))"
            )
        }
        if depth > Limits.maxJSONDepth {
            throw SiteThreadError(
                "The server returned JSON nested too deeply (over \(Limits.maxJSONDepth) levels)"
            )
        }

        if let text = value as? String {
            if text.count > Limits.maxJSONStringChars {
                throw SiteThreadError(
                    "The server returned an oversized JSON string "
                        + "(\(text.count) > \(Limits.maxJSONStringChars) characters)"
                )
            }
        } else if let array = value as? [Any] {
            if array.count > Limits.maxJSONCollectionItems {
                throw SiteThreadError(
                    "The server returned an oversized JSON array "
                        + "(\(array.count) > \(Limits.maxJSONCollectionItems) items)"
                )
            }
            for child in array { pending.append((child, depth + 1)) }
        } else if let object = value as? [String: Any] {
            if object.count > Limits.maxJSONCollectionItems {
                throw SiteThreadError(
                    "The server returned an oversized JSON object "
                        + "(\(object.count) > \(Limits.maxJSONCollectionItems) fields)"
                )
            }
            for (key, child) in object {
                if key.count > Limits.maxJSONKeyChars {
                    throw SiteThreadError("The server returned an invalid JSON field name")
                }
                pending.append((child, depth + 1))
            }
        } else if !isBoolean(value), let number = value as? NSNumber {
            let scalar = number.doubleValue
            if !scalar.isFinite || abs(scalar) > Limits.maxJSONNumberAbs {
                throw SiteThreadError("The server returned an out-of-range JSON number")
            }
        }
    }
}

/// Decodes a bounded response body, returning `nil` for a non-JSON payload the
/// way the Linux helper does.
public func decodeJSON(_ data: Data) throws -> Any? {
    if data.count > Limits.maxResponseBytes {
        throw SiteThreadError(
            "The server returned an oversized response "
                + "(\(data.count) > \(Limits.maxResponseBytes) bytes)"
        )
    }
    if data.isEmpty { return nil }
    guard let payload = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
        return nil
    }
    try validateJSONLimits(payload)
    return payload
}
