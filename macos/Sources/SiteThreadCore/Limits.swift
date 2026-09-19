import Foundation

/// Every failure surfaced to the panel carries a message that is safe to show.
public struct SiteThreadError: LocalizedError, Equatable {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

/// Bounds ported from the Linux helper so a hostile or broken console cannot
/// exhaust memory through an oversized or deeply nested response.
public enum Limits {
    public static let maxResponseBytes = 1024 * 1024
    public static let maxSnapshotBytes = 16 * 1024 * 1024
    public static let maxJSONDepth = 20
    public static let maxJSONCollectionItems = 1000
    public static let maxJSONTotalValues = 20_000
    public static let maxJSONStringChars = 4096
    public static let maxJSONKeyChars = 128
    public static let maxJSONNumberAbs = 1e15
    public static let maxRowsPerResponse = 500
    public static let maxPaginatedRows = 4000
    public static let maxModelItems = 500
    public static let maxPaginationPages = 20
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
            throw SiteThreadError("The server returned too many JSON values")
        }
        if depth > Limits.maxJSONDepth {
            throw SiteThreadError("The server returned JSON nested too deeply")
        }

        if let text = value as? String {
            if text.count > Limits.maxJSONStringChars {
                throw SiteThreadError("The server returned an oversized JSON string")
            }
        } else if let array = value as? [Any] {
            if array.count > Limits.maxJSONCollectionItems {
                throw SiteThreadError("The server returned an oversized JSON array")
            }
            for child in array { pending.append((child, depth + 1)) }
        } else if let object = value as? [String: Any] {
            if object.count > Limits.maxJSONCollectionItems {
                throw SiteThreadError("The server returned an oversized JSON object")
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
        throw SiteThreadError("The server returned an oversized response")
    }
    if data.isEmpty { return nil }
    guard let payload = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
        return nil
    }
    try validateJSONLimits(payload)
    return payload
}
