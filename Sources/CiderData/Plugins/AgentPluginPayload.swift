import Foundation
import CryptoKit
import CiderDomain

/// Only replaces a complete, unchanged snapshot previously staged by Cider.
enum AgentPluginPayload {
    private static let receipt = ".cider-payload.json"
    static func validate(_ plan: AgentPluginPlan) throws {
        try safeParents(plan.destination)
        guard FileManager.default.isExecutableFile(atPath: plan.cli.path) else { throw WorkStoreError.unavailable }
        _ = try files(plan.source)
        if FileManager.default.fileExists(atPath: plan.destination.path) {
            let existing = try files(plan.destination)
            guard let record = existing[receipt], let expected = try? JSONDecoder().decode([String: String].self, from: record),
                  hashes(existing.filter { $0.key != receipt }) == expected else { throw WorkStoreError.conflict }
        }
    }
    static func stage(_ plan: AgentPluginPlan) throws {
        try validate(plan)
        var payload = try files(plan.source)
        payload["bin/cider"] = try Data(contentsOf: plan.cli)
        let schema = plan.cli.deletingLastPathComponent().deletingLastPathComponent().appending(path: "Resources/Cider_CiderData.bundle/Schema.sql")
        payload["bin/Cider_CiderData.bundle/Schema.sql"] = try Data(contentsOf: schema)
        let binary = plan.destination.appending(path: "bin/cider").path
        let quoted = "'" + binary.replacingOccurrences(of: "'", with: "'\\''") + "'"
        payload["plugins/cider/scripts/cider"] = Data("#!/bin/sh\nset -eu\nexec \(quoted) \"$@\"\n".utf8)
        payload[receipt] = try JSONEncoder().encode(hashes(payload))
        let parent = plan.destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try safeParents(plan.destination)
        let temporary = parent.appending(path: ".stage-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: temporary) }
        for (relative, bytes) in payload {
            let path = temporary.appending(path: relative)
            try FileManager.default.createDirectory(at: path.deletingLastPathComponent(), withIntermediateDirectories: true)
            try bytes.write(to: path)
            if relative == "bin/cider" || relative == "plugins/cider/scripts/cider" {
                try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: path.path)
            }
        }
        try validate(plan)
        if FileManager.default.fileExists(atPath: plan.destination.path) {
            let backup = parent.appending(path: plan.provider.rawValue + "-backup-" + UUID().uuidString)
            try FileManager.default.moveItem(at: plan.destination, to: backup)
            do { try FileManager.default.moveItem(at: temporary, to: plan.destination) }
            catch { try? FileManager.default.moveItem(at: backup, to: plan.destination); throw error }
        } else { try FileManager.default.moveItem(at: temporary, to: plan.destination) }
    }
    private static func hashes(_ files: [String: Data]) -> [String: String] {
        files.mapValues { SHA256.hash(data: $0).map { String(format: "%02x", $0) }.joined() }
    }
    private static func safeParents(_ destination: URL) throws {
        var path = destination.standardizedFileURL
        while path.path != "/" {
            if let target = try? FileManager.default.destinationOfSymbolicLink(atPath: path.path) {
                // macOS exposes these system directories through fixed aliases.
                // Reject links anywhere in the user-controlled destination tree.
                let systemAliases = ["/var": "private/var", "/tmp": "private/tmp"]
                guard systemAliases[path.path] == target else { throw WorkStoreError.outsideRoot }
            }
            path.deleteLastPathComponent()
        }
    }
    private static func files(_ root: URL) throws -> [String: Data] {
        guard let enumerator = FileManager.default.enumerator(atPath: root.path) else { throw WorkStoreError.unavailable }
        var result: [String: Data] = [:]
        for case let relative as String in enumerator {
            let file = root.appending(path: relative)
            let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            guard values.isSymbolicLink != true else { throw WorkStoreError.outsideRoot }
            if values.isRegularFile == true {
                guard (values.fileSize ?? 0) <= 100_000_000, result.count < 100 else { throw WorkStoreError.outputLimit }
                result[relative] = try Data(contentsOf: file)
            }
        }
        guard !result.isEmpty else { throw WorkStoreError.unavailable }
        return result
    }
}
