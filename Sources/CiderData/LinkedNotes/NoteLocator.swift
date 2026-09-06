import Foundation
import CiderDomain

/// Validates explicit note paths. It never falls back to a basename match.
struct NoteLocator: Sendable {
    func resolve(_ note: NoteReference, root: FolderReference, expectedIdentity: Data? = nil) throws -> URL {
        guard note.rootID == root.id, root.available, note.available else { throw WorkStoreError.unavailable }
        let url = try path(note, root: root)
        if let expected = expectedIdentity ?? note.fileIdentity, let actual = try? identity(of: url), expected != actual { throw WorkStoreError.notFound }
        return url
    }

    func path(_ note: NoteReference, root: FolderReference) throws -> URL {
        guard note.rootID == root.id, root.available, note.available else { throw WorkStoreError.unavailable }
        let url = try containedFile(note.relativePath, root: root)
        guard FileManager.default.fileExists(atPath: url.path) else { throw WorkStoreError.notFound }
        return url
    }

    func directory(_ relativeDirectory: String, in root: FolderReference) throws -> URL {
        guard root.available else { throw WorkStoreError.unavailable }
        let rootURL = try canonicalRoot(root)
        if relativeDirectory.isEmpty { return rootURL }
        guard isSafeRelative(relativeDirectory) else { throw WorkStoreError.outsideRoot }
        let directory = rootURL.appendingPathComponent(relativeDirectory, isDirectory: true).resolvingSymlinksInPath()
        guard contains(rootURL, directory), FileManager.default.fileExists(atPath: directory.path) else { throw WorkStoreError.outsideRoot }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw WorkStoreError.notFound }
        return directory
    }

    func relativePath(of url: URL, in root: FolderReference) throws -> String {
        let rootURL = try canonicalRoot(root)
        let canonical = url.resolvingSymlinksInPath()
        guard contains(rootURL, canonical) else { throw WorkStoreError.outsideRoot }
        return canonical.pathComponents.dropFirst(rootURL.pathComponents.count).joined(separator: "/")
    }

    func identity(of url: URL) throws -> Data? {
        let attributes: [FileAttributeKey: Any]
        do { attributes = try FileManager.default.attributesOfItem(atPath: url.path) } catch { throw WorkStoreError.unavailable }
        guard let number = attributes[.systemFileNumber] as? NSNumber else { return nil }
        return Data(number.stringValue.utf8)
    }

    func modifiedAt(_ url: URL) throws -> Date {
        do { return try FileManager.default.attributesOfItem(atPath: url.path)[.modificationDate] as? Date ?? .distantPast }
        catch { throw WorkStoreError.unavailable }
    }

    private func containedFile(_ relativePath: String, root: FolderReference) throws -> URL {
        guard isSafeRelative(relativePath) else { throw WorkStoreError.outsideRoot }
        let rootURL = try canonicalRoot(root)
        let candidate = rootURL.appendingPathComponent(relativePath).resolvingSymlinksInPath()
        guard contains(rootURL, candidate) else { throw WorkStoreError.outsideRoot }
        return candidate
    }

    private func canonicalRoot(_ root: FolderReference) throws -> URL {
        guard !root.path.isEmpty else { throw WorkStoreError.unavailable }
        let url = URL(fileURLWithPath: root.path, isDirectory: true).resolvingSymlinksInPath()
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { throw WorkStoreError.unavailable }
        return url
    }

    private func isSafeRelative(_ path: String) -> Bool {
        !path.hasPrefix("/") && !path.hasPrefix("\\") && path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { $0 != ".." && $0 != "" }
    }

    private func contains(_ root: URL, _ candidate: URL) -> Bool {
        let base = root.standardizedFileURL.pathComponents
        let path = candidate.standardizedFileURL.pathComponents
        return path.count >= base.count && zip(base, path).allSatisfy(==)
    }
}
