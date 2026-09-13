import Foundation
import CiderDomain

struct CLIResult {
    var data: AnyEncodable
    var revision: Int64
    var nextCursor: String? = nil
    var truncated: Bool = false
    init<T: Encodable>(_ data: T, revision: Int64, nextCursor: String? = nil, truncated: Bool = false) {
        self.data = AnyEncodable(data)
        self.revision = revision
        self.nextCursor = nextCursor
        self.truncated = truncated
    }
}

enum CLIOutput {
    static func success(_ result: some Encodable, revision: Int64, nextCursor: String? = nil, truncated: Bool = false) throws -> String {
        let envelope = SuccessEnvelope(storeRevision: revision, data: AnyEncodable(result), nextCursor: nextCursor, truncated: truncated)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try normalizedUUIDData(encoder.encode(envelope))
        guard data.count <= WorkLimits.contextBytes else { throw WorkStoreError.outputLimit }
        return String(decoding: data, as: UTF8.self)
    }

    static func error(_ error: Error) -> String {
        let code = stableCode(error)
        let remote = (error as? CLIWriteFailure)?.reply
        let envelope = ErrorEnvelope(error: ErrorBody(code: code,
            message: remote?.partialWrite == true ? "The note file was saved, but its connections could not finish. Inspect recoveryPath before retrying." : message(for: code),
            recoveryPath: remote?.partialWrite == true ? remote?.path : nil))
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return (try? String(decoding: encoder.encode(envelope), as: UTF8.self)) ?? #"{"schemaVersion":1,"error":{"code":"unavailable","message":"Cider TODO access is unavailable."}}"#
    }

    static func exitCode(_ error: Error) -> Int {
        switch stableCode(error) {
        case "invalidInput": 2
        case "notFound": 3
        case "unavailable", "unsupportedSchema", "migrationFailed": 4
        case "conflict", "busy", "fileChanged": 5
        default: 6
        }
    }

    private static func stableCode(_ error: Error) -> String {
        if let remote = error as? CLIWriteFailure { return remote.reply.error?.code ?? "unavailable" }
        return (error as? WorkStoreError)?.code ?? "unavailable"
    }
    private static func message(for code: String) -> String {
        switch code {
        case "invalidInput": "Invalid Cider command, input or identifier. Run cider --help."
        case "notFound": "The requested task, note or folder was not found."
        case "conflict", "fileChanged": "The saved task or note changed. Read it again before updating."
        case "busy": "Cider is busy, a note has unsaved edits, or the write timed out. Inspect saved state before retrying."
        case "unsupportedSchema": "The store uses an unsupported schema."
        case "outputLimit": "The command input or result exceeds Cider's size limit."
        default: "Cider access is unavailable. Writes require Cider running on the selected store."
        }
    }

    private static func normalizedUUIDData(_ data: Data) throws -> Data {
        let source = try JSONSerialization.jsonObject(with: data)
        let normalized = normalizeUUIDs(source, key: nil)
        return try JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys])
    }

    private static func normalizeUUIDs(_ value: Any, key: String?) -> Any {
        let uuidKeys: Set<String> = ["id", "taskID", "noteID", "rootID", "linkID", "hostID", "sourceID", "targetID", "sourceEventID"]
        if let text = value as? String, uuidKeys.contains(key ?? ""), UUID(uuidString: text) != nil { return text.lowercased() }
        if let array = value as? [Any] { return array.map { normalizeUUIDs($0, key: nil) } }
        if let object = value as? [String: Any] {
            if key == "plannedDay", let year = object["year"] as? Int, let month = object["month"] as? Int, let day = object["day"] as? Int {
                return String(format: "%04d-%02d-%02d", year, month, day)
            }
            return Dictionary(uniqueKeysWithValues: object.map { ($0.key, normalizeUUIDs($0.value, key: $0.key)) })
        }
        return value
    }
}

private struct SuccessEnvelope: Encodable {
    let schemaVersion = 1
    let storeRevision: Int64
    let generatedAt: Date = .now
    let data: AnyEncodable
    let nextCursor: String?
    let truncated: Bool
    enum CodingKeys: String, CodingKey { case schemaVersion, storeRevision, generatedAt, data, nextCursor, truncated }
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(storeRevision, forKey: .storeRevision)
        try container.encode(generatedAt, forKey: .generatedAt)
        try container.encode(data, forKey: .data)
        try container.encode(nextCursor, forKey: .nextCursor)
        try container.encode(truncated, forKey: .truncated)
    }
}
private struct ErrorEnvelope: Encodable { let schemaVersion = 1; let error: ErrorBody }
private struct ErrorBody: Encodable { let code: String; let message: String; var recoveryPath: String? = nil }

struct AnyEncodable: Encodable {
    private let encodeBody: (Encoder) throws -> Void
    init<T: Encodable>(_ value: T) { encodeBody = value.encode }
    func encode(to encoder: Encoder) throws { try encodeBody(encoder) }
}
